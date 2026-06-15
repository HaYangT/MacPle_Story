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
        #expect(secondResults.count == 1)
        #expect(secondResults.first?.ruleID == rule.id)
        #expect(secondResults.first?.skillTimerID == timerID)
        #expect(secondResults.first?.confidence == 0.92)
        #expect(thirdResults.isEmpty)
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

        #expect(abs(locatedRect.minX - 56) <= 2)
        #expect(abs(locatedRect.minY - 44) <= 2)
        #expect(location.confidence > 0.9)
    }

    @Test func imageBasedSkillDetectionTriggersOnIconCooldownTransition() async throws {
        let iconImage = makeTestSkillIconImage(width: 32, height: 32)
        let iconTemplate = SkillIconTemplate(
            pngData: try #require(pngData(from: iconImage)),
            pixelWidth: 32,
            pixelHeight: 32
        )
        let timerID = UUID()
        let rule = SkillDetectionRule(
            skillTimerID: timerID,
            displayName: "이미지 감지 스킬",
            detectionMode: .locateIcon,
            iconTemplate: iconTemplate,
            matchThreshold: 0.55
        )
        let iconRect = CGRect(x: 56, y: 44, width: 32, height: 32)
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
        let cooldownFrame = ScreenCaptureFrame(
            image: makeFrameImage(
                width: 160,
                height: 120,
                iconImage: iconImage,
                iconRect: iconRect,
                isCooldown: true
            ),
            capturedAt: startedAt.addingTimeInterval(0.35)
        )
        let service = SkillDetectionService(
            iconLocator: SkillIconLocator(minimumConfidence: 0.75),
            cooldownStateDetector: SkillCooldownStateDetector(
                cooldownConfidenceThreshold: 0.45
            )
        )

        let readyResults = try await service.detectSkills(
            in: readyFrame,
            using: [rule]
        )
        let cooldownResults = try await service.detectSkills(
            in: cooldownFrame,
            using: [rule]
        )

        #expect(readyResults.isEmpty)
        #expect(cooldownResults.count == 1)
        #expect(cooldownResults.first?.ruleID == rule.id)
        #expect(cooldownResults.first?.skillTimerID == timerID)
        #expect((cooldownResults.first?.confidence ?? 0) >= 0.45)
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

    func requestAuthorization() {}

    func notifyPreAlert(for timer: SkillTimer) {
        preAlertTimerIDs.append(timer.id)
    }

    func notifyReadyAlert(for timer: SkillTimer) {
        readyAlertTimerIDs.append(timer.id)
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
    isCooldown: Bool
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

    if isCooldown {
        context?.setFillColor(CGColor(gray: 0, alpha: 0.55))
        context?.fill(iconRect)
        context?.setFillColor(CGColor(red: 1, green: 0.9, blue: 0.08, alpha: 1))
        context?.fill(CGRect(x: iconRect.minX + 11, y: iconRect.minY + 9, width: 4, height: 15))
        context?.fill(CGRect(x: iconRect.minX + 18, y: iconRect.minY + 9, width: 4, height: 15))
        context?.fill(CGRect(x: iconRect.minX + 11, y: iconRect.minY + 21, width: 11, height: 4))
    }

    guard let image = context?.makeImage() else {
        preconditionFailure("Failed to create frame image")
    }

    return image
}

private func pngData(from image: CGImage) -> Data? {
    NSBitmapImageRep(cgImage: image).representation(
        using: .png,
        properties: [:]
    )
}
