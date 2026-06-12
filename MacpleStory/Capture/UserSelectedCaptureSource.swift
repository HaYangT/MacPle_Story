//
//  UserSelectedCaptureSource.swift
//  MacpleStory
//
//  Created by Codex on 6/13/26.
//

import CoreGraphics
import Foundation

struct UserSelectedCaptureSource: Equatable {
    let displayName: String
    let contentRect: CGRect
    let pointPixelScale: CGFloat

    var pixelWidth: Int {
        max(1, Int((contentRect.width * pointPixelScale).rounded()))
    }

    var pixelHeight: Int {
        max(1, Int((contentRect.height * pointPixelScale).rounded()))
    }

    var sizeText: String {
        "\(pixelWidth)x\(pixelHeight)"
    }
}
