//
//  MacpleStoryTests.swift
//  MacpleStoryTests
//
//  Created by 고혜역 on 6/12/26.
//

import CoreGraphics
import Testing
@testable import MacpleStory

struct MacpleStoryTests {

    @Test func timerCountsDownWhileRunning() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "테스트 스킬",
            cooldownSeconds: 3,
            alertBeforeSeconds: 1,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        store.toggleTimer(id: timerID)

        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 2)
        #expect(store.skillTimers.first?.isRunning == true)

        store.tick()
        store.tick()
        #expect(store.skillTimers.first?.remainingSeconds == 0)
        #expect(store.skillTimers.first?.isRunning == false)
    }

    @Test func completedTimerRestartsFromCooldown() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "재시작 스킬",
            cooldownSeconds: 2,
            alertBeforeSeconds: 1,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        store.toggleTimer(id: timerID)
        store.tick()
        store.tick()

        store.toggleTimer(id: timerID)

        #expect(store.skillTimers.first?.remainingSeconds == 2)
        #expect(store.skillTimers.first?.isRunning == true)
    }

    @Test func menuBarStatusHighlightsWarningAndReadyTimers() async throws {
        let store = SkillTimerStore(alertNotificationService: NoopAlertNotificationService())

        store.addTimer(
            name: "임박 스킬",
            cooldownSeconds: 3,
            alertBeforeSeconds: 2,
            preAlertSoundID: nil,
            readyAlertSoundID: nil
        )

        let timerID = try #require(store.skillTimers.first?.id)
        store.toggleTimer(id: timerID)
        store.tick()

        #expect(store.menuBarStatus.tone == .warning)
        #expect(store.menuBarStatus.title == "임박 스킬 00:02 남음")

        store.tick()
        store.tick()

        #expect(store.menuBarStatus.tone == .ready)
        #expect(store.menuBarStatus.title == "임박 스킬 사용 가능")
    }

    @Test func alertPopupPlacementConvertsBetweenNormalizedAndScreenOrigin() async throws {
        let screenFrame = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let panelSize = CGSize(width: 200, height: 100)
        let placement = AlertPopupPlacement(normalizedX: 0.5, normalizedY: 0.25)

        let origin = placement.popupOrigin(panelSize: panelSize, in: screenFrame)

        #expect(origin.x == 500)
        #expect(origin.y == 575)

        let restoredPlacement = AlertPopupPlacement.placement(
            from: origin,
            panelSize: panelSize,
            in: screenFrame
        )

        #expect(restoredPlacement == placement)
    }

    @Test func alertPopupPlacementUsesTopLeftCoordinateSemantics() async throws {
        let screenFrame = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let panelSize = CGSize(width: 200, height: 100)

        let topLeftOrigin = AlertPopupPlacement(
            normalizedX: 0,
            normalizedY: 0
        ).popupOrigin(panelSize: panelSize, in: screenFrame)

        #expect(topLeftOrigin.x == 100)
        #expect(topLeftOrigin.y == 750)

        let bottomRightOrigin = AlertPopupPlacement(
            normalizedX: 1,
            normalizedY: 1
        ).popupOrigin(panelSize: panelSize, in: screenFrame)

        #expect(bottomRightOrigin.x == 900)
        #expect(bottomRightOrigin.y == 50)
    }

}

private final class NoopAlertNotificationService: AlertNotificationProviding {
    var popupPlacement: AlertPopupPlacement = .defaultValue

    func requestAuthorization() {}
    func notifyPreAlert(for timer: SkillTimer) {}
    func notifyReadyAlert(for timer: SkillTimer) {}

    func beginPopupPlacementSelection(
        initialPlacement: AlertPopupPlacement,
        completion: @escaping (AlertPopupPlacement) -> Void
    ) {}
}
