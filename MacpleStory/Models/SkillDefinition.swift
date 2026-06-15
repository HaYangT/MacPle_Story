//
//  SkillDefinition.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import Foundation

struct SkillDefinition: Identifiable, Codable, Equatable {
    typealias ID = String

    let id: ID
    var displayName: String
    var iconTemplate: SkillIconTemplate
    var maxLevel: Int
    var cooldownSecondsByLevel: [Int: Int]
    var durationSecondsByLevel: [Int: Int]

    init(
        id: ID,
        displayName: String,
        iconTemplate: SkillIconTemplate,
        maxLevel: Int,
        cooldownSecondsByLevel: [Int: Int],
        durationSecondsByLevel: [Int: Int] = [:]
    ) {
        self.id = id
        self.displayName = displayName
        self.iconTemplate = iconTemplate
        self.maxLevel = max(1, maxLevel)
        self.cooldownSecondsByLevel = cooldownSecondsByLevel
        self.durationSecondsByLevel = durationSecondsByLevel
    }

    func clampedLevel(_ level: Int) -> Int {
        min(max(1, level), maxLevel)
    }

    func cooldownSeconds(for level: Int) -> Int? {
        levelValue(
            in: cooldownSecondsByLevel,
            for: clampedLevel(level)
        )
    }

    func durationSeconds(for level: Int) -> Int? {
        levelValue(
            in: durationSecondsByLevel,
            for: clampedLevel(level)
        )
    }

    private func levelValue(
        in valuesByLevel: [Int: Int],
        for level: Int
    ) -> Int? {
        if let exactValue = valuesByLevel[level] {
            return exactValue
        }

        if let nearestLowerLevel = valuesByLevel.keys
            .filter({ $0 <= level })
            .max() {
            return valuesByLevel[nearestLowerLevel]
        }

        if let nearestHigherLevel = valuesByLevel.keys
            .filter({ $0 > level })
            .min() {
            return valuesByLevel[nearestHigherLevel]
        }

        return nil
    }
}
