//
//  AlertNotificationService.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import AppKit
import Foundation
import UserNotifications

protocol AlertNotificationProviding: AnyObject {
    var popupPlacement: AlertPopupPlacement { get set }
    /// 팝업을 띄울 대상 디스플레이. `AlertTargetDisplay.mainDisplayID`(0)이면 주 화면.
    var targetDisplayID: CGDirectDisplayID { get set }
    /// 알림 표시 방식(알림창 / 점등형 / 둘 다).
    var presentationStyle: AlertPresentationStyle { get set }
    /// 팝업 박스 배경과 테두리 점등에 쓰는 사용자 지정 색상.
    var accentColor: AlertColor { get set }

    func requestAuthorization()
    func notifyPreAlert(for timer: SkillTimer)
    func notifyReadyAlert(for timer: SkillTimer)
    func notifyExperienceBuffExpired(name: String)
    func notifyExperienceBuffExpiring(name: String, secondsLeft: Int)
    func beginPopupPlacementSelection(
        initialPlacement: AlertPopupPlacement,
        completion: @escaping (AlertPopupPlacement) -> Void
    )
    func beginAccentColorSelection(
        initialColor: AlertColor,
        completion: @escaping (AlertColor) -> Void
    )
}

final class AlertNotificationService: NSObject, AlertNotificationProviding, UNUserNotificationCenterDelegate {
    private let notificationCenter: UNUserNotificationCenter
    private let placementSelector = AlertPopupPlacementSelector()
    private let colorSelector = AlertColorSelector()
    private let borderGlowPresenter = BorderGlowOverlayPresenter()
    private var popupPanels: [NSPanel] = []
    var popupPlacement: AlertPopupPlacement
    var targetDisplayID: CGDirectDisplayID
    var presentationStyle: AlertPresentationStyle
    var accentColor: AlertColor

    init(
        popupPlacement: AlertPopupPlacement = .defaultValue,
        targetDisplayID: CGDirectDisplayID = AlertTargetDisplay.mainDisplayID,
        presentationStyle: AlertPresentationStyle = .defaultValue,
        accentColor: AlertColor = .defaultValue
    ) {
        self.notificationCenter = .current()
        self.popupPlacement = popupPlacement
        self.targetDisplayID = targetDisplayID
        self.presentationStyle = presentationStyle
        self.accentColor = accentColor
        super.init()
        notificationCenter.delegate = self
    }

    func requestAuthorization() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else {
                return
            }

            self?.notificationCenter.requestAuthorization(options: [.alert]) { _, error in
                if let error {
                    print("Failed to request notification authorization: \(error)")
                }
            }
        }
    }

    func notifyPreAlert(for timer: SkillTimer) {
        sendNotification(
            title: "스킬 준비 알림",
            body: "\(timer.name) \(timer.alertBeforeSeconds)초 전입니다.",
            identifier: "\(timer.id.uuidString)-pre-alert",
            colorOverride: timer.alertColor
        )
    }

    func notifyReadyAlert(for timer: SkillTimer) {
        sendNotification(
            title: "스킬 사용 가능",
            body: "\(timer.name)을 사용할 수 있습니다.",
            identifier: "\(timer.id.uuidString)-ready-alert-\(Date().timeIntervalSince1970)",
            colorOverride: timer.alertColor
        )
    }

    func notifyExperienceBuffExpired(name: String) {
        sendNotification(
            title: "경험치 버프 꺼짐",
            body: "\(name) 버프가 꺼졌습니다.",
            identifier: "experience-buff-expired-\(Date().timeIntervalSince1970)"
        )
    }

    func notifyExperienceBuffExpiring(name: String, secondsLeft: Int) {
        sendNotification(
            title: "버프 곧 만료",
            body: "\(name) 버프가 약 \(secondsLeft)초 후 만료됩니다.",
            identifier: "experience-buff-expiring-\(Date().timeIntervalSince1970)"
        )
    }

    func beginPopupPlacementSelection(
        initialPlacement: AlertPopupPlacement,
        completion: @escaping (AlertPopupPlacement) -> Void
    ) {
        placementSelector.beginSelection(
            initialPlacement: initialPlacement,
            completion: completion
        )
    }

    func beginAccentColorSelection(
        initialColor: AlertColor,
        completion: @escaping (AlertColor) -> Void
    ) {
        colorSelector.beginSelection(
            initialColor: initialColor,
            onPreviewGlow: { [weak self] color in
                guard let self else {
                    return
                }

                self.borderGlowPresenter.flash(color: color, on: self.targetScreen ?? NSScreen.main)
            },
            completion: completion
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    private func sendNotification(
        title: String,
        body: String,
        identifier: String,
        colorOverride: AlertColor? = nil
    ) {
        // 스킬별 색이 지정돼 있으면 그 색을, 없으면 전역 알림 색을 사용한다.
        let color = colorOverride ?? accentColor

        // 선택한 디스플레이(예: 넷플릭스 모니터)에 띄워야 하므로 위치 제어가 불가능한
        // 시스템 알림 대신 항상 커스텀 팝업을 사용한다.
        if presentationStyle.showsPopup {
            showPopup(title: title, body: body, color: color)
        }

        guard presentationStyle.showsBorderGlow else {
            return
        }

        let screen = targetScreen ?? NSScreen.main
        let glowColor = color.nsColor
        DispatchQueue.main.async { [weak self] in
            self?.borderGlowPresenter.flash(color: glowColor, on: screen)
        }
    }

    private func showPopup(title: String, body: String, color: AlertColor) {
        DispatchQueue.main.async {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
                styleMask: [.titled, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "MacpleStory"
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let accent = color
            let textColor = accent.contrastingTextColor

            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = .boldSystemFont(ofSize: 15)
            titleLabel.textColor = textColor

            let bodyLabel = NSTextField(labelWithString: body)
            bodyLabel.font = .systemFont(ofSize: 13)
            bodyLabel.textColor = textColor.withAlphaComponent(0.85)
            bodyLabel.lineBreakMode = .byWordWrapping
            bodyLabel.maximumNumberOfLines = 2

            let stackView = NSStackView(views: [titleLabel, bodyLabel])
            stackView.orientation = .vertical
            stackView.alignment = .leading
            stackView.spacing = 6
            stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            stackView.wantsLayer = true
            stackView.layer?.backgroundColor = accent.nsColor.cgColor
            stackView.layer?.cornerRadius = 10

            panel.backgroundColor = accent.nsColor
            panel.contentView = stackView
            panel.setFrameOrigin(self.popupOrigin(for: panel.frame.size))
            panel.orderFrontRegardless()

            self.popupPanels.append(panel)

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self, weak panel] in
                guard let panel else {
                    return
                }

                panel.close()
                self?.popupPanels.removeAll { $0 === panel }
            }
        }
    }

    private func popupOrigin(for panelSize: CGSize) -> CGPoint {
        let screenFrame = (targetScreen ?? NSScreen.main)?.visibleFrame ?? .zero
        return popupPlacement.popupOrigin(
            panelSize: panelSize,
            in: screenFrame
        )
    }

    /// 선택한 대상 디스플레이의 화면. 못 찾으면 nil(→ 주 화면으로 폴백).
    private var targetScreen: NSScreen? {
        guard targetDisplayID != AlertTargetDisplay.mainDisplayID else {
            return nil
        }

        return NSScreen.screens.first { $0.displayID == targetDisplayID }
    }
}
