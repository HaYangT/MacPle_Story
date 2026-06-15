//
//  SkillDetectionDebugSnapshot.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import CoreGraphics
import Foundation

struct SkillDetectionDebugSnapshot: Equatable {
    let ruleID: SkillDetectionRule.ID
    let skillTimerID: SkillTimer.ID
    let displayName: String
    let capturedAt: Date
    let framePixelWidth: Int
    let framePixelHeight: Int
    let iconRegion: NormalizedScreenRegion?
    let iconConfidence: Double?
    let slotState: SkillSlotVisualState?
    let stateConfidence: Double?
    let isArmedForTrigger: Bool?
    let message: String

    var coordinateText: String {
        guard let iconRegion else {
            return "좌표 없음"
        }

        let rect = iconRegion.pixelRect(
            pixelWidth: framePixelWidth,
            pixelHeight: framePixelHeight
        )

        return "x:\(Int(rect.minX)) y:\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
    }

    var summaryText: String {
        var parts = [displayName, coordinateText]

        if let iconConfidence {
            parts.append("아이콘 \(Int(iconConfidence * 100))%")
        }

        if let slotState {
            parts.append("\(slotState.displayText) \(Int((stateConfidence ?? 0) * 100))%")
        }

        if let isArmedForTrigger {
            parts.append(isArmedForTrigger ? "감지 준비" : "재감지 대기")
        }

        return parts.joined(separator: " · ")
    }
}

extension SkillSlotVisualState {
    var displayText: String {
        switch self {
        case .ready:
            "대기"
        case .cooldown:
            "쿨다운"
        case .unknown:
            "불명"
        }
    }
}
