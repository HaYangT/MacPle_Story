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
    @Published private(set) var lastDetectedResolution: MapleStoryResolutionDetectionResult?
    @Published private(set) var lastTriggeredSkillTimerID: SkillTimer.ID?
    @Published private(set) var lastErrorMessage: String?

    private let screenCaptureService: ScreenCaptureProviding
    private let skillDetectionService: SkillDetectionProviding
    private let resolutionDetector: MapleStoryResolutionDetecting
    private let detectionInterval: TimeInterval
    private let triggerLockout: TimeInterval
    private var detectionTask: Task<Void, Never>?
    private var lastTriggeredAtByTimerID: [SkillTimer.ID: Date] = [:]

    init() {
        self.screenCaptureService = ScreenCaptureService()
        self.skillDetectionService = SkillDetectionService()
        self.resolutionDetector = MapleStoryResolutionDetector()
        self.detectionInterval = 0.35
        self.triggerLockout = 1.5
    }

    init(
        screenCaptureService: ScreenCaptureProviding,
        skillDetectionService: SkillDetectionProviding,
        detectionInterval: TimeInterval = 0.35,
        triggerLockout: TimeInterval = 1.5
    ) {
        self.screenCaptureService = screenCaptureService
        self.skillDetectionService = skillDetectionService
        self.resolutionDetector = MapleStoryResolutionDetector()
        self.detectionInterval = detectionInterval
        self.triggerLockout = triggerLockout
    }

    init(
        screenCaptureService: ScreenCaptureProviding,
        skillDetectionService: SkillDetectionProviding,
        resolutionDetector: MapleStoryResolutionDetecting,
        detectionInterval: TimeInterval = 0.35,
        triggerLockout: TimeInterval = 1.5
    ) {
        self.screenCaptureService = screenCaptureService
        self.skillDetectionService = skillDetectionService
        self.resolutionDetector = resolutionDetector
        self.detectionInterval = detectionInterval
        self.triggerLockout = triggerLockout
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
        ruleStore: SkillDetectionRuleStore
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
                        timerStore: timerStore
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
        lastDetectedResolution = nil
        lastTriggeredSkillTimerID = nil
    }

    func processOnce(
        using rules: [SkillDetectionRule],
        timerStore: SkillTimerStore? = nil
    ) async throws {
        guard isRunning else {
            lastDetectedResult = nil
            return
        }

        guard let frame = try await screenCaptureService.captureFrame() else {
            return
        }

        lastDetectedResolution = resolutionDetector.detectResolution(in: frame)

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

        guard let detectedResult, let timerStore else {
            return
        }

        triggerTimerIfNeeded(
            for: detectedResult,
            timerStore: timerStore
        )
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
