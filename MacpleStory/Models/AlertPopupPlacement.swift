//
//  AlertPopupPlacement.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import CoreGraphics
import Foundation

struct AlertPopupPlacement: Codable, Equatable {
    static let defaultValue = AlertPopupPlacement(normalizedX: 1, normalizedY: 0)

    var normalizedX: Double
    var normalizedY: Double

    var displayText: String {
        let xPercent = Int((clampedX * 100).rounded())
        let yPercent = Int((clampedY * 100).rounded())
        return "왼쪽 \(xPercent)% · 위쪽 \(yPercent)%"
    }

    func popupOrigin(panelSize: CGSize, in screenFrame: CGRect) -> CGPoint {
        let availableWidth = max(0, screenFrame.width - panelSize.width)
        let availableHeight = max(0, screenFrame.height - panelSize.height)

        return CGPoint(
            x: screenFrame.minX + availableWidth * CGFloat(clampedX),
            y: screenFrame.minY + availableHeight * CGFloat(1 - clampedY)
        )
    }

    static func placement(
        from origin: CGPoint,
        panelSize: CGSize,
        in screenFrame: CGRect
    ) -> AlertPopupPlacement {
        let availableWidth = max(1, screenFrame.width - panelSize.width)
        let availableHeight = max(1, screenFrame.height - panelSize.height)

        let yFromBottom = (origin.y - screenFrame.minY) / availableHeight

        return AlertPopupPlacement(
            normalizedX: Double((origin.x - screenFrame.minX) / availableWidth).clamped(to: 0...1),
            normalizedY: Double(1 - yFromBottom).clamped(to: 0...1)
        )
    }

    private var clampedX: Double {
        normalizedX.clamped(to: 0...1)
    }

    private var clampedY: Double {
        normalizedY.clamped(to: 0...1)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
