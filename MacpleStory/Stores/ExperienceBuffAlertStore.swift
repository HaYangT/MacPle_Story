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
                iconName: preset.displayName,
                variants: preset.variants,
                alertSoundID: settings.preferences[preset.id]?.alertSoundID,
                durationSeconds: resolvedDurationSeconds(for: preset)
            )
        }
    }

    /// 시간 기반 버프의 지속시간(초). 사용자가 고른 값(없으면 첫 옵션) × 60.
    private func resolvedDurationSeconds(for preset: ExperienceBuffPreset) -> Int? {
        guard preset.isFixedDuration else {
            return nil
        }

        let selected = settings.preferences[preset.id]?.selectedDurationMinutes
        let minutes = selected.flatMap { value in
            preset.durationsMinutes.contains(value) ? value : nil
        } ?? preset.durationsMinutes.first

        return minutes.map { $0 * 60 }
    }

    /// 사용자가 고른 지속시간(분). 시간 기반 버프 행에서 표시·선택용.
    func selectedDurationMinutes(for preset: ExperienceBuffPreset) -> Int? {
        guard preset.isFixedDuration else {
            return nil
        }

        let selected = settings.preferences[preset.id]?.selectedDurationMinutes
        return selected.flatMap { value in
            preset.durationsMinutes.contains(value) ? value : nil
        } ?? preset.durationsMinutes.first
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

    func setDuration(presetID: String, minutes: Int) {
        var preference = settings.preferences[presetID] ?? PresetPreference()
        preference.selectedDurationMinutes = minutes
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
