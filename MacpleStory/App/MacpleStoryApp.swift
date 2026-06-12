//
//  MacpleStoryApp.swift
//  MacpleStory
//
//  Created by 고혜역 on 6/12/26.
//

import SwiftUI

@main
struct MacpleStoryApp: App {
    @StateObject private var timerStore = SkillTimerStore()
    @StateObject private var detectionRuleStore = SkillDetectionRuleStore()
    @StateObject private var autoTriggerCoordinator = SkillAutoTriggerCoordinator()
    private let screenRecordingPermissionService = ScreenRecordingPermissionService()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(timerStore)
                .environmentObject(detectionRuleStore)
                .environmentObject(autoTriggerCoordinator)
                .onAppear {
                    timerStore.requestNotificationAuthorization()
                    screenRecordingPermissionService.requestPermissionOnceIfNeeded()
                }
        } label: {
            MenuBarStatusLabelView(status: timerStore.menuBarStatus)
        }
        .menuBarExtraStyle(.window)
    }
}
