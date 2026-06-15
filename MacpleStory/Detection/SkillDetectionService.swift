//
//  SkillDetectionService.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import CoreGraphics
import Foundation

protocol SkillDetectionProviding {
    var lastDebugSnapshot: SkillDetectionDebugSnapshot? { get }

    func detectSkills(
        in frame: ScreenCaptureFrame,
        using rules: [SkillDetectionRule]
    ) async throws -> [SkillDetectionResult]
}

extension SkillDetectionProviding {
    var lastDebugSnapshot: SkillDetectionDebugSnapshot? {
        nil
    }
}

final class SkillDetectionService: SkillDetectionProviding {
    private let iconLocator: SkillIconLocating
    private let cooldownStateDetector: SkillCooldownStateDetecting
    private var isArmedByRuleID: [SkillDetectionRule.ID: Bool] = [:]
    private var readyFrameCountByRuleID: [SkillDetectionRule.ID: Int] = [:]
    private var cooldownFrameCountByRuleID: [SkillDetectionRule.ID: Int] = [:]
    private var locatedIconByRuleID: [SkillDetectionRule.ID: SkillIconLocation] = [:]
    private var failedLocationAttemptAtByRuleID: [SkillDetectionRule.ID: Date] = [:]
    private let failedLocationRetryInterval: TimeInterval = 2
    private let readyFrameThreshold = 1
    private let cooldownFrameThreshold = 2
    private(set) var lastDebugSnapshot: SkillDetectionDebugSnapshot?

    init(
        iconLocator: SkillIconLocating = SkillIconLocator(),
        cooldownStateDetector: SkillCooldownStateDetecting = SkillCooldownStateDetector()
    ) {
        self.iconLocator = iconLocator
        self.cooldownStateDetector = cooldownStateDetector
    }

    func detectSkills(
        in frame: ScreenCaptureFrame,
        using rules: [SkillDetectionRule]
    ) async throws -> [SkillDetectionResult] {
        pruneStateCache(keeping: rules.map(\.id))

        return rules.compactMap { rule in
            guard let locatedSlot = slotRegion(for: rule, in: frame) else {
                return nil
            }

            let currentDetection = cooldownStateDetector.detectState(
                in: frame,
                rule: rule,
                slotRegion: locatedSlot.region
            )
            let triggerState = triggerEligibleState(
                for: currentDetection,
                rule: rule
            )
            let shouldTrigger = updateTriggerState(
                ruleID: rule.id,
                currentState: triggerState
            )
            lastDebugSnapshot = SkillDetectionDebugSnapshot(
                ruleID: rule.id,
                skillTimerID: rule.skillTimerID,
                displayName: rule.displayName,
                capturedAt: frame.capturedAt,
                framePixelWidth: frame.image.width,
                framePixelHeight: frame.image.height,
                iconRegion: locatedSlot.region,
                iconConfidence: locatedSlot.confidence,
                slotState: currentDetection.state,
                stateConfidence: currentDetection.confidence,
                isArmedForTrigger: isArmedByRuleID[rule.id] ?? false,
                message: debugMessage(
                    for: currentDetection,
                    triggerState: triggerState,
                    rule: rule,
                    didTrigger: shouldTrigger,
                    isArmed: isArmedByRuleID[rule.id] ?? false,
                    cooldownFrameCount: cooldownFrameCountByRuleID[rule.id] ?? 0
                )
            )

            guard shouldTrigger else {
                return nil
            }

            return SkillDetectionResult(
                ruleID: rule.id,
                skillTimerID: rule.skillTimerID,
                confidence: currentDetection.confidence,
                detectedAt: frame.capturedAt
            )
        }
    }

    private func slotRegion(
        for rule: SkillDetectionRule,
        in frame: ScreenCaptureFrame
    ) -> SkillIconLocation? {
        if let lastKnownIconRegion = rule.lastKnownIconRegion {
            return SkillIconLocation(
                region: lastKnownIconRegion,
                confidence: 1
            )
        }

        if let locatedIcon = locatedIconByRuleID[rule.id] {
            return locatedIcon
        }

        switch rule.detectionMode {
        case .fixedRegion:
            return SkillIconLocation(
                region: rule.screenRegion,
                confidence: 1
            )
        case .locateIcon:
            guard let iconTemplate = rule.iconTemplate else {
                lastDebugSnapshot = debugSnapshot(
                    for: rule,
                    in: frame,
                    message: "아이콘 템플릿 없음"
                )
                return nil
            }

            if let failedAt = failedLocationAttemptAtByRuleID[rule.id],
               frame.capturedAt.timeIntervalSince(failedAt) < failedLocationRetryInterval {
                lastDebugSnapshot = debugSnapshot(
                    for: rule,
                    in: frame,
                    message: "아이콘 재탐색 대기"
                )
                return nil
            }

            guard let location = iconLocator.locateIcon(
                matching: iconTemplate,
                in: frame,
                searchRegion: rule.screenRegion
            ) else {
                failedLocationAttemptAtByRuleID[rule.id] = frame.capturedAt
                lastDebugSnapshot = debugSnapshot(
                    for: rule,
                    in: frame,
                    message: "아이콘 위치 못 찾음"
                )
                return nil
            }

            locatedIconByRuleID[rule.id] = location
            failedLocationAttemptAtByRuleID[rule.id] = nil
            lastDebugSnapshot = debugSnapshot(
                for: rule,
                in: frame,
                iconLocation: location,
                message: "아이콘 위치 찾음"
            )
            return location
        }
    }

    private func debugSnapshot(
        for rule: SkillDetectionRule,
        in frame: ScreenCaptureFrame,
        iconLocation: SkillIconLocation? = nil,
        message: String
    ) -> SkillDetectionDebugSnapshot {
        SkillDetectionDebugSnapshot(
            ruleID: rule.id,
            skillTimerID: rule.skillTimerID,
            displayName: rule.displayName,
            capturedAt: frame.capturedAt,
            framePixelWidth: frame.image.width,
            framePixelHeight: frame.image.height,
            iconRegion: iconLocation?.region,
            iconConfidence: iconLocation?.confidence,
            slotState: nil,
            stateConfidence: nil,
            isArmedForTrigger: nil,
            message: message
        )
    }

    private func pruneStateCache(keeping activeRuleIDs: [SkillDetectionRule.ID]) {
        let activeRuleIDs = Set(activeRuleIDs)
        isArmedByRuleID = isArmedByRuleID.filter { element in
            activeRuleIDs.contains(element.key)
        }
        readyFrameCountByRuleID = readyFrameCountByRuleID.filter { element in
            activeRuleIDs.contains(element.key)
        }
        cooldownFrameCountByRuleID = cooldownFrameCountByRuleID.filter { element in
            activeRuleIDs.contains(element.key)
        }
        locatedIconByRuleID = locatedIconByRuleID.filter { element in
            activeRuleIDs.contains(element.key)
        }
        failedLocationAttemptAtByRuleID = failedLocationAttemptAtByRuleID.filter { element in
            activeRuleIDs.contains(element.key)
        }
    }

    private func updateTriggerState(
        ruleID: SkillDetectionRule.ID,
        currentState: SkillSlotVisualState
    ) -> Bool {
        switch currentState {
        case .ready:
            let nextReadyFrameCount = min(
                readyFrameThreshold,
                (readyFrameCountByRuleID[ruleID] ?? 0) + 1
            )
            readyFrameCountByRuleID[ruleID] = nextReadyFrameCount
            cooldownFrameCountByRuleID[ruleID] = 0

            if nextReadyFrameCount >= readyFrameThreshold {
                isArmedByRuleID[ruleID] = true
            }

            return false

        case .cooldown:
            readyFrameCountByRuleID[ruleID] = 0

            guard isArmedByRuleID[ruleID] == true else {
                cooldownFrameCountByRuleID[ruleID] = 0
                return false
            }

            let nextCooldownFrameCount = min(
                cooldownFrameThreshold,
                (cooldownFrameCountByRuleID[ruleID] ?? 0) + 1
            )
            cooldownFrameCountByRuleID[ruleID] = nextCooldownFrameCount

            guard nextCooldownFrameCount >= cooldownFrameThreshold else {
                return false
            }

            isArmedByRuleID[ruleID] = false
            cooldownFrameCountByRuleID[ruleID] = 0
            return true

        case .unknown:
            readyFrameCountByRuleID[ruleID] = 0
            cooldownFrameCountByRuleID[ruleID] = 0
            return false
        }
    }

    private func triggerEligibleState(
        for detection: SkillCooldownStateDetection,
        rule: SkillDetectionRule
    ) -> SkillSlotVisualState {
        guard detection.state == .cooldown,
              detection.confidence < rule.matchThreshold else {
            return detection.state
        }

        return .unknown
    }

    private func debugMessage(
        for detection: SkillCooldownStateDetection,
        triggerState: SkillSlotVisualState,
        rule: SkillDetectionRule,
        didTrigger: Bool,
        isArmed: Bool,
        cooldownFrameCount: Int
    ) -> String {
        if didTrigger {
            return "쿨다운 감지"
        }

        if detection.state == .cooldown,
           triggerState == .unknown,
           detection.confidence < rule.matchThreshold {
            return "쿨다운 후보"
        }

        if detection.state == .cooldown,
           triggerState == .cooldown,
           !isArmed {
            return "대기 확인 전"
        }

        if detection.state == .cooldown,
           triggerState == .cooldown,
           cooldownFrameCount > 0 {
            return "쿨다운 확인 중"
        }

        return "아이콘 좌표 확인"
    }
}
