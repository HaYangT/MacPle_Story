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
    private var detectionTask: Task<Void, Never>?
    private var lastTriggeredAtByTimerID: [SkillTimer.ID: Date] = [:]
    private var buffTrackingStateByEntryID: [String: ExperienceBuffTrackingState] = [:]
    private var buffFixedDurationStateByEntryID: [String: FixedDurationAlertState] = [:]

    init() {
        self.screenCaptureService = ScreenCaptureService()
        self.skillDetectionService = SkillDetectionService()
        self.experienceBuffDetectionService = ExperienceBuffDetectionService()
        self.resolutionDetector = MapleStoryResolutionDetector()
        self.detectionInterval = 0.35
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
            await requestUserSelectedWindow()
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

                try? await Task.sleep(nanoseconds: self.detectionIntervalNanoseconds)
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
            return
        }

        pruneExperienceBuffStateCache(keeping: activeEntries.map(\.id))

        let now = frame.capturedAt

        // 타이머가 돌고 있는 시간 기반 버프는 매칭을 건너뛴다(효율).
        // 만료 시각까지는 결과가 뻔하므로 시계만으로 처리한다.
        let timingEntries = activeEntries.filter { isFixedDurationTimerRunning($0) }
        let timingIDs = Set(timingEntries.map(\.id))
        let entriesToDetect = activeEntries.filter { !timingIDs.contains($0.id) }

        let detectedResults = entriesToDetect.isEmpty
            ? []
            : try await experienceBuffDetectionService.detectExperienceBuffs(
                in: frame,
                entries: entriesToDetect
            )

        var expiredEntryNames: [String] = []
        var expiringEntryNames: [String] = []

        // 1) 매칭한 버프 처리
        for result in detectedResults {
            guard let entry = entriesToDetect.first(where: { $0.id == result.entryID }) else {
                continue
            }

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
                let currentState = buffTrackingStateByEntryID[result.entryID] ?? .waitingForActivation
                let (nextState, didExpire) = currentState.transition(
                    isActive: result.isActive,
                    missingFrameThreshold: experienceBuffMissingFrameThreshold
                )
                buffTrackingStateByEntryID[result.entryID] = nextState

                if didExpire {
                    expiredEntryNames.append(entry.iconName)
                    timerStore.playAlertSound(id: entry.alertSoundID)
                    timerStore.notifyExperienceBuffExpired(name: entry.iconName)
                }
            }
        }

        // 2) 타이머 진행 중인 버프: 매칭 없이 시계로만 발화/만료 처리
        var timingResults: [ExperienceBuffDetectionResult] = []
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

            // 타이머가 아직 살아있으면 UI에 "활성"으로 표시
            if buffFixedDurationStateByEntryID[entry.id]?.scheduledFireAt != nil {
                timingResults.append(
                    ExperienceBuffDetectionResult(
                        entryID: entry.id,
                        isActive: true,
                        confidence: 1,
                        detectedAt: now,
                        iconRegion: nil
                    )
                )
            }
        }

        lastExperienceBuffDetectionResults = detectedResults + timingResults

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
