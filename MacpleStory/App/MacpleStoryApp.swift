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

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(timerStore)
                .onAppear {
                    timerStore.requestNotificationAuthorization()
                }
        } label: {
            MenuBarStatusLabelView(status: timerStore.menuBarStatus)
        }
        .menuBarExtraStyle(.window)
    }
}
