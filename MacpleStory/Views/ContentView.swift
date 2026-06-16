//
//  ContentView.swift
//  MacpleStory
//
//  Created by 고혜역 on 6/12/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable {
    case skillTimer = "스킬 타이머"
    case buffAlert = "버프 감지"

    var systemImage: String {
        switch self {
        case .skillTimer: return "timer"
        case .buffAlert: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore
    @EnvironmentObject private var ruleStore: SkillDetectionRuleStore
    @EnvironmentObject private var autoTriggerCoordinator: SkillAutoTriggerCoordinator
    @State private var selectedTab: AppTab = .skillTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .skillTimer:
                        SkillTimerTabView()
                    case .buffAlert:
                        BuffAlertTabView()
                    }
                }
                .padding(16)
            }

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 380, height: 540)
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

    private var footer: some View {
        HStack {
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - 스킬 타이머 탭

private struct SkillTimerTabView: View {
    var body: some View {
        RegisteredSkillListView()

        Divider()

        SkillInputFormView()

        Divider()

        AutoTriggerControlView()

        Divider()

        AlertSettingsView()
    }
}

// MARK: - 버프 감지 탭

private struct BuffAlertTabView: View {
    var body: some View {
        AutoTriggerControlView()

        Divider()

        ExperienceBuffAlertSettingsView()

        Divider()

        AlertSettingsView()
    }
}

// MARK: - 자동 감지 컨트롤

private struct AutoTriggerControlView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore
    @EnvironmentObject private var ruleStore: SkillDetectionRuleStore
    @EnvironmentObject private var experienceBuffStore: ExperienceBuffAlertStore
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

                    if let debugText {
                        Text(debugText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
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

    private var debugText: String? {
        guard let snapshot = autoTriggerCoordinator.lastDetectionDebugSnapshot else {
            return nil
        }
        return "\(snapshot.message) · \(snapshot.summaryText)"
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
                    ruleStore: ruleStore,
                    experienceBuffStore: experienceBuffStore
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

// MARK: - 경험치 버프 알림 설정

private struct ExperienceBuffAlertSettingsView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore
    @EnvironmentObject private var experienceBuffStore: ExperienceBuffAlertStore
    @EnvironmentObject private var autoTriggerCoordinator: SkillAutoTriggerCoordinator
    @State private var iconImportErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: Binding(
                    get: { experienceBuffStore.settings.isEnabled },
                    set: { experienceBuffStore.updateEnabled($0) }
                )) {
                    Label("경험치 버프 알림", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                }

                Spacer()

                Button {
                    addExperienceBuffEntry()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("경험치 버프 아이콘 추가")
            }

            if let message = autoTriggerCoordinator.lastExperienceBuffAlertMessage,
               experienceBuffStore.settings.isEnabled,
               !experienceBuffStore.settings.entries.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if experienceBuffStore.settings.entries.isEmpty {
                Text("아이콘을 추가하면 버프 종료 시 알림이 울립니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(experienceBuffStore.settings.entries) { entry in
                    ExperienceBuffEntryRow(
                        entry: entry,
                        alertSounds: timerStore.alertSounds,
                        detectionResult: autoTriggerCoordinator.lastExperienceBuffDetectionResults
                            .first(where: { $0.entryID == entry.id }),
                        captureSource: autoTriggerCoordinator.userSelectedCaptureSource
                    )
                }
            }

            if let iconImportErrorMessage {
                Label(iconImportErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func addExperienceBuffEntry() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            let iconTemplate = try SkillIconTemplateImporter().importTemplate(from: selectedURL)
            let entry = ExperienceBuffEntry(
                iconTemplate: iconTemplate,
                iconName: selectedURL.deletingPathExtension().lastPathComponent
            )
            experienceBuffStore.addEntry(entry)
            iconImportErrorMessage = nil
        } catch {
            iconImportErrorMessage = error.localizedDescription
        }
    }
}

private struct ExperienceBuffEntryRow: View {
    @EnvironmentObject private var timerStore: SkillTimerStore
    @EnvironmentObject private var experienceBuffStore: ExperienceBuffAlertStore

    let entry: ExperienceBuffEntry
    let alertSounds: [AlertSound]
    let detectionResult: ExperienceBuffDetectionResult?
    let captureSource: UserSelectedCaptureSource?

    private var selectedAlertSoundID: Binding<String> {
        Binding(
            get: { entry.alertSoundID ?? "" },
            set: { experienceBuffStore.updateEntryAlertSoundID(id: entry.id, alertSoundID: $0.isEmpty ? nil : $0) }
        )
    }

    private var coordinateText: String? {
        guard let result = detectionResult,
              result.isActive,
              let region = result.iconRegion else {
            return nil
        }

        guard let captureSource else {
            return String(
                format: "위치 %.0f%%, %.0f%%",
                region.x * 100,
                region.y * 100
            )
        }

        let rect = region.pixelRect(
            pixelWidth: captureSource.pixelWidth,
            pixelHeight: captureSource.pixelHeight
        )

        return "x:\(Int(rect.minX)) y:\(Int(rect.minY)) · \(Int(rect.width))×\(Int(rect.height))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)

                    if let image = NSImage(data: entry.iconTemplate.pngData) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(3)
                    }
                }
                .frame(width: 34, height: 34)
                .overlay(alignment: .bottomTrailing) {
                    if detectionResult?.isActive == true {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.iconName)
                        .font(.subheadline)
                        .lineLimit(1)

                    if let result = detectionResult {
                        Text(result.isActive ? "감지 중 · \(Int(result.confidence * 100))%" : "미감지")
                            .font(.caption2)
                            .foregroundStyle(result.isActive ? .green : .secondary)

                        if let coordinateText {
                            Text(coordinateText)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { entry.isEnabled },
                    set: { experienceBuffStore.updateEntryEnabled(id: entry.id, isEnabled: $0) }
                ))
                .labelsHidden()

                Button {
                    experienceBuffStore.removeEntry(id: entry.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("버프 제거")
            }

            if !alertSounds.isEmpty {
                Picker("알림음", selection: selectedAlertSoundID) {
                    Text("선택 안 함").tag("")
                    ForEach(alertSounds) { alertSound in
                        Text("\(alertSound.displayName) · \(alertSound.formatLabel)")
                            .tag(alertSound.id)
                    }
                }
                .font(.caption)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 알림 설정

private struct AlertSettingsView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Slider(
                    value: Binding(
                        get: { timerStore.alertVolume * 100 },
                        set: { timerStore.updateAlertVolume($0 / 100) }
                    ),
                    in: 0...100,
                    step: 1
                )

                Text("\(Int((timerStore.alertVolume * 100).rounded()))%")
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}

// MARK: - 등록된 스킬 목록

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
                LazyVStack(spacing: 8) {
                    ForEach(timerStore.skillTimers) { skillTimer in
                        SkillTimerRowView(skillTimer: skillTimer)
                    }
                }
            }
        }
    }
}

// MARK: - 공통 컴포넌트

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
        Label("아직 등록된 스킬이 없습니다", systemImage: "clock")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SkillTimerStore())
            .environmentObject(SkillDetectionRuleStore())
            .environmentObject(TrackedSkillStore())
            .environmentObject(ExperienceBuffAlertStore())
            .environmentObject(SkillAutoTriggerCoordinator())
    }
}
