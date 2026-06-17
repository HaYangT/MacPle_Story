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
    /// 시간 기반 버프에서 사용자가 고른 지속시간(분). nil이면 프리셋의 첫 옵션 사용.
    var selectedDurationMinutes: Int?

    init(
        isTracked: Bool = false,
        alertSoundID: AlertSound.ID? = nil,
        selectedDurationMinutes: Int? = nil
    ) {
        self.isTracked = isTracked
        self.alertSoundID = alertSoundID
        self.selectedDurationMinutes = selectedDurationMinutes
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

/// 감지 대상으로 확정된 버프 한 건(그룹). 프리셋 + 사용자 설정을 합쳐 런타임에 생성된다.
/// 변형(2배/3배/4배 등) 중 하나라도 감지되면 활성으로 본다.
struct ExperienceBuffEntry: Identifiable, Equatable {
    /// presetID(그룹명). 감지 결과·상태 추적의 키.
    let id: String
    let iconName: String
    let variants: [BuffIconVariant]
    let alertSoundID: AlertSound.ID?
    /// 시간 기반 알림 버프의 지속시간(초). nil이면 "사라지면 알림" 방식.
    let durationSeconds: Int?

    init(
        id: String,
        iconName: String,
        variants: [BuffIconVariant],
        alertSoundID: AlertSound.ID? = nil,
        durationSeconds: Int? = nil
    ) {
        self.id = id
        self.iconName = iconName
        self.variants = variants
        self.alertSoundID = alertSoundID
        self.durationSeconds = durationSeconds
    }
}
