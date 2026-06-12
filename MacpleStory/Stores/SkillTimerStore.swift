//
//  SkillTimerStore.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Combine
import Foundation

final class SkillTimerStore: ObservableObject {
    @Published private(set) var skillTimers: [SkillTimer] = []
    @Published private(set) var alertSounds: [AlertSound] = []
    @Published private(set) var alertPopupPlacement: AlertPopupPlacement
    @Published var alertSoundImportErrorMessage: String?

    private let alertSoundService: AlertSoundService
    private let alertNotificationService: AlertNotificationProviding
    private var tickerCancellable: AnyCancellable?
    private static let alertPopupPlacementDefaultsKey = "alertPopupPlacement"

    init(
        alertSoundService: AlertSoundService = AlertSoundService(),
        alertNotificationService: AlertNotificationProviding = AlertNotificationService()
    ) {
        self.alertSoundService = alertSoundService
        self.alertNotificationService = alertNotificationService
        self.alertPopupPlacement = Self.loadAlertPopupPlacement()
        self.alertNotificationService.popupPlacement = alertPopupPlacement
        reloadAlertSounds()
    }

    var runningTimerCount: Int {
        skillTimers.filter(\.isRunning).count
    }

    var menuBarStatus: MenuBarTimerStatus {
        if let readyTimer = skillTimers.first(where: { !$0.isRunning && $0.remainingSeconds == 0 }) {
            return MenuBarTimerStatus(
                title: "\(readyTimer.name) 사용 가능",
                systemImageName: "bolt.fill",
                tone: .ready
            )
        }

        let runningTimers = skillTimers.filter(\.isRunning)

        if let warningTimer = runningTimers
            .filter({ $0.alertBeforeSeconds > 0 && $0.remainingSeconds <= $0.alertBeforeSeconds })
            .min(by: { $0.remainingSeconds < $1.remainingSeconds }) {
            return MenuBarTimerStatus(
                title: "\(warningTimer.name) \(warningTimer.remainingSeconds.timerText) 남음",
                systemImageName: "bell.fill",
                tone: .warning
            )
        }

        if let nextTimer = runningTimers.min(by: { $0.remainingSeconds < $1.remainingSeconds }) {
            return MenuBarTimerStatus(
                title: "\(nextTimer.name) \(nextTimer.remainingSeconds.timerText)",
                systemImageName: "timer",
                tone: .running
            )
        }

        return MenuBarTimerStatus(
            title: "MacpleStory",
            systemImageName: "timer",
            tone: .idle
        )
    }

    func reloadAlertSounds() {
        alertSounds = alertSoundService.availableSounds()
    }

    func requestNotificationAuthorization() {
        alertNotificationService.requestAuthorization()
    }

    func beginAlertPopupPlacementSelection() {
        alertNotificationService.beginPopupPlacementSelection(
            initialPlacement: alertPopupPlacement
        ) { [weak self] placement in
            self?.updateAlertPopupPlacement(placement)
        }
    }

    func updateAlertPopupPlacement(_ placement: AlertPopupPlacement) {
        alertPopupPlacement = placement
        alertNotificationService.popupPlacement = placement
        saveAlertPopupPlacement(placement)
    }

    func importAlertSound(from sourceURL: URL) {
        do {
            _ = try alertSoundService.importSound(from: sourceURL)
            alertSoundImportErrorMessage = nil
            reloadAlertSounds()
        } catch {
            alertSoundImportErrorMessage = error.localizedDescription
        }
    }

    func addTimer(
        name: String,
        cooldownSeconds: Int,
        alertBeforeSeconds: Int,
        preAlertSoundID: AlertSound.ID?,
        readyAlertSoundID: AlertSound.ID?
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        let normalizedCooldown = max(1, cooldownSeconds)
        let normalizedAlert = min(max(0, alertBeforeSeconds), normalizedCooldown)

        skillTimers.append(
            SkillTimer(
                name: trimmedName,
                cooldownSeconds: normalizedCooldown,
                alertBeforeSeconds: normalizedAlert,
                preAlertSoundID: preAlertSoundID,
                readyAlertSoundID: readyAlertSoundID
            )
        )
    }

    func playPreAlertSound(for timer: SkillTimer) {
        guard let soundID = timer.preAlertSoundID else {
            return
        }

        alertSoundService.playSound(id: soundID, from: alertSounds)
    }

    func playReadyAlertSound(for timer: SkillTimer) {
        guard let soundID = timer.readyAlertSoundID else {
            return
        }

        alertSoundService.playSound(id: soundID, from: alertSounds)
    }

    func removeTimer(id: SkillTimer.ID) {
        skillTimers.removeAll { $0.id == id }
        stopTickerIfIdle()
    }

    func startTimer(id: SkillTimer.ID) {
        var didStartTimer = false

        updateTimer(id: id) { timer in
            guard !timer.isRunning else {
                return
            }

            if timer.remainingSeconds <= 0 {
                timer.remainingSeconds = timer.cooldownSeconds
                timer.didSendPreAlert = false
            }

            timer.isRunning = true
            didStartTimer = true
        }

        if didStartTimer {
            startTickerIfNeeded()
        }
    }

    func stopTimer(id: SkillTimer.ID) {
        updateTimer(id: id) { timer in
            timer.isRunning = false
        }

        stopTickerIfIdle()
    }

    func toggleTimer(id: SkillTimer.ID) {
        guard let timer = skillTimers.first(where: { $0.id == id }) else {
            return
        }

        if timer.isRunning {
            stopTimer(id: id)
        } else {
            startTimer(id: id)
        }
    }

    func resetTimer(id: SkillTimer.ID) {
        updateTimer(id: id) { timer in
            timer.remainingSeconds = timer.cooldownSeconds
            timer.isRunning = false
            timer.didSendPreAlert = false
        }

        stopTickerIfIdle()
    }

    @discardableResult
    func triggerCooldown(id: SkillTimer.ID) -> Bool {
        var didTriggerCooldown = false

        updateTimer(id: id) { timer in
            guard !timer.isRunning else {
                return
            }

            timer.remainingSeconds = timer.cooldownSeconds
            timer.isRunning = true
            timer.didSendPreAlert = false
            didTriggerCooldown = true
        }

        if didTriggerCooldown {
            startTickerIfNeeded()
        }

        return didTriggerCooldown
    }

    func tick() {
        guard skillTimers.contains(where: \.isRunning) else {
            stopTickerIfIdle()
            return
        }

        for index in skillTimers.indices {
            guard skillTimers[index].isRunning else {
                continue
            }

            if skillTimers[index].remainingSeconds > 0 {
                skillTimers[index].remainingSeconds -= 1
            }

            if skillTimers[index].remainingSeconds <= 0 {
                skillTimers[index].remainingSeconds = 0
                skillTimers[index].isRunning = false
                skillTimers[index].didSendPreAlert = true
                playReadyAlertSound(for: skillTimers[index])
                alertNotificationService.notifyReadyAlert(for: skillTimers[index])
                continue
            }

            let shouldSendPreAlert = skillTimers[index].alertBeforeSeconds > 0
                && skillTimers[index].remainingSeconds <= skillTimers[index].alertBeforeSeconds
                && !skillTimers[index].didSendPreAlert

            if shouldSendPreAlert {
                skillTimers[index].didSendPreAlert = true
                playPreAlertSound(for: skillTimers[index])
                alertNotificationService.notifyPreAlert(for: skillTimers[index])
            }
        }

        stopTickerIfIdle()
    }

    private func updateTimer(id: SkillTimer.ID, mutate: (inout SkillTimer) -> Void) {
        guard let index = skillTimers.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&skillTimers[index])
    }

    private func startTickerIfNeeded() {
        guard tickerCancellable == nil else {
            return
        }

        tickerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTickerIfIdle() {
        guard !skillTimers.contains(where: \.isRunning) else {
            return
        }

        tickerCancellable?.cancel()
        tickerCancellable = nil
    }

    private static func loadAlertPopupPlacement() -> AlertPopupPlacement {
        guard
            let data = UserDefaults.standard.data(forKey: alertPopupPlacementDefaultsKey),
            let placement = try? JSONDecoder().decode(AlertPopupPlacement.self, from: data)
        else {
            return .defaultValue
        }

        return placement
    }

    private func saveAlertPopupPlacement(_ placement: AlertPopupPlacement) {
        guard let data = try? JSONEncoder().encode(placement) else {
            return
        }

        UserDefaults.standard.set(data, forKey: Self.alertPopupPlacementDefaultsKey)
    }
}
