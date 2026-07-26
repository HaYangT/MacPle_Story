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
    @State private var isShowingSettings = false

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

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help("설정")
            .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                SettingsView()
                    .environmentObject(timerStore)
                    .environmentObject(autoTriggerCoordinator)
            }
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
    }
}

// MARK: - 버프 감지 탭

private struct BuffAlertTabView: View {
    var body: some View {
        AutoTriggerControlView()

        Divider()

        ExperienceBuffAlertSettingsView()
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

            Text(captureSourceText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var captureSourceText: String {
        guard let source = autoTriggerCoordinator.userSelectedCaptureSource else {
            return "캡처 창 미선택 · 설정에서 선택"
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
}

// MARK: - 경험치 버프 알림 설정

private struct ExperienceBuffAlertSettingsView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore
    @EnvironmentObject private var experienceBuffStore: ExperienceBuffAlertStore
    @EnvironmentObject private var autoTriggerCoordinator: SkillAutoTriggerCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { experienceBuffStore.settings.isEnabled },
                set: { experienceBuffStore.updateEnabled($0) }
            )) {
                Label("경험치 버프 알림", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
            }

            if let message = autoTriggerCoordinator.lastExperienceBuffAlertMessage,
               experienceBuffStore.settings.isEnabled,
               !experienceBuffStore.activeEntries.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if experienceBuffStore.presets.isEmpty {
                Text("선택 가능한 버프 아이콘이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("추적할 버프를 선택하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(experienceBuffStore.presets) { preset in
                    ExperienceBuffPresetRow(
                        preset: preset,
                        preference: experienceBuffStore.preference(for: preset.id),
                        alertSounds: timerStore.alertSounds,
                        detectionResult: autoTriggerCoordinator.lastExperienceBuffDetectionResults
                            .first(where: { $0.entryID == preset.id }),
                        captureSource: autoTriggerCoordinator.userSelectedCaptureSource,
                        expiresAt: autoTriggerCoordinator.buffExpiryByEntryID[preset.id]
                    )
                }
            }
        }
    }
}

private struct ExperienceBuffPresetRow: View {
    @EnvironmentObject private var experienceBuffStore: ExperienceBuffAlertStore

    let preset: ExperienceBuffPreset
    let preference: PresetPreference
    let alertSounds: [AlertSound]
    let detectionResult: ExperienceBuffDetectionResult?
    let captureSource: UserSelectedCaptureSource?
    let expiresAt: Date?

    private var selectedAlertSoundID: Binding<String> {
        Binding(
            get: { preference.alertSoundID ?? "" },
            set: { experienceBuffStore.setAlertSound(presetID: preset.id, alertSoundID: $0.isEmpty ? nil : $0) }
        )
    }

    private var selectedDuration: Binding<Int> {
        Binding(
            get: {
                experienceBuffStore.selectedDurationMinutes(for: preset)
                    ?? preset.durationsMinutes.first
                    ?? 0
            },
            set: { experienceBuffStore.setDuration(presetID: preset.id, minutes: $0) }
        )
    }

    private func detectionStatusText(_ result: ExperienceBuffDetectionResult) -> String {
        let percent = Int(result.confidence * 100)

        guard result.isActive else {
            return "미감지 · 최고 \(percent)%"
        }

        if let variant = result.matchedVariantName, variant != preset.displayName {
            return "감지 중 · \(variant) · \(percent)%"
        }
        return "감지 중 · \(percent)%"
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

                    if let pngData = preset.representativeVariant?.iconTemplate.pngData,
                       let image = NSImage(data: pngData) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(3)
                    }
                }
                .frame(width: 36, height: 36)
                .overlay(alignment: .bottomTrailing) {
                    if detectionResult?.isActive == true {
                        Circle()
                            .fill(.green)
                            .frame(width: 9, height: 9)
                            .offset(x: 2, y: 2)
                    }
                }
                .opacity(preference.isTracked ? 1 : 0.4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .opacity(preference.isTracked ? 1 : 0.5)

                    if preference.isTracked {
                        if let expiresAt {
                            // 타이머 진행 중 — 이 동안은 매칭을 멈춘다.
                            BuffCountdownView(expiresAt: expiresAt)
                            Text("감지 일시중지")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if let result = detectionResult {
                            Text(detectionStatusText(result))
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
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { preference.isTracked },
                    set: { experienceBuffStore.setTracked(presetID: preset.id, isTracked: $0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .help(preference.isTracked ? "추적 켜짐 (끄려면 클릭)" : "추적 꺼짐 (켜려면 클릭)")
            }

            if preference.isTracked, preset.isFixedDuration {
                Picker("지속시간", selection: selectedDuration) {
                    ForEach(preset.durationsMinutes, id: \.self) { minutes in
                        Text("\(minutes)분").tag(minutes)
                    }
                }
                .font(.caption)
                .help("이 시간 − 15초에 만료 알림")
            }

            if preference.isTracked, !alertSounds.isEmpty {
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

/// 시간 기반 버프의 남은 시간을 매초 갱신해 보여준다.
private struct BuffCountdownView: View {
    let expiresAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(expiresAt.timeIntervalSince(context.date).rounded()))

            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                Text(remaining > 0 ? "남은 시간 \(remaining.timerText)" : "만료됨")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(remaining > 0 ? Color.orange : .secondary)
        }
    }
}

// MARK: - 설정 (톱니바퀴)

private struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("설정")
                    .font(.title3.bold())

                CaptureSourceSettingsView()

                Divider()

                AlertSettingsView()
            }
            .padding(16)
        }
        .frame(width: 360, height: 460)
    }
}

// MARK: - 창 감지 설정

private struct CaptureSourceSettingsView: View {
    @EnvironmentObject private var autoTriggerCoordinator: SkillAutoTriggerCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("창 감지")
                .font(.headline)

            Text(captureSourceText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    autoDetectWindow()
                } label: {
                    Label("자동 감지", systemImage: "sparkles.tv")
                }
                .buttonStyle(.bordered)
                .disabled(autoTriggerCoordinator.isPresentingCapturePicker)
                .help("열린 창에서 메이플스토리 창을 자동으로 찾습니다")

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
            return "캡처 창 미선택 · 자동 감지 또는 창 선택을 누르세요"
        }
        return "\(source.displayName) · \(source.sizeText)"
    }

    private func autoDetectWindow() {
        Task {
            await autoTriggerCoordinator.autoDetectMapleWindow()
        }
    }

    private func selectWindow() {
        Task {
            await autoTriggerCoordinator.requestUserSelectedWindow()
        }
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("알림 표시 화면")
                        .font(.headline)

                    Text("메이플과 다른 모니터(예: 넷플릭스 화면)를 고르면 그곳에 알림이 뜹니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker(
                    "알림 표시 화면",
                    selection: Binding(
                        get: { timerStore.alertTargetDisplayID },
                        set: { timerStore.updateAlertTargetDisplay($0) }
                    )
                ) {
                    ForEach(timerStore.availableAlertDisplays) { display in
                        Text(display.name).tag(display.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("알림 방식")
                    .font(.headline)

                Picker("알림 방식", selection: Binding(
                    get: { timerStore.alertPresentationStyle },
                    set: { newValue in
                        // 세그먼트 Picker가 뷰 업데이트 도중 set을 호출할 수 있어,
                        // @Published 변경을 다음 런루프로 미뤄 "Publishing changes from
                        // within view updates" 경고를 피한다.
                        DispatchQueue.main.async {
                            timerStore.updateAlertPresentationStyle(newValue)
                        }
                    }
                )) {
                    ForEach(AlertPresentationStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("알림창은 팝업 박스, 점등형은 화면 테두리 깜빡임입니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("알림 색상")
                        .font(.headline)

                    Text("팝업 박스 배경과 테두리 점등에 함께 적용됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                RoundedRectangle(cornerRadius: 6)
                    .fill(timerStore.alertAccentColor.color)
                    .frame(width: 28, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.4))
                    )

                Button {
                    timerStore.beginAlertAccentColorSelection()
                } label: {
                    Label("색상 설정", systemImage: "paintpalette")
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
