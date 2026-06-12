//
//  Int+TimerText.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import Foundation

extension Int {
    var timerText: String {
        let clampedSeconds = Swift.max(0, self)
        let minutes = clampedSeconds / 60
        let seconds = clampedSeconds % 60

        return String(format: "%02d:%02d", minutes, seconds)
    }
}
