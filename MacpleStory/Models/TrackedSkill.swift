//
//  TrackedSkill.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import Foundation

struct TrackedSkill: Identifiable, Codable, Equatable {
    let id: UUID
    var skillDefinitionID: SkillDefinition.ID
    var skillTimerID: SkillTimer.ID
    var detectionRuleID: SkillDetectionRule.ID
    var level: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        skillDefinitionID: SkillDefinition.ID,
        skillTimerID: SkillTimer.ID,
        detectionRuleID: SkillDetectionRule.ID,
        level: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.skillDefinitionID = skillDefinitionID
        self.skillTimerID = skillTimerID
        self.detectionRuleID = detectionRuleID
        self.level = level
        self.isEnabled = isEnabled
    }
}
