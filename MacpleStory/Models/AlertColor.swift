//
//  AlertColor.swift
//  MacpleStory
//
//  Created by Hayangt on 6/22/26.
//

import AppKit
import SwiftUI

/// 알림 팝업 박스 배경과 테두리 점등에 함께 쓰는 사용자 지정 색상.
/// UserDefaults 저장을 위해 sRGB 성분으로 보관한다.
struct AlertColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    /// 기본값(시스템 블루 계열).
    static let defaultValue = AlertColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// 배경 위 텍스트 대비를 위한 전경색(밝으면 검정, 어두우면 흰색).
    var contrastingTextColor: NSColor {
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.6 ? .black : .white
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red.clampedUnit
        self.green = green.clampedUnit
        self.blue = blue.clampedUnit
        self.alpha = alpha.clampedUnit
    }

    init(_ color: Color) {
        self.init(nsColor: NSColor(color))
    }

    init(nsColor: NSColor) {
        let resolved = nsColor.usingColorSpace(.sRGB) ?? .systemBlue
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: Double(resolved.alphaComponent)
        )
    }
}

private extension Double {
    var clampedUnit: Double {
        Swift.min(Swift.max(self, 0), 1)
    }
}
