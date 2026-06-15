//
//  TrackedSkillStore.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import Combine
import Foundation

final class TrackedSkillStore: ObservableObject {
    @Published private(set) var trackedSkills: [TrackedSkill] = []

    func addTrackedSkill(_ trackedSkill: TrackedSkill) {
        trackedSkills.append(trackedSkill)
    }

    func removeTrackedSkill(id: TrackedSkill.ID) {
        trackedSkills.removeAll { $0.id == id }
    }

    func setEnabled(_ isEnabled: Bool, for id: TrackedSkill.ID) {
        updateTrackedSkill(id: id) { trackedSkill in
            trackedSkill.isEnabled = isEnabled
        }
    }

    func replaceTrackedSkills(_ trackedSkills: [TrackedSkill]) {
        self.trackedSkills = trackedSkills
    }

    private func updateTrackedSkill(
        id: TrackedSkill.ID,
        mutate: (inout TrackedSkill) -> Void
    ) {
        guard let index = trackedSkills.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&trackedSkills[index])
    }
}
