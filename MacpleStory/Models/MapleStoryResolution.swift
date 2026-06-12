//
//  MapleStoryResolution.swift
//  MacpleStory
//
//  Created by Codex on 6/13/26.
//

import CoreGraphics
import Foundation

enum MapleStoryResolution: String, CaseIterable, Codable, Equatable, Identifiable {
    case size1024x768
    case size1280x720
    case size1366x768

    var id: String {
        rawValue
    }

    var width: Int {
        switch self {
        case .size1024x768:
            1024
        case .size1280x720:
            1280
        case .size1366x768:
            1366
        }
    }

    var height: Int {
        switch self {
        case .size1024x768:
            768
        case .size1280x720:
            720
        case .size1366x768:
            768
        }
    }

    var size: CGSize {
        CGSize(
            width: CGFloat(width),
            height: CGFloat(height)
        )
    }

    var displayText: String {
        "\(width)x\(height)"
    }
}

