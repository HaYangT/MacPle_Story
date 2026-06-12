//
//  SkillDetectionRule.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Foundation

struct SkillDetectionRule: Identifiable, Codable, Equatable {
    let id: UUID
    var skillTimerID: SkillTimer.ID
    var displayName: String
    var isEnabled: Bool
    var screenRegion: NormalizedScreenRegion
    var matchThreshold: Double

    init(
        id: UUID = UUID(),
        skillTimerID: SkillTimer.ID,
        displayName: String,
        isEnabled: Bool = true,
        screenRegion: NormalizedScreenRegion = .fullScreen,
        matchThreshold: Double = 0.9
    ) {
        self.id = id
        self.skillTimerID = skillTimerID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.screenRegion = screenRegion
        self.matchThreshold = matchThreshold
    }
}
