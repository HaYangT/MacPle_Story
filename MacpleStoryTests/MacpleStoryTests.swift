//
//  MacpleStoryTests.swift
//  MacpleStoryTests
//
//  Created by 고혜역 on 6/12/26.
//

import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import MacpleStory

@Suite(.serialized)
@MainActor
struct MacpleStoryTests {

    @Test func timerCountsDownWhileRunning() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "테스트 스킬",
            cooldownSeconds: 3,
            alertBeforeSeconds: 1,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        store.toggleTimer(id: timerID)

        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 2)
        #expect(store.skillTimers.first?.isRunning == true)

        store.tick()
        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 0)
        #expect(store.skillTimers.first?.isRunning == false)
    }

    @Test func completedTimerRestartsFromCooldown() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "재시작 스킬",
            cooldownSeconds: 2,
            alertBeforeSeconds: 1,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        store.toggleTimer(id: timerID)
        store.tick()
        store.tick()

        store.toggleTimer(id: timerID)

        #expect(store.skillTimers.first?.remainingSeconds == 2)
        #expect(store.skillTimers.first?.isRunning == true)
    }

    @Test func explicitStartStopAndResetControlTimerState() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "제어 테스트",
            cooldownSeconds: 10,
            alertBeforeSeconds: 5,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)

        store.startTimer(id: timerID)
        #expect(store.skillTimers.first?.isRunning == true)

        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 9)

        store.stopTimer(id: timerID)
        store.tick()
        #expect(store.skillTimers.first?.isRunning == false)
        #expect(store.skillTimers.first?.remainingSeconds == 9)

        store.resetTimer(id: timerID)
        #expect(store.skillTimers.first?.isRunning == false)
        #expect(store.skillTimers.first?.remainingSeconds == 10)
    }

    @Test func automaticCooldownTriggerStartsIdleTimerFromFullCooldown() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "자동 시작 스킬",
            cooldownSeconds: 12,
            alertBeforeSeconds: 5,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)

        #expect(store.triggerCooldown(id: timerID) == true)
        #expect(store.skillTimers.first?.isRunning == true)
        #expect(store.skillTimers.first?.remainingSeconds == 12)

        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 11)

        #expect(store.triggerCooldown(id: timerID) == false)
        #expect(store.skillTimers.first?.remainingSeconds == 11)
    }

    @Test func preAlertFiresWhenRemainingTimeReachesAlertThreshold() async throws {
        let alertService = NoopAlertNotificationService()
        let store = SkillTimerStore(alertNotificationService: alertService)

        store.addTimer(
            name: "알림 테스트",
            cooldownSeconds: 7,
            alertBeforeSeconds: 5,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        store.startTimer(id: timerID)

        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 6)
        #expect(alertService.preAlertTimerIDs.isEmpty)

        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 5)
        #expect(alertService.preAlertTimerIDs == [timerID])

        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 4)
        #expect(alertService.preAlertTimerIDs == [timerID])
    }

    @Test func alertVolumeDefaultsToHalfAndClampsToRange() async throws {
        let suiteName = UUID().uuidString
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        let alertSoundService = AlertSoundService()
        let store = SkillTimerStore(
            alertSoundService: alertSoundService,
            alertNotificationService: NoopAlertNotificationService(),
            userDefaults: userDefaults
        )

        #expect(store.alertVolume == 0.5)
        #expect(alertSoundService.volume == 0.5)

        store.updateAlertVolume(1.4)
        #expect(store.alertVolume == 1)
        #expect(alertSoundService.volume == 1)

        store.updateAlertVolume(-0.2)
        #expect(store.alertVolume == 0)
        #expect(alertSoundService.volume == 0)
    }

    @Test func resolutionDetectorRecognizesSupportedExactResolutions() async throws {
        let detector = MapleStoryResolutionDetector()

        let standardResult = try #require(
            detector.detectResolution(pixelWidth: 1024, pixelHeight: 768)
        )
        #expect(standardResult.resolution == .size1024x768)
        #expect(standardResult.scale == 1)

        let hdResult = try #require(
            detector.detectResolution(pixelWidth: 1280, pixelHeight: 720)
        )
        #expect(hdResult.resolution == .size1280x720)
        #expect(hdResult.scale == 1)

        let wideResult = try #require(
            detector.detectResolution(pixelWidth: 1366, pixelHeight: 768)
        )
        #expect(wideResult.resolution == .size1366x768)
        #expect(wideResult.scale == 1)
    }

    @Test func resolutionDetectorRecognizesScaledCaptures() async throws {
        let detector = MapleStoryResolutionDetector()

        let retinaResult = try #require(
            detector.detectResolution(pixelWidth: 2048, pixelHeight: 1536)
        )
        #expect(retinaResult.resolution == .size1024x768)
        #expect(retinaResult.scale == 2)

        let scaledHDResult = try #require(
            detector.detectResolution(pixelWidth: 1920, pixelHeight: 1080)
        )
        #expect(scaledHDResult.resolution == .size1280x720)
        #expect(scaledHDResult.scale == 1.5)

        let scaledWideResult = try #require(
            detector.detectResolution(pixelWidth: 2732, pixelHeight: 1536)
        )
        #expect(scaledWideResult.resolution == .size1366x768)
        #expect(scaledWideResult.scale == 2)
    }

    @Test func resolutionDetectorRejectsUnsupportedResolution() async throws {
        let detector = MapleStoryResolutionDetector()

        #expect(detector.detectResolution(pixelWidth: 1440, pixelHeight: 900) == nil)
    }

    @Test func skillDefinitionResolvesLevelBasedValues() async throws {
        let skill = SkillDefinition(
            id: "test-skill",
            displayName: "테스트 스킬",
            iconTemplate: SkillIconTemplate(
                pngData: Data([1, 2, 3]),
                pixelWidth: 32,
                pixelHeight: 32
            ),
            maxLevel: 30,
            cooldownSecondsByLevel: [
                1: 90,
                10: 80,
                20: 60
            ],
            durationSecondsByLevel: [
                1: 20,
                20: 40
            ]
        )

        #expect(skill.cooldownSeconds(for: 0) == 90)
        #expect(skill.cooldownSeconds(for: 15) == 80)
        #expect(skill.cooldownSeconds(for: 30) == 60)
        #expect(skill.durationSeconds(for: 30) == 40)
    }

    @Test func skillTrackingRegistrationCreatesTimerAndDetectionRule() async throws {
        let timerStore = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())
        let ruleStore = SkillDetectionRuleStore()
        let trackedSkillStore = TrackedSkillStore()
        let skill = SkillDefinition(
            id: "tracked-skill",
            displayName: "추적 스킬",
            iconTemplate: SkillIconTemplate(
                pngData: Data([4, 5, 6]),
                pixelWidth: 32,
                pixelHeight: 32
            ),
            maxLevel: 30,
            cooldownSecondsByLevel: [
                1: 45,
                30: 30
            ]
        )

        let trackedSkill = try #require(
            SkillTrackingRegistrationService().register(
                skill: skill,
                level: 30,
                alertBeforeSeconds: 5,
                timerStore: timerStore,
                ruleStore: ruleStore,
                trackedSkillStore: trackedSkillStore
            )
        )
        let timer = try #require(timerStore.skillTimers.first)
        let rule = try #require(ruleStore.rules.first)

        #expect(timer.name == "추적 스킬")
        #expect(timer.cooldownSeconds == 30)
        #expect(rule.skillTimerID == timer.id)
        #expect(rule.skillDefinitionID == skill.id)
        #expect(rule.detectionMode == .locateIcon)
        #expect(rule.iconTemplate == skill.iconTemplate)
        #expect(trackedSkill.skillTimerID == timer.id)
        #expect(trackedSkill.detectionRuleID == rule.id)
        #expect(trackedSkillStore.trackedSkills == [trackedSkill])
    }

    @Test func skillDetectionServiceEmitsOnlyReadyToCooldownTransitions() async throws {
        let timerID = UUID()
        let rule = SkillDetectionRule(
            skillTimerID: timerID,
            displayName: "전이 감지 스킬",
            detectionMode: .fixedRegion,
            matchThreshold: 0.8
        )
        let detector = SequencedCooldownStateDetector(
            states: [
                (.ready, 0.99),
                (.cooldown, 0.92),
                (.cooldown, 0.93)
            ]
        )
        let service = SkillDetectionService(cooldownStateDetector: detector)
        let firstFrameDate = Date()
        let firstFrame = ScreenCaptureFrame(
            image: makeTestImage(width: 1280, height: 720),
            capturedAt: firstFrameDate
        )
        let secondFrame = ScreenCaptureFrame(
            image: makeTestImage(width: 1280, height: 720),
            capturedAt: firstFrameDate.addingTimeInterval(0.35)
        )
        let thirdFrame = ScreenCaptureFrame(
            image: makeTestImage(width: 1280, height: 720),
            capturedAt: firstFrameDate.addingTimeInterval(0.7)
        )

        let firstResults = try await service.detectSkills(
            in: firstFrame,
            using: [rule]
        )
        let secondResults = try await service.detectSkills(
            in: secondFrame,
            using: [rule]
        )
        let thirdResults = try await service.detectSkills(
            in: thirdFrame,
            using: [rule]
        )

        #expect(firstResults.isEmpty)
        #expect(secondResults.isEmpty)
        #expect(thirdResults.count == 1)
        #expect(thirdResults.first?.ruleID == rule.id)
        #expect(thirdResults.first?.skillTimerID == timerID)
        #expect(thirdResults.first?.confidence == 0.93)
    }

    @Test func iconLocatorFindsRegisteredSkillIconInFrame() async throws {
        let iconImage = makeTestSkillIconImage(width: 32, height: 32)
        let iconTemplate = SkillIconTemplate(
            pngData: try #require(pngData(from: iconImage)),
            pixelWidth: 32,
            pixelHeight: 32
        )
        let frameImage = makeFrameImage(
            width: 160,
            height: 120,
            iconImage: iconImage,
            iconRect: CGRect(x: 56, y: 44, width: 32, height: 32),
            isCooldown: false
        )
        let frame = ScreenCaptureFrame(
            image: frameImage,
            capturedAt: Date()
        )

        let location = try #require(
            SkillIconLocator(minimumConfidence: 0.75).locateIcon(
                matching: iconTemplate,
                in: frame,
                searchRegion: .fullScreen
            )
        )
        let locatedRect = location.region.pixelRect(
            pixelWidth: frameImage.width,
            pixelHeight: frameImage.height
        )

        #expect(abs(locatedRect.minX - 56) <= 3)
        #expect(abs(locatedRect.minY - 44) <= 2)
        #expect(location.confidence > 0.8)
    }

    @Test func fixedRegionSkillDetectionTriggersOnConfirmedCooldownTransition() async throws {
        let iconImage = makeTestSkillIconImage(width: 32, height: 32)
        let iconTemplate = SkillIconTemplate(
            pngData: try #require(pngData(from: iconImage)),
            pixelWidth: 32,
            pixelHeight: 32
        )
        let timerID = UUID()
        let iconRect = CGRect(x: 56, y: 44, width: 32, height: 32)
        let rule = SkillDetectionRule(
            skillTimerID: timerID,
            displayName: "이미지 감지 스킬",
            detectionMode: .fixedRegion,
            iconTemplate: iconTemplate,
            screenRegion: .fromPixelRect(
                iconRect,
                pixelWidth: 160,
                pixelHeight: 120
            ),
            matchThreshold: 0.35
        )
        let startedAt = Date()
        let readyFrame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: false
            ),
            capturedAt: startedAt
        )
        let firstCooldownFrame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: true
            ),
            capturedAt: startedAt.addingTimeInterval(0.35)
        )
        let confirmedCooldownFrame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: true
            ),
            capturedAt: startedAt.addingTimeInterval(0.7)
        )
        let service = SkillDetectionService(
            iconLocator: SkillIconLocator(minimumConfidence: 0.75),
            cooldownStateDetector: SequencedCooldownStateDetector(
                states: [
                    (.ready, 0.98),
                    (.cooldown, 0.82),
                    (.cooldown, 0.84)
                ]
            )
        )

        let readyResults = try await service.detectSkills(
            in: readyFrame,
            using: [rule]
        )
        let firstCooldownResults = try await service.detectSkills(
            in: firstCooldownFrame,
            using: [rule]
        )
        let confirmedCooldownResults = try await service.detectSkills(
            in: confirmedCooldownFrame,
            using: [rule]
        )

        #expect(readyResults.isEmpty)
        #expect(firstCooldownResults.isEmpty)
        #expect(confirmedCooldownResults.count == 1)
        #expect(confirmedCooldownResults.first?.ruleID == rule.id)
        #expect(confirmedCooldownResults.first?.skillTimerID == timerID)
        #expect(confirmedCooldownResults.first?.confidence == 0.84)
    }

    @Test func experienceBuffDetectorKeepsDarkenedIconActiveWithMinuteOverlay() async throws {
        let iconImage = makeTestSkillIconImage(width: 32, height: 32)
        let iconTemplate = SkillIconTemplate(
            pngData: try #require(pngData(from: iconImage)),
            pixelWidth: 32,
            pixelHeight: 32
        )
        let entry = ExperienceBuffEntry(id: "경험치", iconTemplate: iconTemplate, iconName: "경험치")
        let iconRect = CGRect(x: 64, y: 36, width: 32, height: 32)
        let startedAt = Date()
        let cleanActiveFrame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: false
            ),
            capturedAt: startedAt
        )
        let darkenedActiveFrame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: false,
                showsBuffMinuteOverlay: true,
                buffDarkeningAlpha: 0.15
            ),
            capturedAt: startedAt.addingTimeInterval(1)
        )
        let expiredFrame = ScreenCaptureFrame(
            image: makeTestImage(width: 160, height: 120),
            capturedAt: startedAt.addingTimeInterval(2)
        )
        let service = ExperienceBuffDetectionService(searchRegion: .fullScreen)

        let cleanActiveResult = try #require(
            try await service.detectExperienceBuffs(
                in: cleanActiveFrame,
                entries: [entry]
            ).first
        )
        let darkenedActiveResult = try #require(
            try await service.detectExperienceBuffs(
                in: darkenedActiveFrame,
                entries: [entry]
            ).first
        )
        let expiredResult = try #require(
            try await service.detectExperienceBuffs(
                in: expiredFrame,
                entries: [entry]
            ).first
        )

        #expect(cleanActiveResult.isActive == true)
        #expect(darkenedActiveResult.isActive == true)
        // 다중 스케일 매칭이라 어두워진 버전은 약간 다른 배율을 고를 수 있으므로
        // 정확 일치 대신 같은 위치(중심점 근접)를 가리키는지 확인한다.
        let cleanRegion = try #require(cleanActiveResult.iconRegion)
        let darkenedRegion = try #require(darkenedActiveResult.iconRegion)
        let cleanCenterX = cleanRegion.x + (cleanRegion.width / 2)
        let cleanCenterY = cleanRegion.y + (cleanRegion.height / 2)
        let darkenedCenterX = darkenedRegion.x + (darkenedRegion.width / 2)
        let darkenedCenterY = darkenedRegion.y + (darkenedRegion.height / 2)
        #expect(abs(cleanCenterX - darkenedCenterX) < 0.05)
        #expect(abs(cleanCenterY - darkenedCenterY) < 0.05)
        #expect(expiredResult.isActive == false)
    }

    @Test func experienceBuffDetectorFindsLiveIconWithMinuteOverlay() async throws {
        let iconImage = makeTestSkillIconImage(width: 32, height: 32)
        let iconTemplate = SkillIconTemplate(
            pngData: try #require(pngData(from: iconImage)),
            pixelWidth: 32,
            pixelHeight: 32
        )
        let entry = ExperienceBuffEntry(id: "경험치", iconTemplate: iconTemplate, iconName: "경험치")
        let iconRect = CGRect(x: 64, y: 36, width: 32, height: 32)
        // 실제 버프 아이콘은 밝은 상태로 남은 시간 숫자만 덧그려진다.
        let frame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: false,
                showsBuffMinuteOverlay: true,
                buffDarkeningAlpha: 0.15
            ),
            capturedAt: Date()
        )
        let service = ExperienceBuffDetectionService(searchRegion: .fullScreen)

        let result = try #require(
            try await service.detectExperienceBuffs(
                in: frame,
                entries: [entry]
            ).first
        )

        #expect(result.isActive == true)
        #expect(result.confidence >= 0.35)
    }

    @Test func experienceBuffDetectorIgnoresIconOutsideSearchRegion() async throws {
        let iconImage = makeTestSkillIconImage(width: 32, height: 32)
        let iconTemplate = SkillIconTemplate(
            pngData: try #require(pngData(from: iconImage)),
            pixelWidth: 32,
            pixelHeight: 32
        )
        let entry = ExperienceBuffEntry(id: "경험치", iconTemplate: iconTemplate, iconName: "경험치")
        // 아이콘을 좌측(x 0.4~0.6)에 배치한다.
        let iconRect = CGRect(x: 64, y: 36, width: 32, height: 32)
        let frame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: false
            ),
            capturedAt: Date()
        )

        // 검색 영역을 아이콘이 없는 좌측 일부로 제한하면 감지되지 않는다.
        let restricted = ExperienceBuffDetectionService(
            searchRegion: NormalizedScreenRegion(x: 0, y: 0, width: 0.3, height: 1)
        )
        let restrictedResult = try #require(
            try await restricted.detectExperienceBuffs(in: frame, entries: [entry]).first
        )
        #expect(restrictedResult.isActive == false)

        // 전체 화면 검색이면 동일 프레임에서 감지된다.
        let fullScreen = ExperienceBuffDetectionService(searchRegion: .fullScreen)
        let fullResult = try #require(
            try await fullScreen.detectExperienceBuffs(in: frame, entries: [entry]).first
        )
        #expect(fullResult.isActive == true)
    }

    @Test func autoTriggerCoordinatorStartsDetectedTimerOnce() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())
        store.addTimer(
            name: "감지 스킬",
            cooldownSeconds: 20,
            alertBeforeSeconds: 5,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        let rule = SkillDetectionRule(
            skillTimerID: timerID,
            displayName: "감지 스킬",
            matchThreshold: 0.8
        )
        let detectedAt = Date()
        let result = SkillDetectionResult(
            ruleID: rule.id,
            skillTimerID: timerID,
            confidence: 0.95,
            detectedAt: detectedAt
        )
        let frame = ScreenCaptureFrame(
            image: makeTestImage(width: 1280, height: 720),
            capturedAt: detectedAt
        )
        let coordinator = SkillAutoTriggerCoordinator(
            screenCaptureService: StubScreenCaptureService(frame: frame),
            skillDetectionService: StubSkillDetectionService(results: [result])
        )

        coordinator.start()
        try await coordinator.processOnce(
            using: [rule],
            timerStore: store
        )

        #expect(coordinator.lastDetectedResult == result)
        #expect(coordinator.lastDetectedResolution?.resolution == .size1280x720)
        #expect(coordinator.lastTriggeredSkillTimerID == timerID)
        #expect(store.skillTimers.first?.isRunning == true)
        #expect(store.skillTimers.first?.remainingSeconds == 20)

        store.stopTimer(id: timerID)
        try await coordinator.processOnce(
            using: [rule],
            timerStore: store
        )

        #expect(store.skillTimers.first?.isRunning == false)
    }

    @Test func autoTriggerCoordinatorAlertsWhenExperienceBuffExpiresAfterBeingActive() async throws {
        let alertService = NoopAlertNotificationService()
        let timerStore = SkillTimerStore(alertNotificationService: alertService)
        let suiteName = UUID().uuidString
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        let preset = ExperienceBuffPreset(
            id: "경험치",
            displayName: "경험치",
            iconTemplate: SkillIconTemplate(pngData: Data([0x1]), pixelWidth: 1, pixelHeight: 1)
        )
        let experienceBuffStore = ExperienceBuffAlertStore(
            userDefaults: userDefaults,
            presets: [preset]
        )
        experienceBuffStore.setTracked(presetID: preset.id, isTracked: true)
        let entryID = preset.id
        let frame = ScreenCaptureFrame(
            image: makeTestImage(width: 1280, height: 720),
            capturedAt: Date()
        )
        let coordinator = SkillAutoTriggerCoordinator(
            screenCaptureService: StubScreenCaptureService(frame: frame),
            skillDetectionService: StubSkillDetectionService(results: []),
            experienceBuffDetectionService: StubExperienceBuffDetectionService(resultsSequence: [
                [
                    ExperienceBuffDetectionResult(
                        entryID: entryID,
                        isActive: true,
                        confidence: 0.8,
                        detectedAt: frame.capturedAt,
                        iconRegion: .fullScreen
                    )
                ],
                [
                    ExperienceBuffDetectionResult(
                        entryID: entryID,
                        isActive: false,
                        confidence: 0,
                        detectedAt: frame.capturedAt.addingTimeInterval(0.35),
                        iconRegion: nil
                    )
                ],
                [
                    ExperienceBuffDetectionResult(
                        entryID: entryID,
                        isActive: false,
                        confidence: 0,
                        detectedAt: frame.capturedAt.addingTimeInterval(0.7),
                        iconRegion: nil
                    )
                ]
            ]),
            experienceBuffMissingFrameThreshold: 2
        )

        coordinator.start()
        try await coordinator.processOnce(
            using: [],
            timerStore: timerStore,
            experienceBuffStore: experienceBuffStore
        )
        try await coordinator.processOnce(
            using: [],
            timerStore: timerStore,
            experienceBuffStore: experienceBuffStore
        )
        #expect(alertService.experienceBuffExpiredCount == 0)

        try await coordinator.processOnce(
            using: [],
            timerStore: timerStore,
            experienceBuffStore: experienceBuffStore
        )

        #expect(alertService.experienceBuffExpiredCount == 1)
        #expect(coordinator.lastExperienceBuffAlertMessage == "경험치 꺼짐")
    }

    @Test func autoTriggerCoordinatorUsesUserSelectedWindowTarget() async throws {
        let frame = ScreenCaptureFrame(
            image: makeTestImage(width: 1366, height: 768),
            capturedAt: Date()
        )
        let captureService = StubScreenCaptureService(
            frame: frame,
            userSelectedCaptureSource: UserSelectedCaptureSource(
                displayName: "MapleStory",
                contentRect: CGRect(x: 0, y: 0, width: 1366, height: 768),
                pointPixelScale: 1
            )
        )
        let coordinator = SkillAutoTriggerCoordinator(
            screenCaptureService: captureService,
            skillDetectionService: StubSkillDetectionService(results: [])
        )

        await coordinator.requestUserSelectedWindow()
        coordinator.start()

        try await coordinator.processOnce(using: [])

        #expect(coordinator.userSelectedCaptureSource?.displayName == "MapleStory")
        #expect(captureService.didRequestUserSelectedWindow == true)
        #expect(captureService.captureFrameCallCount == 1)
        #expect(coordinator.lastDetectedResolution?.resolution == .size1366x768)
    }

    @Test func startMonitoringRequestsPermissionWhenScreenCapturePermissionIsMissing() async throws {
        let captureService = StubScreenCaptureService(
            frame: nil,
            hasScreenCapturePermission: false,
            permissionRequestResult: false
        )
        let coordinator = SkillAutoTriggerCoordinator(
            screenCaptureService: captureService,
            skillDetectionService: StubSkillDetectionService(results: []),
            detectionInterval: 10
        )

        await coordinator.startMonitoring(
            timerStore: SkillTimerStore(alertNotificationService: NoopAlertNotificationService()),
            ruleStore: SkillDetectionRuleStore()
        )

        #expect(captureService.didRequestScreenCapturePermission == true)
        #expect(captureService.didRequestUserSelectedWindow == false)
        #expect(coordinator.isRunning == false)
        #expect(coordinator.lastErrorMessage != nil)
    }

    @Test func startMonitoringRequestsWindowSelectionBeforeRunning() async throws {
        let captureService = StubScreenCaptureService(
            frame: nil,
            userSelectedCaptureSource: UserSelectedCaptureSource(
                displayName: "MapleStory",
                contentRect: CGRect(x: 0, y: 0, width: 1024, height: 768),
                pointPixelScale: 1
            )
        )
        let coordinator = SkillAutoTriggerCoordinator(
            screenCaptureService: captureService,
            skillDetectionService: StubSkillDetectionService(results: []),
            detectionInterval: 10
        )

        await coordinator.startMonitoring(
            timerStore: SkillTimerStore(alertNotificationService: NoopAlertNotificationService()),
            ruleStore: SkillDetectionRuleStore()
        )

        #expect(captureService.didRequestScreenCapturePermission == false)
        #expect(captureService.didRequestUserSelectedWindow == true)
        #expect(coordinator.userSelectedCaptureSource?.displayName == "MapleStory")
        #expect(coordinator.isRunning == true)

        coordinator.stop()
    }

    @Test func menuBarStatusHighlightsWarningAndReadyTimers() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "임박 스킬",
            cooldownSeconds: 3,
            alertBeforeSeconds: 2,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        store.toggleTimer(id: timerID)
        store.tick()

        #expect(store.menuBarStatus.tone == .warning)
        #expect(store.menuBarStatus.title == "임박 스킬 00:02 남음")

        store.tick()
        store.tick()

        #expect(store.menuBarStatus.tone == .ready)
        #expect(store.menuBarStatus.title == "임박 스킬 사용 가능")
    }

    @Test func alertPopupPlacementConvertsBetweenNormalizedAndScreenOrigin() async throws {
        let screenFrame = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let panelSize = CGSize(width: 200, height: 100)
        let placement = AlertPopupPlacement(normalizedX: 0.5, normalizedY: 0.25)

        let origin = placement.popupOrigin(panelSize: panelSize, in: screenFrame)

        #expect(origin.x == 500)
        #expect(origin.y == 575)

        let restoredPlacement = AlertPopupPlacement.placement(
            from: origin,
            panelSize: panelSize,
            in: screenFrame
        )

        #expect(restoredPlacement == placement)
    }

    @Test func alertPopupPlacementUsesTopLeftCoordinateSemantics() async throws {
        let screenFrame = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let panelSize = CGSize(width: 200, height: 100)

        let topLeftPlacement = AlertPopupPlacement(
            normalizedX: 0,
            normalizedY: 0
        )
        let topLeftOrigin = topLeftPlacement.popupOrigin(panelSize: panelSize, in: screenFrame)

        #expect(topLeftOrigin.x == 100)
        #expect(topLeftOrigin.y == 750)
        #expect(topLeftPlacement.displayText == "왼쪽 100% · 위쪽 100%")

        let bottomRightPlacement = AlertPopupPlacement(
            normalizedX: 1,
            normalizedY: 1
        )
        let bottomRightOrigin = bottomRightPlacement.popupOrigin(panelSize: panelSize, in: screenFrame)

        #expect(bottomRightOrigin.x == 900)
        #expect(bottomRightOrigin.y == 50)
        #expect(bottomRightPlacement.displayText == "왼쪽 0% · 위쪽 0%")
    }

}

private final class NoopAlertNotificationService: AlertNotificationProviding {
    var popupPlacement: AlertPopupPlacement = .defaultValue
    var preAlertTimerIDs: [SkillTimer.ID] = []
    var readyAlertTimerIDs: [SkillTimer.ID] = []
    var experienceBuffExpiredCount = 0

    func requestAuthorization() {}

    func notifyPreAlert(for timer: SkillTimer) {
        preAlertTimerIDs.append(timer.id)
    }

    func notifyReadyAlert(for timer: SkillTimer) {
        readyAlertTimerIDs.append(timer.id)
    }

    func notifyExperienceBuffExpired(name: String) {
        experienceBuffExpiredCount += 1
    }

    func beginPopupPlacementSelection(
        initialPlacement: AlertPopupPlacement,
        completion: @escaping (AlertPopupPlacement) -> Void
    ) {}
}

private final class StubScreenCaptureService: ScreenCaptureProviding {
    private let frame: ScreenCaptureFrame?
    private let userSelectedCaptureSource: UserSelectedCaptureSource?
    private let permissionRequestResult: Bool
    private(set) var hasScreenCapturePermission: Bool
    private(set) var captureFrameCallCount = 0
    private(set) var didRequestScreenCapturePermission = false
    private(set) var didRequestUserSelectedWindow = false

    init(
        frame: ScreenCaptureFrame?,
        hasScreenCapturePermission: Bool = true,
        permissionRequestResult: Bool = true,
        userSelectedCaptureSource: UserSelectedCaptureSource? = nil
    ) {
        self.frame = frame
        self.hasScreenCapturePermission = hasScreenCapturePermission
        self.permissionRequestResult = permissionRequestResult
        self.userSelectedCaptureSource = userSelectedCaptureSource
    }

    func requestScreenCapturePermissionIfNeeded() -> Bool {
        guard !hasScreenCapturePermission else {
            return true
        }

        didRequestScreenCapturePermission = true

        if permissionRequestResult {
            hasScreenCapturePermission = true
        }

        return permissionRequestResult
    }

    func requestUserSelectedWindow() async throws -> UserSelectedCaptureSource {
        didRequestUserSelectedWindow = true

        if let userSelectedCaptureSource {
            return userSelectedCaptureSource
        }

        throw StubCaptureError.userSelectedWindowUnavailable
    }

    func captureFrame() async throws -> ScreenCaptureFrame? {
        captureFrameCallCount += 1
        return frame
    }
}

private enum StubCaptureError: LocalizedError {
    case userSelectedWindowUnavailable

    var errorDescription: String? {
        "직접 선택한 창이 없습니다."
    }
}

private final class StubSkillDetectionService: SkillDetectionProviding {
    private let results: [SkillDetectionResult]

    init(results: [SkillDetectionResult]) {
        self.results = results
    }

    func detectSkills(
        in frame: ScreenCaptureFrame,
        using rules: [SkillDetectionRule]
    ) async throws -> [SkillDetectionResult] {
        results
    }
}

private final class StubExperienceBuffDetectionService: ExperienceBuffDetecting {
    private let resultsSequence: [[ExperienceBuffDetectionResult]]
    private var currentIndex = 0

    init(resultsSequence: [[ExperienceBuffDetectionResult]]) {
        self.resultsSequence = resultsSequence
    }

    func detectExperienceBuffs(
        in frame: ScreenCaptureFrame,
        entries: [ExperienceBuffEntry]
    ) async throws -> [ExperienceBuffDetectionResult] {
        guard !resultsSequence.isEmpty else {
            return []
        }

        let resolvedIndex = min(currentIndex, resultsSequence.count - 1)
        currentIndex += 1
        return resultsSequence[resolvedIndex]
    }
}

private final class SequencedCooldownStateDetector: SkillCooldownStateDetecting {
    private let states: [(SkillSlotVisualState, Double)]
    private var currentIndex = 0

    init(states: [(SkillSlotVisualState, Double)]) {
        self.states = states
    }

    func detectState(
        in frame: ScreenCaptureFrame,
        rule: SkillDetectionRule,
        slotRegion: NormalizedScreenRegion
    ) -> SkillCooldownStateDetection {
        let state: SkillSlotVisualState
        let confidence: Double

        if states.isEmpty {
            state = .unknown
            confidence = 0
        } else {
            let resolvedIndex = min(currentIndex, states.count - 1)
            state = states[resolvedIndex].0
            confidence = states[resolvedIndex].1
            currentIndex += 1
        }

        return SkillCooldownStateDetection(
            state: state,
            confidence: confidence,
            slotRegion: slotRegion
        )
    }
}

private func makeTestImage(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )

    context?.setFillColor(CGColor(gray: 0, alpha: 1))
    context?.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context?.makeImage() else {
        preconditionFailure("Failed to create test image")
    }

    return image
}

private func makeTestSkillIconImage(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )

    context?.setAllowsAntialiasing(false)
    context?.setFillColor(CGColor(gray: 0.08, alpha: 1))
    context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context?.setFillColor(CGColor(red: 0.22, green: 0.14, blue: 0.55, alpha: 1))
    context?.fill(CGRect(x: 3, y: 3, width: width - 6, height: height - 6))
    context?.setStrokeColor(CGColor(red: 0.9, green: 0.85, blue: 1, alpha: 1))
    context?.setLineWidth(3)
    context?.strokeEllipse(in: CGRect(x: 8, y: 8, width: width - 16, height: height - 16))
    context?.setFillColor(CGColor(red: 0.75, green: 0.65, blue: 1, alpha: 1))
    context?.fill(CGRect(x: 14, y: 5, width: 4, height: height - 10))
    context?.fill(CGRect(x: 5, y: 14, width: width - 10, height: 4))

    guard let image = context?.makeImage() else {
        preconditionFailure("Failed to create test skill icon")
    }

    return image
}

private func makeFrameImage(
    width: Int,
    height: Int,
    iconImage: CGImage,
    iconRect: CGRect,
    isCooldown: Bool,
    showsTimeOverlay: Bool = false,
    showsBuffMinuteOverlay: Bool = false,
    buffDarkeningAlpha: Double = 0
) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )

    context?.setAllowsAntialiasing(false)
    context?.setFillColor(CGColor(gray: 0.02, alpha: 1))
    context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context?.setFillColor(CGColor(gray: 0.1, alpha: 1))
    context?.fill(CGRect(x: 0, y: height - 48, width: width, height: 48))
    context?.interpolationQuality = .none
    context?.draw(iconImage, in: iconRect)

    if buffDarkeningAlpha > 0 {
        context?.setFillColor(CGColor(gray: 0, alpha: CGFloat(min(max(buffDarkeningAlpha, 0), 1))))
        context?.fill(iconRect)
    }

    if isCooldown {
        context?.setFillColor(CGColor(gray: 0, alpha: 0.55))
        context?.fill(iconRect)
        context?.setFillColor(CGColor(red: 1, green: 0.9, blue: 0.08, alpha: 1))
        context?.fill(CGRect(x: iconRect.minX + 11, y: iconRect.minY + 9, width: 4, height: 15))
        context?.fill(CGRect(x: iconRect.minX + 18, y: iconRect.minY + 9, width: 4, height: 15))
        context?.fill(CGRect(x: iconRect.minX + 11, y: iconRect.minY + 21, width: 11, height: 4))
    }

    if showsTimeOverlay {
        context?.setFillColor(CGColor(gray: 0, alpha: 0.35))
        context?.fill(CGRect(x: iconRect.minX + 5, y: iconRect.minY + 8, width: 22, height: 16))
        context?.setFillColor(CGColor(red: 1, green: 0.95, blue: 0.24, alpha: 1))
        context?.fill(CGRect(x: iconRect.minX + 10, y: iconRect.minY + 10, width: 3, height: 12))
        context?.fill(CGRect(x: iconRect.minX + 15, y: iconRect.minY + 10, width: 8, height: 3))
        context?.fill(CGRect(x: iconRect.minX + 20, y: iconRect.minY + 13, width: 3, height: 4))
        context?.fill(CGRect(x: iconRect.minX + 15, y: iconRect.minY + 18, width: 8, height: 3))
    }

    if showsBuffMinuteOverlay {
        fillSegmentDigitThree(
            in: context,
            origin: CGPoint(x: iconRect.minX + 1, y: iconRect.minY + 1),
            color: CGColor(gray: 0.02, alpha: 1)
        )
        fillSegmentDigitThree(
            in: context,
            origin: CGPoint(x: iconRect.minX, y: iconRect.minY + 2),
            color: CGColor(red: 0.82, green: 0.9, blue: 1, alpha: 1)
        )

        context?.setFillColor(CGColor(gray: 0.02, alpha: 1))
        context?.fill(CGRect(x: iconRect.maxX - 10, y: iconRect.maxY - 6, width: 9, height: 2))
        context?.fill(CGRect(x: iconRect.maxX - 4, y: iconRect.maxY - 10, width: 2, height: 7))
    }

    guard let image = context?.makeImage() else {
        preconditionFailure("Failed to create frame image")
    }

    return image
}

private func fillSegmentDigitThree(
    in context: CGContext?,
    origin: CGPoint,
    color: CGColor
) {
    context?.setFillColor(color)
    context?.fill(CGRect(x: origin.x, y: origin.y, width: 8, height: 2))
    context?.fill(CGRect(x: origin.x + 6, y: origin.y + 2, width: 2, height: 4))
    context?.fill(CGRect(x: origin.x + 1, y: origin.y + 6, width: 7, height: 2))
    context?.fill(CGRect(x: origin.x + 6, y: origin.y + 8, width: 2, height: 4))
    context?.fill(CGRect(x: origin.x, y: origin.y + 12, width: 8, height: 2))
}

private func pngData(from image: CGImage) -> Data? {
    NSBitmapImageRep(cgImage: image).representation(
        using: .png,
        properties: [:]
    )
}
