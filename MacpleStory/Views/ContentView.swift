//
//  ContentView.swift
//  MacpleStory
//
//  Created by 고혜역 on 6/12/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            RegisteredSkillListView()

            Divider()

            SkillInputFormView()

            Divider()

            AlertPopupPlacementSettingsView()

            Divider()

            HStack {
                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(width: 380)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("MacpleStory")
                    .font(.headline)

                Text("메이플스토리 스킬 타이머")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(
                runningCount: timerStore.runningTimerCount,
                totalCount: timerStore.skillTimers.count
            )
        }
    }
}

private struct AlertPopupPlacementSettingsView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("알림 위치")
                        .font(.headline)

                    Text(timerStore.alertPopupPlacement.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    timerStore.beginAlertPopupPlacementSelection()
                } label: {
                    Label("위치 설정", systemImage: "location.viewfinder")
                }
            }
        }
    }
}

private struct RegisteredSkillListView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("등록된 스킬")
                    .font(.headline)

                Spacer()

                Text("\(timerStore.skillTimers.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if timerStore.skillTimers.isEmpty {
                EmptyTimerView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(timerStore.skillTimers) { skillTimer in
                            SkillTimerRowView(skillTimer: skillTimer)
                        }
                    }
                }
                .frame(minHeight: 74, maxHeight: 220)
            }
        }
    }
}

private struct StatusBadge: View {
    let runningCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(runningCount > 0 ? "실행 중" : "대기")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(runningCount > 0 ? .green : .secondary)

            Text("\(runningCount)/\(totalCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyTimerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("아직 등록된 스킬이 없습니다", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SkillTimerStore())
    }
}
