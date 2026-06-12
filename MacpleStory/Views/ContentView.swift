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
    @EnvironmentObject private var ruleStore: SkillDetectionRuleStore
    @EnvironmentObject private var autoTriggerCoordinator: SkillAutoTriggerCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            RegisteredSkillListView()

            Divider()

            AutoTriggerControlView()

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

private struct AutoTriggerControlView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore
    @EnvironmentObject private var ruleStore: SkillDetectionRuleStore
    @EnvironmentObject private var autoTriggerCoordinator: SkillAutoTriggerCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: autoTriggerCoordinator.isRunning ? "dot.radiowaves.left.and.right" : "dot.scope")
                    .foregroundStyle(autoTriggerCoordinator.isRunning ? .green : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("자동 감지")
                        .font(.headline)

                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(detailColor)
                        .lineLimit(autoTriggerCoordinator.lastErrorMessage == nil ? 1 : 2)
                }

                Spacer()

                Button {
                    toggleMonitoring()
                } label: {
                    Label(
                        autoTriggerCoordinator.isRunning ? "정지" : "시작",
                        systemImage: autoTriggerCoordinator.isRunning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(autoTriggerCoordinator.isRunning ? .red : .accentColor)
            }

            HStack(spacing: 8) {
                Text(captureSourceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    selectWindow()
                } label: {
                    Label(
                        autoTriggerCoordinator.isPresentingCapturePicker ? "선택 중" : "창 선택",
                        systemImage: "cursorarrow.click"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(autoTriggerCoordinator.isPresentingCapturePicker)
                .help("메이플스토리 창 직접 선택")
            }
        }
    }

    private var captureSourceText: String {
        guard let source = autoTriggerCoordinator.userSelectedCaptureSource else {
            return "캡처 창 미선택"
        }

        return "\(source.displayName) · \(source.sizeText)"
    }

    private var detailText: String {
        if let errorMessage = autoTriggerCoordinator.lastErrorMessage {
            return errorMessage
        }

        if let timerID = autoTriggerCoordinator.lastTriggeredSkillTimerID,
           let timer = timerStore.skillTimers.first(where: { $0.id == timerID }) {
            return "최근 시작: \(timer.name)"
        }

        if let result = autoTriggerCoordinator.lastDetectedResult {
            return "최근 감지: \(Int(result.confidence * 100))%"
        }

        if let resolution = autoTriggerCoordinator.lastDetectedResolution {
            return "해상도: \(resolution.displayText)"
        }

        if let windowMessage = autoTriggerCoordinator.lastWindowRefreshMessage {
            return windowMessage
        }

        return autoTriggerCoordinator.isRunning
            ? "실행 중 · 규칙 \(ruleStore.rules.count)개"
            : "정지 · 규칙 \(ruleStore.rules.count)개"
    }

    private var detailColor: Color {
        autoTriggerCoordinator.lastErrorMessage == nil ? .secondary : .red
    }

    private func toggleMonitoring() {
        if autoTriggerCoordinator.isRunning {
            autoTriggerCoordinator.stop()
        } else {
            Task {
                await autoTriggerCoordinator.startMonitoring(
                    timerStore: timerStore,
                    ruleStore: ruleStore
                )
            }
        }
    }

    private func selectWindow() {
        Task {
            await autoTriggerCoordinator.requestUserSelectedWindow()
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
            .environmentObject(SkillDetectionRuleStore())
            .environmentObject(SkillAutoTriggerCoordinator())
    }
}
