//
//  MapleStoryResolutionDetectionResult.swift
//  MacpleStory
//
//  Created by Codex on 6/13/26.
//

import CoreGraphics
import Foundation

struct MapleStoryResolutionDetectionResult: Equatable {
    let resolution: MapleStoryResolution
    let observedPixelSize: CGSize
    let scale: Double
    let confidence: Double

    var displayText: String {
        if scale == 1 {
            return resolution.displayText
        }

        return "\(resolution.displayText) @\(String(format: "%.2gx", scale))"
    }
}

