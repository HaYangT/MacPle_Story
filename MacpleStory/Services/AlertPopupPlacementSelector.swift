//
//  AlertPopupPlacementSelector.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import AppKit

final class AlertPopupPlacementSelector {
    private var panel: NSPanel?

    func beginSelection(
        initialPlacement: AlertPopupPlacement,
        completion: @escaping (AlertPopupPlacement) -> Void
    ) {
        guard let screen = NSScreen.main else {
            completion(initialPlacement)
            return
        }

        panel?.close()

        let screenFrame = screen.visibleFrame
        let selectionPanel = AlertPopupPlacementPanel(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        selectionPanel.level = .statusBar
        selectionPanel.isOpaque = false
        selectionPanel.backgroundColor = .clear
        selectionPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        selectionPanel.isReleasedWhenClosed = false

        let contentView = AlertPopupPlacementSelectionView(
            frame: NSRect(origin: .zero, size: screenFrame.size),
            screenFrame: screenFrame,
            initialPlacement: initialPlacement,
            onSave: { [weak self] placement in
                completion(placement)
                self?.panel?.close()
                self?.panel = nil
            },
            onCancel: { [weak self] in
                self?.panel?.close()
                self?.panel = nil
            }
        )

        selectionPanel.contentView = contentView
        selectionPanel.initialFirstResponder = contentView
        panel = selectionPanel

        NSApp.activate(ignoringOtherApps: true)
        selectionPanel.orderFrontRegardless()
        selectionPanel.makeKey()
        selectionPanel.makeFirstResponder(contentView)
    }
}

private final class AlertPopupPlacementPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

private final class AlertPopupPlacementSelectionView: NSView {
    private let screenFrame: CGRect
    private let previewSize = CGSize(width: 320, height: 120)
    private let onSave: (AlertPopupPlacement) -> Void
    private let onCancel: () -> Void
    private let previewView: DraggableAlertPopupPreviewView
    private var selectedOrigin: CGPoint

    init(
        frame frameRect: NSRect,
        screenFrame: CGRect,
        initialPlacement: AlertPopupPlacement,
        onSave: @escaping (AlertPopupPlacement) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screenFrame = screenFrame
        self.onSave = onSave
        self.onCancel = onCancel

        let initialScreenOrigin = initialPlacement.popupOrigin(
            panelSize: previewSize,
            in: screenFrame
        )
        self.selectedOrigin = CGPoint(
            x: initialScreenOrigin.x - screenFrame.minX,
            y: initialScreenOrigin.y - screenFrame.minY
        )
        self.previewView = DraggableAlertPopupPreviewView(
            frame: NSRect(origin: selectedOrigin, size: previewSize)
        )

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor

        configureHeader()
        configurePreview()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }

    private func configureHeader() {
        let titleLabel = NSTextField(labelWithString: "알림 위치 설정")
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white

        let descriptionLabel = NSTextField(labelWithString: "알림 박스를 원하는 위치로 드래그한 뒤 저장하세요.")
        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .white.withAlphaComponent(0.82)

        let saveButton = NSButton(title: "저장", target: self, action: #selector(savePlacement))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "취소", target: self, action: #selector(cancelSelection))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let textStack = NSStackView(views: [titleLabel, descriptionLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let buttonStack = NSStackView(views: [cancelButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8

        let headerStack = NSStackView(views: [textStack, buttonStack])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 24
        headerStack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        headerStack.wantsLayer = true
        headerStack.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.58).cgColor
        headerStack.layer?.cornerRadius = 10

        addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            headerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            headerStack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -48)
        ])
    }

    private func configurePreview() {
        previewView.onMove = { [weak self] origin in
            self?.selectedOrigin = origin
        }
        addSubview(previewView)
    }

    @objc private func savePlacement() {
        let screenOrigin = CGPoint(
            x: selectedOrigin.x + screenFrame.minX,
            y: selectedOrigin.y + screenFrame.minY
        )
        let placement = AlertPopupPlacement.placement(
            from: screenOrigin,
            panelSize: previewSize,
            in: screenFrame
        )

        onSave(placement)
    }

    @objc private func cancelSelection() {
        onCancel()
    }
}

private final class DraggableAlertPopupPreviewView: NSView {
    var onMove: ((CGPoint) -> Void)?
    private var dragOffset: CGPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        dragOffset = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let superview else {
            return
        }

        let location = superview.convert(event.locationInWindow, from: nil)
        var nextOrigin = CGPoint(
            x: location.x - dragOffset.x,
            y: location.y - dragOffset.y
        )

        nextOrigin.x = nextOrigin.x.clamped(to: 0...(superview.bounds.width - frame.width))
        nextOrigin.y = nextOrigin.y.clamped(to: 0...(superview.bounds.height - frame.height))

        setFrameOrigin(nextOrigin)
        onMove?(nextOrigin)
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        shadow = NSShadow()
        shadow?.shadowBlurRadius = 16
        shadow?.shadowOffset = CGSize(width: 0, height: -4)
        shadow?.shadowColor = NSColor.black.withAlphaComponent(0.28)

        let titleLabel = NSTextField(labelWithString: "스킬 사용 가능")
        titleLabel.font = .boldSystemFont(ofSize: 15)

        let bodyLabel = NSTextField(labelWithString: "알림은 이 위치에 표시됩니다.")
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor

        let dragLabel = NSTextField(labelWithString: "드래그")
        dragLabel.font = .systemFont(ofSize: 12, weight: .medium)
        dragLabel.textColor = .controlAccentColor

        let stackView = NSStackView(views: [titleLabel, bodyLabel, dragLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
