//
//  SkillTrackingRegistrationService.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import Foundation

@MainActor
struct SkillTrackingRegistrationService {
    @discardableResult
    func register(
        skill: SkillDefinition,
        level: Int,
        alertBeforeSeconds: Int,
        preAlertSoundID: AlertSound.ID? = nil,
        readyAlertSoundID: AlertSound.ID? = nil,
        detectionMode: SkillDetectionMode = .locateIcon,
        searchRegion: NormalizedScreenRegion = .quickSlotSearchArea,
        matchThreshold: Double = 0.35,
        timerStore: SkillTimerStore,
        ruleStore: SkillDetectionRuleStore,
        trackedSkillStore: TrackedSkillStore? = nil
    ) -> TrackedSkill? {
        let normalizedLevel = skill.clampedLevel(level)

        guard let cooldownSeconds = skill.cooldownSeconds(for: normalizedLevel) else {
            return nil
        }

        guard let timer = timerStore.addTimer(
            name: skill.displayName,
            cooldownSeconds: cooldownSeconds,
            alertBeforeSeconds: alertBeforeSeconds,
            preAlertSoundID: preAlertSoundID,
            readyAlertSoundID: readyAlertSoundID
        ) else {
            return nil
        }

        let rule = SkillDetectionRule(
            skillTimerID: timer.id,
            displayName: skill.displayName,
            skillDefinitionID: skill.id,
            detectionMode: detectionMode,
            iconTemplate: skill.iconTemplate,
            screenRegion: searchRegion,
            matchThreshold: matchThreshold
        )
        ruleStore.addRule(rule)

        let trackedSkill = TrackedSkill(
            skillDefinitionID: skill.id,
            skillTimerID: timer.id,
            detectionRuleID: rule.id,
            level: normalizedLevel
        )
        trackedSkillStore?.addTrackedSkill(trackedSkill)

        return trackedSkill
    }
}
