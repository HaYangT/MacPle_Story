//
//  SkillAutoTriggerCoordinator.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Combine
import Foundation

@MainActor
final class SkillAutoTriggerCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var userSelectedCaptureSource: UserSelectedCaptureSource?
    @Published private(set) var isPresentingCapturePicker = false
    @Published private(set) var lastWindowRefreshMessage: String?
    @Published private(set) var lastDetectedResult: SkillDetectionResult?
    @Published private(set) var lastDetectionDebugSnapshot: SkillDetectionDebugSnapshot?
    @Published private(set) var lastDetectedResolution: MapleStoryResolutionDetectionResult?
    @Published private(set) var lastTriggeredSkillTimerID: SkillTimer.ID?
    @Published private(set) var lastExperienceBuffDetectionResults: [ExperienceBuffDetectionResult] = []
    @Published private(set) var lastExperienceBuffAlertMessage: String?
    /// 시간 기반 버프의 만료 예정 시각(presetID 기준). UI 카운트다운에 사용.
    @Published private(set) var buffExpiryByEntryID: [String: Date] = [:]
    @Published private(set) var lastErrorMessage: String?

    private let screenCaptureService: ScreenCaptureProviding
    private let skillDetectionService: SkillDetectionProviding
    private let experienceBuffDetectionService: ExperienceBuffDetecting
    private let resolutionDetector: MapleStoryResolutionDetecting
    private let detectionInterval: TimeInterval
    private let triggerLockout: TimeInterval
    private let experienceBuffMissingFrameThreshold: Int
    private let fixedDurationAlertLeadSeconds = 15
    private let buffScanInterval: TimeInterval = 1.0
    private var detectionTask: Task<Void, Never>?
    private var lastTriggeredAtByTimerID: [SkillTimer.ID: Date] = [:]
    private var buffTrackingStateByEntryID: [String: ExperienceBuffTrackingState] = [:]
    private var buffFixedDurationStateByEntryID: [String: FixedDurationAlertState] = [:]
    /// 버프 매칭을 마지막으로 실행한 시각(프레임 시계 기준). lazy 주기 throttle용.
    private var lastBuffScanAt: Date?
    /// 라운드로빈으로 한 틱에 하나의 후보 버프만 매칭하기 위한 인덱스.
    private var buffRoundRobinIndex = 0
    /// 엔트리별 최신 감지 결과(틱 사이 UI 깜빡임 방지용 유지).
    private var lastBuffResultByEntryID: [String: ExperienceBuffDetectionResult] = [:]

    init() {
        self.screenCaptureService = ScreenCaptureService()
        self.skillDetectionService = SkillDetectionService()
        self.experienceBuffDetectionService = ExperienceBuffDetectionService()
        self.resolutionDetector = MapleStoryResolutionDetector()
        self.detectionInterval = 5.0
        self.triggerLockout = 1.5
        self.experienceBuffMissingFrameThreshold = 3
    }

    init(
        screenCaptureService: ScreenCaptureProviding,
        skillDetectionService: SkillDetectionProviding,
        experienceBuffDetectionService: ExperienceBuffDetecting? = nil,
        detectionInterval: TimeInterval = 0.35,
        triggerLockout: TimeInterval = 1.5,
        experienceBuffMissingFrameThreshold: Int = 3
    ) {
        self.screenCaptureService = screenCaptureService
        self.skillDetectionService = skillDetectionService
        self.experienceBuffDetectionService = experienceBuffDetectionService ?? ExperienceBuffDetectionService()
        self.resolutionDetector = MapleStoryResolutionDetector()
        self.detectionInterval = detectionInterval
        self.triggerLockout = triggerLockout
        self.experienceBuffMissingFrameThreshold = max(1, experienceBuffMissingFrameThreshold)
    }

    init(
        screenCaptureService: ScreenCaptureProviding,
        skillDetectionService: SkillDetectionProviding,
        experienceBuffDetectionService: ExperienceBuffDetecting? = nil,
        resolutionDetector: MapleStoryResolutionDetecting,
        detectionInterval: TimeInterval = 0.35,
        triggerLockout: TimeInterval = 1.5,
        experienceBuffMissingFrameThreshold: Int = 3
    ) {
        self.screenCaptureService = screenCaptureService
        self.skillDetectionService = skillDetectionService
        self.experienceBuffDetectionService = experienceBuffDetectionService ?? ExperienceBuffDetectionService()
        self.resolutionDetector = resolutionDetector
        self.detectionInterval = detectionInterval
        self.triggerLockout = triggerLockout
        self.experienceBuffMissingFrameThreshold = max(1, experienceBuffMissingFrameThreshold)
    }

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        lastErrorMessage = nil
    }

    func requestUserSelectedWindow() async {
        guard !isPresentingCapturePicker else {
            return
        }

        isPresentingCapturePicker = true
        defer {
            isPresentingCapturePicker = false
        }

        lastErrorMessage = nil
        lastWindowRefreshMessage = "창 선택 화면에서 메이플스토리 창을 선택해 주세요"

        do {
            let source = try await screenCaptureService.requestUserSelectedWindow()
            userSelectedCaptureSource = source
            lastDetectedResolution = nil
            lastDetectedResult = nil
            lastErrorMessage = nil
            lastWindowRefreshMessage = "직접 선택: \(source.displayName) · \(source.sizeText)"
        } catch {
            lastWindowRefreshMessage = nil
            lastErrorMessage = error.localizedDescription
        }
    }

    /// 메이플 창을 자동 감지해 캡처 대상으로 설정한다. 성공하면 true.
    @discardableResult
    func autoDetectMapleWindow() async -> Bool {
        guard !isPresentingCapturePicker else {
            return false
        }

        do {
            let source = try await screenCaptureService.autoDetectMapleWindow()
            userSelectedCaptureSource = source
            lastDetectedResolution = nil
            lastDetectedResult = nil
            lastErrorMessage = nil
            lastWindowRefreshMessage = "자동 감지: \(source.displayName) · \(source.sizeText)"
            return true
        } catch {
            lastWindowRefreshMessage = "메이플 창 자동 감지 실패 · 직접 선택해 주세요"
            return false
        }
    }

    func startMonitoring(
        timerStore: SkillTimerStore,
        ruleStore: SkillDetectionRuleStore,
        experienceBuffStore: ExperienceBuffAlertStore? = nil
    ) async {
        guard detectionTask == nil else {
            return
        }

        guard requestScreenCapturePermissionIfNeeded() else {
            return
        }

        if userSelectedCaptureSource == nil {
            // 먼저 메이플 창 자동 감지를 시도하고, 실패하면 수동 선택으로 폴백.
            let didAutoDetect = await autoDetectMapleWindow()
            if !didAutoDetect {
                await requestUserSelectedWindow()
            }
        }

        guard userSelectedCaptureSource != nil else {
            return
        }

        start()

        detectionTask = Task { @MainActor [weak self, weak timerStore, weak ruleStore] in
            while !Task.isCancelled {
                guard let self, let timerStore, let ruleStore else {
                    return
                }

                do {
                    try await self.processOnce(
                        using: ruleStore.rules,
                        timerStore: timerStore,
                        experienceBuffStore: experienceBuffStore
                    )
                    self.lastErrorMessage = nil
                } catch {
                    self.lastErrorMessage = error.localizedDescription
                }

                // 스킬 감지가 없으면(버프 전용) 캡처 주기를 버프 스캔 주기로 늦춰 리소스 절약.
                try? await Task.sleep(nanoseconds: self.loopIntervalNanoseconds(skillRules: ruleStore.rules))
            }
        }
    }

    func stop() {
        detectionTask?.cancel()
        detectionTask = nil
        isRunning = false
        lastDetectedResult = nil
        lastDetectionDebugSnapshot = nil
        lastDetectedResolution = nil
        lastTriggeredSkillTimerID = nil
        lastExperienceBuffDetectionResults = []
        lastExperienceBuffAlertMessage = nil
        buffTrackingStateByEntryID = [:]
        buffFixedDurationStateByEntryID = [:]
        buffExpiryByEntryID = [:]
        lastBuffResultByEntryID = [:]
        lastBuffScanAt = nil
        buffRoundRobinIndex = 0
    }

    func processOnce(
        using rules: [SkillDetectionRule],
        timerStore: SkillTimerStore? = nil,
        experienceBuffStore: ExperienceBuffAlertStore? = nil
    ) async throws {
        guard isRunning else {
            lastDetectedResult = nil
            lastExperienceBuffDetectionResults = []
            return
        }

        guard let frame = try await screenCaptureService.captureFrame() else {
            return
        }

        lastDetectedResolution = resolutionDetector.detectResolution(in: frame)
        try await processSkillDetection(
            in: frame,
            using: rules,
            timerStore: timerStore
        )
        try await processExperienceBuffDetection(
            in: frame,
            timerStore: timerStore,
            experienceBuffStore: experienceBuffStore
        )
    }

    private func processSkillDetection(
        in frame: ScreenCaptureFrame,
        using rules: [SkillDetectionRule],
        timerStore: SkillTimerStore?
    ) async throws {
        let enabledRules = rules.filter(\.isEnabled)
        guard !enabledRules.isEmpty else {
            lastDetectedResult = nil
            return
        }

        let rulesByID = Dictionary(
            uniqueKeysWithValues: enabledRules.map { ($0.id, $0) }
        )
        let detectedResult = try await skillDetectionService
            .detectSkills(in: frame, using: enabledRules)
            .filter { result in
                guard let rule = rulesByID[result.ruleID] else {
                    return false
                }

                return result.confidence >= rule.matchThreshold
            }
            .max { lhs, rhs in
                lhs.confidence < rhs.confidence
            }

        lastDetectedResult = detectedResult
        lastDetectionDebugSnapshot = skillDetectionService.lastDebugSnapshot

        guard let detectedResult, let timerStore else {
            return
        }

        triggerTimerIfNeeded(
            for: detectedResult,
            timerStore: timerStore
        )
    }

    private func processExperienceBuffDetection(
        in frame: ScreenCaptureFrame,
        timerStore: SkillTimerStore?,
        experienceBuffStore: ExperienceBuffAlertStore?
    ) async throws {
        guard let timerStore,
              let experienceBuffStore else {
            return
        }

        let activeEntries = experienceBuffStore.activeEntries

        guard !activeEntries.isEmpty else {
            lastExperienceBuffDetectionResults = []
            lastExperienceBuffAlertMessage = nil
            buffTrackingStateByEntryID = [:]
            buffFixedDurationStateByEntryID = [:]
            buffExpiryByEntryID = [:]
            lastBuffResultByEntryID = [:]
            lastBuffScanAt = nil
            return
        }

        pruneExperienceBuffStateCache(keeping: activeEntries.map(\.id))

        let now = frame.capturedAt
        var expiredEntryNames: [String] = []
        var expiringEntryNames: [String] = []

        // 1) 타이머 진행 중인 시간 기반 버프: 매칭 없이 시계로만 발화/만료 처리(매 틱).
        let timingEntries = activeEntries.filter { isFixedDurationTimerRunning($0) }
        let timingIDs = Set(timingEntries.map(\.id))
        for entry in timingEntries {
            guard let durationSeconds = entry.durationSeconds else {
                continue
            }

            if handleFixedDuration(
                entry: entry,
                isActive: true,
                durationSeconds: durationSeconds,
                now: now,
                timerStore: timerStore
            ) {
                expiringEntryNames.append(entry.iconName)
            }

            if buffFixedDurationStateByEntryID[entry.id]?.scheduledFireAt != nil {
                lastBuffResultByEntryID[entry.id] = ExperienceBuffDetectionResult(
                    entryID: entry.id,
                    isActive: true,
                    confidence: 1,
                    detectedAt: now,
                    iconRegion: nil
                )
            } else {
                lastBuffResultByEntryID[entry.id] = nil
            }
        }

        // 2) 나머지(매칭 필요) 버프: lazy 주기 + 라운드로빈으로 한 틱에 하나만 매칭.
        let candidateEntries = activeEntries.filter { !timingIDs.contains($0.id) }
        let shouldScan = lastBuffScanAt.map { now.timeIntervalSince($0) >= buffScanInterval } ?? true

        if shouldScan, !candidateEntries.isEmpty {
            lastBuffScanAt = now
            let entry = candidateEntries[buffRoundRobinIndex % candidateEntries.count]
            buffRoundRobinIndex += 1

            let results = try await experienceBuffDetectionService.detectExperienceBuffs(
                in: frame,
                entries: [entry]
            )

            if let result = results.first {
                lastBuffResultByEntryID[entry.id] = result

                if let durationSeconds = entry.durationSeconds {
                    if handleFixedDuration(
                        entry: entry,
                        isActive: result.isActive,
                        durationSeconds: durationSeconds,
                        now: now,
                        timerStore: timerStore
                    ) {
                        expiringEntryNames.append(entry.iconName)
                    }
                } else {
                    let currentState = buffTrackingStateByEntryID[entry.id] ?? .waitingForActivation
                    let (nextState, didExpire) = currentState.transition(
                        isActive: result.isActive,
                        missingFrameThreshold: experienceBuffMissingFrameThreshold
                    )
                    buffTrackingStateByEntryID[entry.id] = nextState

                    if didExpire {
                        expiredEntryNames.append(entry.iconName)
                        timerStore.playAlertSound(id: entry.alertSoundID)
                        timerStore.notifyExperienceBuffExpired(name: entry.iconName)
                    }
                }
            }
        }

        // 활성 엔트리 기준으로 유지 결과 정리 후 게시.
        let activeIDs = Set(activeEntries.map(\.id))
        lastBuffResultByEntryID = lastBuffResultByEntryID.filter { activeIDs.contains($0.key) }
        lastExperienceBuffDetectionResults = Array(lastBuffResultByEntryID.values)

        updateExperienceBuffMessage(
            results: lastExperienceBuffDetectionResults,
            expiredEntryNames: expiredEntryNames,
            expiringEntryNames: expiringEntryNames
        )
    }

    /// 시간 기반 버프의 타이머가 진행 중인지(= 감지 후 만료 전). 이 동안은 매칭을 건너뛴다.
    private func isFixedDurationTimerRunning(_ entry: ExperienceBuffEntry) -> Bool {
        entry.durationSeconds != nil
            && buffFixedDurationStateByEntryID[entry.id]?.scheduledFireAt != nil
    }

    /// 시간 기반 버프 처리. 알림을 이번에 발화했으면 true.
    /// 감지 시 타이머 예약, (지속시간 − 15초)에 1회 알림, 만료 시각이 지나면 초기화(→ 다음 감지 재개).
    private func handleFixedDuration(
        entry: ExperienceBuffEntry,
        isActive: Bool,
        durationSeconds: Int,
        now: Date,
        timerStore: SkillTimerStore
    ) -> Bool {
        var state = buffFixedDurationStateByEntryID[entry.id] ?? FixedDurationAlertState()

        if isActive, state.scheduledFireAt == nil {
            // 감지 시작 → 알림 예약 + 만료 시각 기록
            let lead = TimeInterval(max(0, durationSeconds - fixedDurationAlertLeadSeconds))
            state.scheduledFireAt = now.addingTimeInterval(lead)
            state.didFire = false
            buffExpiryByEntryID[entry.id] = now.addingTimeInterval(TimeInterval(durationSeconds))
        }

        var didFireNow = false
        if let fireAt = state.scheduledFireAt, !state.didFire, now >= fireAt {
            state.didFire = true
            didFireNow = true
            timerStore.playAlertSound(id: entry.alertSoundID)
            timerStore.notifyExperienceBuffExpiring(
                name: entry.iconName,
                secondsLeft: fixedDurationAlertLeadSeconds
            )
        }

        // 만료 시각 경과 → 초기화. 다음 사이클부터 다시 감지(재사용 대응).
        if let expiry = buffExpiryByEntryID[entry.id], now >= expiry {
            state = FixedDurationAlertState()
            buffExpiryByEntryID[entry.id] = nil
        }

        buffFixedDurationStateByEntryID[entry.id] = state
        return didFireNow
    }

    private func updateExperienceBuffMessage(
        results: [ExperienceBuffDetectionResult],
        expiredEntryNames: [String],
        expiringEntryNames: [String]
    ) {
        let activeCount = results.filter(\.isActive).count
        let alertedCount = buffTrackingStateByEntryID.values.filter { $0.isAlertedInactive }.count

        if !expiringEntryNames.isEmpty {
            lastExperienceBuffAlertMessage = "\(expiringEntryNames.joined(separator: ", ")) 곧 만료"
        } else if !expiredEntryNames.isEmpty {
            lastExperienceBuffAlertMessage = "\(expiredEntryNames.joined(separator: ", ")) 꺼짐"
        } else if alertedCount > 0 {
            lastExperienceBuffAlertMessage = "버프 꺼짐 · 재활성 대기 중"
        } else if activeCount > 0 {
            lastExperienceBuffAlertMessage = "경험치 버프 \(activeCount)개 감지 중"
        } else {
            lastExperienceBuffAlertMessage = "버프 활성화 대기 중"
        }
    }

    private func pruneExperienceBuffStateCache(keeping activeEntryIDs: [String]) {
        let activeSet = Set(activeEntryIDs)
        buffTrackingStateByEntryID = buffTrackingStateByEntryID.filter { activeSet.contains($0.key) }
        buffFixedDurationStateByEntryID = buffFixedDurationStateByEntryID.filter { activeSet.contains($0.key) }
        buffExpiryByEntryID = buffExpiryByEntryID.filter { activeSet.contains($0.key) }
    }

    private var detectionIntervalNanoseconds: UInt64 {
        UInt64(detectionInterval * 1_000_000_000)
    }

    /// 다음 캡처까지 대기 시간. 스킬 감지(쿨다운)는 빠른 프레임이 필요하므로 기본 주기,
    /// 활성 스킬 규칙이 없으면(버프 전용) 버프 스캔 주기로 늦춰 캡처 횟수를 줄인다.
    private func loopIntervalNanoseconds(skillRules: [SkillDetectionRule]) -> UInt64 {
        let hasSkillWork = skillRules.contains(where: \.isEnabled)
        let interval = hasSkillWork ? detectionInterval : max(detectionInterval, buffScanInterval)
        return UInt64(interval * 1_000_000_000)
    }

    private func triggerTimerIfNeeded(
        for result: SkillDetectionResult,
        timerStore: SkillTimerStore
    ) {
        if let lastTriggeredAt = lastTriggeredAtByTimerID[result.skillTimerID],
           result.detectedAt.timeIntervalSince(lastTriggeredAt) < triggerLockout {
            return
        }

        guard timerStore.triggerCooldown(id: result.skillTimerID) else {
            return
        }

        lastTriggeredAtByTimerID[result.skillTimerID] = result.detectedAt
        lastTriggeredSkillTimerID = result.skillTimerID
    }

    private func requestScreenCapturePermissionIfNeeded() -> Bool {
        guard !screenCaptureService.hasScreenCapturePermission else {
            return true
        }

        guard screenCaptureService.requestScreenCapturePermissionIfNeeded() else {
            lastErrorMessage = "화면 기록 권한이 필요합니다. 권한을 허용한 뒤 앱을 재실행해 주세요."
            return false
        }

        lastErrorMessage = nil
        return true
    }
}
