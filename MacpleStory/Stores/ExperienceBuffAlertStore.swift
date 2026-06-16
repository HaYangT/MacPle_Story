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

    private let userDefaults: UserDefaults
    private static let settingsDefaultsKey = "experienceBuffAlertSettings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.loadSettings(from: userDefaults)
    }

    func updateEnabled(_ isEnabled: Bool) {
        settings.isEnabled = isEnabled
        saveSettings()
    }

    func addEntry(_ entry: ExperienceBuffEntry) {
        settings.entries.append(entry)
        saveSettings()
    }

    func removeEntry(id: UUID) {
        settings.entries.removeAll { $0.id == id }
        saveSettings()
    }

    func updateEntryEnabled(id: UUID, isEnabled: Bool) {
        guard let index = settings.entries.firstIndex(where: { $0.id == id }) else { return }
        settings.entries[index].isEnabled = isEnabled
        saveSettings()
    }

    func updateEntryAlertSoundID(id: UUID, alertSoundID: AlertSound.ID?) {
        guard let index = settings.entries.firstIndex(where: { $0.id == id }) else { return }
        settings.entries[index].alertSoundID = alertSoundID
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
