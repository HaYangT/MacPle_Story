//
//  MenuBarTimerStatus.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import Foundation

struct MenuBarTimerStatus: Equatable {
    enum Tone: Equatable {
        case idle
        case running
        case warning
        case ready
    }

    let title: String
    let systemImageName: String
    let tone: Tone
}
