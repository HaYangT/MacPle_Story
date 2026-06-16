//
//  ExperienceBuffAlertStore.swift
//  MacpleStory
//
//  Created by Codex on 6/16/26.
//

import Combine
import Foundation

final class ExperienceBuffAlertStore: ObservableObject {
    @Published private(set) var settings: ExperienceBuffAlertSettings

    /// 앱 번들에서 읽어온 선택 가능한 버프 프리셋 목록.
    let presets: [ExperienceBuffPreset]

    private let userDefaults: UserDefaults
    private static let settingsDefaultsKey = "experienceBuffAlertSettings"

    init(
        userDefaults: UserDefaults = .standard,
        presets: [ExperienceBuffPreset] = ExperienceBuffCatalog.loadPresets()
    ) {
        self.userDefaults = userDefaults
        self.presets = presets
        self.settings = Self.loadSettings(from: userDefaults)
    }

    /// 전역 ON + 추적 체크된 프리셋만 감지 대상으로 변환한다.
    var activeEntries: [ExperienceBuffEntry] {
        guard settings.isEnabled else {
            return []
        }

        return presets.compactMap { preset in
            guard settings.preferences[preset.id]?.isTracked == true else {
                return nil
            }

            return ExperienceBuffEntry(
                id: preset.id,
                iconTemplate: preset.iconTemplate,
                iconName: preset.displayName,
                alertSoundID: settings.preferences[preset.id]?.alertSoundID
            )
        }
    }

    func preference(for presetID: String) -> PresetPreference {
        settings.preferences[presetID] ?? PresetPreference()
    }

    func updateEnabled(_ isEnabled: Bool) {
        settings.isEnabled = isEnabled
        saveSettings()
    }

    func setTracked(presetID: String, isTracked: Bool) {
        var preference = settings.preferences[presetID] ?? PresetPreference()
        preference.isTracked = isTracked
        settings.preferences[presetID] = preference
        saveSettings()
    }

    func setAlertSound(presetID: String, alertSoundID: AlertSound.ID?) {
        var preference = settings.preferences[presetID] ?? PresetPreference()
        preference.alertSoundID = alertSoundID
        settings.preferences[presetID] = preference
        saveSettings()
    }

    private static func loadSettings(from userDefaults: UserDefaults) -> ExperienceBuffAlertSettings {
        guard
            let data = userDefaults.data(forKey: settingsDefaultsKey),
            let settings = try? JSONDecoder().decode(ExperienceBuffAlertSettings.self, from: data)
        else {
            return ExperienceBuffAlertSettings()
        }

        return settings
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: Self.settingsDefaultsKey)
    }
}
