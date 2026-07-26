//
//  BorderGlowOverlayPresenter.swift
//  MacpleStory
//
//  Created by Hayangt on 6/22/26.
//

import AppKit
import QuartzCore

/// 알림 시 화면 테두리를 색으로 점등(펄스)시키는 오버레이를 표시한다.
/// 클릭이 통과(`ignoresMouseEvents`)하고 전체화면 위에도 떠서 넷플릭스 등을 가리지 않는다.
@MainActor
final class BorderGlowOverlayPresenter {
    private var overlayWindows: [NSWindow] = []

    func flash(
        color: NSColor,
        on screen: NSScreen?,
        lineWidth: CGFloat = 16,
        pulses: Int = 3,
        pulseDuration: TimeInterval = 0.45
    ) {
        guard let screen = screen ?? NSScreen.main else {
            return
        }

        let window = makeOverlayWindow(on: screen)
        let borderView = BorderGlowView(color: color, lineWidth: lineWidth)
        borderView.frame = NSRect(origin: .zero, size: screen.frame.size)
        window.contentView = borderView
        window.orderFrontRegardless()
        overlayWindows.append(window)

        borderView.startPulsing(pulses: pulses, pulseDuration: pulseDuration) { [weak self, weak window] in
            guard let window else {
                return
            }

            window.orderOut(nil)
            self?.overlayWindows.removeAll { $0 === window }
        }
    }

    private func makeOverlayWindow(on screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.setFrame(screen.frame, display: true)
        return window
    }
}

/// 둥근 사각형 테두리를 그리고 글로우(그림자)를 입혀 펄스 애니메이션을 재생하는 뷰.
private final class BorderGlowView: NSView {
    private let color: NSColor
    private let lineWidth: CGFloat
    private let borderLayer = CAShapeLayer()

    init(color: NSColor, lineWidth: CGFloat) {
        self.color = color
        self.lineWidth = lineWidth
        super.init(frame: .zero)

        wantsLayer = true
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = color.cgColor
        borderLayer.lineWidth = lineWidth
        borderLayer.shadowColor = color.cgColor
        borderLayer.shadowRadius = lineWidth
        borderLayer.shadowOpacity = 1
        borderLayer.shadowOffset = .zero
        borderLayer.opacity = 0
        layer?.addSublayer(borderLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        borderLayer.frame = bounds

        let inset = lineWidth / 2
        borderLayer.path = CGPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset),
            cornerWidth: 18,
            cornerHeight: 18,
            transform: nil
        )
    }

    func startPulsing(
        pulses: Int,
        pulseDuration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.1
        pulse.toValue = 1.0
        pulse.duration = pulseDuration
        pulse.autoreverses = true
        pulse.repeatCount = Float(max(1, pulses))
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        borderLayer.add(pulse, forKey: "borderPulse")
        CATransaction.commit()
    }
}
