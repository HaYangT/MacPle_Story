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

    func requestAuthorization()
    func notifyPreAlert(for timer: SkillTimer)
    func notifyReadyAlert(for timer: SkillTimer)
    func notifyExperienceBuffExpired(name: String)
    func beginPopupPlacementSelection(
        initialPlacement: AlertPopupPlacement,
        completion: @escaping (AlertPopupPlacement) -> Void
    )
}

final class AlertNotificationService: NSObject, AlertNotificationProviding, UNUserNotificationCenterDelegate {
    private let notificationCenter: UNUserNotificationCenter
    private let placementSelector = AlertPopupPlacementSelector()
    private var popupPanels: [NSPanel] = []
    var popupPlacement: AlertPopupPlacement

    init(popupPlacement: AlertPopupPlacement = .defaultValue) {
        self.notificationCenter = .current()
        self.popupPlacement = popupPlacement
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
            identifier: "\(timer.id.uuidString)-pre-alert"
        )
    }

    func notifyReadyAlert(for timer: SkillTimer) {
        sendNotification(
            title: "스킬 사용 가능",
            body: "\(timer.name)을 사용할 수 있습니다.",
            identifier: "\(timer.id.uuidString)-ready-alert-\(Date().timeIntervalSince1970)"
        )
    }

    func notifyExperienceBuffExpired(name: String) {
        sendNotification(
            title: "경험치 버프 꺼짐",
            body: "\(name) 버프가 꺼졌습니다.",
            identifier: "experience-buff-expired-\(Date().timeIntervalSince1970)"
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    private func sendNotification(title: String, body: String, identifier: String) {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body

                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: nil
                )

                self.notificationCenter.add(request) { error in
                    if let error {
                        print("Failed to send notification: \(error)")
                        self.showPopup(title: title, body: body)
                    }
                }
            case .notDetermined:
                self.requestAuthorization()
                self.showPopup(title: title, body: body)
            case .denied:
                self.showPopup(title: title, body: body)
            @unknown default:
                self.showPopup(title: title, body: body)
            }
        }
    }

    private func showPopup(title: String, body: String) {
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

            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = .boldSystemFont(ofSize: 15)

            let bodyLabel = NSTextField(labelWithString: body)
            bodyLabel.font = .systemFont(ofSize: 13)
            bodyLabel.textColor = .secondaryLabelColor
            bodyLabel.lineBreakMode = .byWordWrapping
            bodyLabel.maximumNumberOfLines = 2

            let stackView = NSStackView(views: [titleLabel, bodyLabel])
            stackView.orientation = .vertical
            stackView.alignment = .leading
            stackView.spacing = 6
            stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

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
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        return popupPlacement.popupOrigin(
            panelSize: panelSize,
            in: screenFrame
        )
    }
}
