//
//  SkillDetectionRule.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Foundation

enum SkillDetectionMode: String, Codable, Equatable {
    case fixedRegion
    case locateIcon
}

struct SkillDetectionRule: Identifiable, Codable, Equatable {
    let id: UUID
    var skillTimerID: SkillTimer.ID
    var displayName: String
    var skillDefinitionID: SkillDefinition.ID?
    var isEnabled: Bool
    var detectionMode: SkillDetectionMode
    var iconTemplate: SkillIconTemplate?
    var screenRegion: NormalizedScreenRegion
    var lastKnownIconRegion: NormalizedScreenRegion?
    var matchThreshold: Double

    init(
        id: UUID = UUID(),
        skillTimerID: SkillTimer.ID,
        displayName: String,
        skillDefinitionID: SkillDefinition.ID? = nil,
        isEnabled: Bool = true,
        detectionMode: SkillDetectionMode = .fixedRegion,
        iconTemplate: SkillIconTemplate? = nil,
        screenRegion: NormalizedScreenRegion = .fullScreen,
        lastKnownIconRegion: NormalizedScreenRegion? = nil,
        matchThreshold: Double = 0.9
    ) {
        self.id = id
        self.skillTimerID = skillTimerID
        self.displayName = displayName
        self.skillDefinitionID = skillDefinitionID
        self.isEnabled = isEnabled
        self.detectionMode = detectionMode
        self.iconTemplate = iconTemplate
        self.screenRegion = screenRegion
        self.lastKnownIconRegion = lastKnownIconRegion
        self.matchThreshold = matchThreshold
    }
}
