//
//  SkillDetectionRuleStore.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Combine
import Foundation

final class SkillDetectionRuleStore: ObservableObject {
    @Published private(set) var rules: [SkillDetectionRule] = []

    func addRule(_ rule: SkillDetectionRule) {
        rules.append(rule)
    }

    func removeRule(id: SkillDetectionRule.ID) {
        rules.removeAll { $0.id == id }
    }

    func replaceRules(_ rules: [SkillDetectionRule]) {
        self.rules = rules
    }
}
