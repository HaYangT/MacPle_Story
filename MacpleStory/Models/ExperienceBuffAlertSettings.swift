//
//  ExperienceBuffAlertSettings.swift
//  MacpleStory
//
//  Created by Codex on 6/16/26.
//

import Foundation

/// 프리셋별 사용자 설정(추적 여부, 알림음). presetID로 키잉되어 저장된다.
struct PresetPreference: Codable, Equatable {
    var isTracked: Bool
    var alertSoundID: AlertSound.ID?

    init(isTracked: Bool = false, alertSoundID: AlertSound.ID? = nil) {
        self.isTracked = isTracked
        self.alertSoundID = alertSoundID
    }
}

struct ExperienceBuffAlertSettings: Codable, Equatable {
    var isEnabled: Bool
    var preferences: [String: PresetPreference]

    init(isEnabled: Bool = true, preferences: [String: PresetPreference] = [:]) {
        self.isEnabled = isEnabled
        self.preferences = preferences
    }
}

/// 감지 대상으로 확정된 버프 한 건. 프리셋 + 사용자 설정을 합쳐 런타임에 생성된다.
struct ExperienceBuffEntry: Identifiable, Equatable {
    /// presetID(파일명). 감지 결과·상태 추적의 키.
    let id: String
    let iconTemplate: SkillIconTemplate
    let iconName: String
    let alertSoundID: AlertSound.ID?

    init(
        id: String,
        iconTemplate: SkillIconTemplate,
        iconName: String,
        alertSoundID: AlertSound.ID? = nil
    ) {
        self.id = id
        self.iconTemplate = iconTemplate
        self.iconName = iconName
        self.alertSoundID = alertSoundID
    }
}
