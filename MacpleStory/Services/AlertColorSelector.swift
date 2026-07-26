//
//  AlertColorSelector.swift
//  MacpleStory
//
//  Created by Hayangt on 6/22/26.
//

import AppKit

/// 알림 색상을 별도 창에서 미리 보고 고른 뒤 "적용"으로 확정하는 선택기.
final class AlertColorSelector {
    private var panel: NSPanel?

    func beginSelection(
        initialColor: AlertColor,
        onPreviewGlow: ((NSColor) -> Void)? = nil,
        completion: @escaping (AlertColor) -> Void
    ) {
        panel?.close()

        let contentView = AlertColorSelectionView(
            initialColor: initialColor,
            onPreviewGlow: onPreviewGlow,
            onApply: { [weak self] color in
                completion(color)
                self?.closePanel()
            },
            onCancel: { [weak self] in
                self?.closePanel()
            }
        )

        let selectionPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        selectionPanel.title = "알림 색상 설정"
        selectionPanel.isReleasedWhenClosed = false
        selectionPanel.level = .floating
        selectionPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        selectionPanel.contentView = contentView
        positionPanel(selectionPanel, near: NSEvent.mouseLocation)
        panel = selectionPanel

        NSApp.activate(ignoringOtherApps: true)
        selectionPanel.makeKeyAndOrderFront(nil)
    }

    /// 패널을 커서(=클릭한 팔레트 버튼) 바로 아래-오른쪽에 붙여서 띄운다. 화면 밖으로 나가면 안쪽으로 보정.
    private func positionPanel(_ panel: NSPanel, near point: CGPoint) {
        let size = panel.frame.size
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        var origin = CGPoint(x: point.x + 8, y: point.y - size.height - 8)
        origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - size.width))
        origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - size.height))

        panel.setFrameOrigin(origin)
    }

    private func closePanel() {
        panel?.close()
        panel = nil
    }
}

private final class AlertColorSelectionView: NSView {
    private let onPreviewGlow: ((NSColor) -> Void)?
    private let onApply: (AlertColor) -> Void
    private let onCancel: () -> Void
    private var selectedColor: NSColor

    private let previewBox = NSView()
    private let previewTitle = NSTextField(labelWithString: "스킬 사용 가능")
    private let previewBody = NSTextField(labelWithString: "알림은 이 색으로 표시됩니다.")
    private let colorWell = NSColorWell()

    init(
        initialColor: AlertColor,
        onPreviewGlow: ((NSColor) -> Void)?,
        onApply: @escaping (AlertColor) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onPreviewGlow = onPreviewGlow
        self.onApply = onApply
        self.onCancel = onCancel
        self.selectedColor = initialColor.nsColor

        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 320))

        build()
        updatePreview()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func build() {
        let titleLabel = NSTextField(labelWithString: "알림 색상 선택")
        titleLabel.font = .boldSystemFont(ofSize: 17)

        let descriptionLabel = NSTextField(labelWithString: "색을 고르면 아래 미리보기에 바로 반영됩니다. 마음에 들면 적용을 누르세요.")
        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 2

        previewBox.wantsLayer = true
        previewBox.layer?.cornerRadius = 12
        previewTitle.font = .boldSystemFont(ofSize: 15)
        previewBody.font = .systemFont(ofSize: 13)

        let previewStack = NSStackView(views: [previewTitle, previewBody])
        previewStack.orientation = .vertical
        previewStack.alignment = .leading
        previewStack.spacing = 6
        previewStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        previewBox.addSubview(previewStack)
        previewStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewStack.leadingAnchor.constraint(equalTo: previewBox.leadingAnchor),
            previewStack.trailingAnchor.constraint(equalTo: previewBox.trailingAnchor),
            previewStack.topAnchor.constraint(equalTo: previewBox.topAnchor),
            previewStack.bottomAnchor.constraint(equalTo: previewBox.bottomAnchor)
        ])
        previewBox.heightAnchor.constraint(equalToConstant: 96).isActive = true

        colorWell.color = selectedColor
        colorWell.target = self
        colorWell.action = #selector(colorWellChanged)
        let colorLabel = NSTextField(labelWithString: "색상")
        colorLabel.font = .systemFont(ofSize: 13)
        let colorRow = NSStackView(views: [colorLabel, colorWell])
        colorRow.orientation = .horizontal
        colorRow.spacing = 12
        colorWell.widthAnchor.constraint(equalToConstant: 64).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let previewGlowButton = NSButton(title: "테두리 점등 미리보기", target: self, action: #selector(previewGlow))
        previewGlowButton.bezelStyle = .rounded
        previewGlowButton.isHidden = onPreviewGlow == nil

        let cancelButton = NSButton(title: "취소", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let applyButton = NSButton(title: "적용", target: self, action: #selector(apply))
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"

        let buttonRow = NSStackView(views: [previewGlowButton, NSView(), cancelButton, applyButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let mainStack = NSStackView(views: [
            titleLabel,
            descriptionLabel,
            previewBox,
            colorRow,
            buttonRow
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 14
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        previewBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
        buttonRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
    }

    private func updatePreview() {
        let alertColor = AlertColor(nsColor: selectedColor)
        let textColor = alertColor.contrastingTextColor

        previewBox.layer?.backgroundColor = selectedColor.cgColor
        previewTitle.textColor = textColor
        previewBody.textColor = textColor.withAlphaComponent(0.85)
    }

    @objc private func colorWellChanged() {
        selectedColor = colorWell.color
        updatePreview()
    }

    @objc private func previewGlow() {
        onPreviewGlow?(selectedColor)
    }

    @objc private func apply() {
        onApply(AlertColor(nsColor: selectedColor))
    }

    @objc private func cancel() {
        onCancel()
    }
}
