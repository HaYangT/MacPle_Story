//
//  ExperienceBuffAlertSettings.swift
//  MacpleStory
//
//  Created by Codex on 6/16/26.
//

import Foundation

struct ExperienceBuffEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var iconTemplate: SkillIconTemplate
    var iconName: String
    var alertSoundID: AlertSound.ID?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        iconTemplate: SkillIconTemplate,
        iconName: String,
        alertSoundID: AlertSound.ID? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.iconTemplate = iconTemplate
        self.iconName = iconName
        self.alertSoundID = alertSoundID
        self.isEnabled = isEnabled
    }
}

struct ExperienceBuffAlertSettings: Codable, Equatable {
    var isEnabled: Bool
    var entries: [ExperienceBuffEntry]

    init(isEnabled: Bool = true, entries: [ExperienceBuffEntry] = []) {
        self.isEnabled = isEnabled
        self.entries = entries
    }

    var activeEntries: [ExperienceBuffEntry] {
        guard isEnabled else { return [] }
        return entries.filter(\.isEnabled)
    }
}
