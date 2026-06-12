//
//  SkillDetectionResult.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Foundation

struct SkillDetectionResult: Equatable {
    let ruleID: SkillDetectionRule.ID
    let skillTimerID: SkillTimer.ID
    let confidence: Double
    let detectedAt: Date
}
