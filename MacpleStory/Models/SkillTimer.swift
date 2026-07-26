//
//  SkillTimer.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Foundation

struct SkillTimer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var cooldownSeconds: Int
    var alertBeforeSeconds: Int
    var remainingSeconds: Int
    var isRunning: Bool
    var didSendPreAlert: Bool
    var preAlertSoundID: String?
    var readyAlertSoundID: String?
    /// 이 스킬 전용 알림 색상. nil이면 전역 알림 색상을 사용한다.
    var alertColor: AlertColor?

    init(
        id: UUID = UUID(),
        name: String,
        cooldownSeconds: Int,
        alertBeforeSeconds: Int,
        remainingSeconds: Int? = nil,
        isRunning: Bool = false,
        didSendPreAlert: Bool = false,
        preAlertSoundID: String? = nil,
        readyAlertSoundID: String? = nil,
        alertColor: AlertColor? = nil
    ) {
        self.id = id
        self.name = name
        self.cooldownSeconds = cooldownSeconds
        self.alertBeforeSeconds = alertBeforeSeconds
        self.remainingSeconds = remainingSeconds ?? cooldownSeconds
        self.isRunning = isRunning
        self.didSendPreAlert = didSendPreAlert
        self.preAlertSoundID = preAlertSoundID
        self.readyAlertSoundID = readyAlertSoundID
        self.alertColor = alertColor
    }
}
