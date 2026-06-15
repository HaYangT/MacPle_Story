//
//  SkillInputFormView.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SkillInputFormView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore
    @EnvironmentObject private var ruleStore: SkillDetectionRuleStore
    @EnvironmentObject private var trackedSkillStore: TrackedSkillStore

    @State private var skillName = ""
    @State private var skillLevel = 1
    @State private var cooldownSeconds = 60
    @State private var durationSeconds = 0
    @State private var alertBeforeSeconds = 5
    @State private var preAlertSoundID = ""
    @State private var readyAlertSoundID = ""
    @State private var selectedIconTemplate: SkillIconTemplate?
    @State private var selectedIconImage: NSImage?
    @State private var selectedIconName = ""
    @State private var iconImportErrorMessage: String?

    private var canAddSkill: Bool {
        !skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canRegisterDetectedSkill: Bool {
        canAddSkill && selectedIconTemplate?.hasImageData == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("스킬 추가")
                .font(.headline)

            iconSelectionView

            TextField("스킬 이름", text: $skillName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: $skillLevel, in: 1...30, step: 1) {
                    SettingValueLabel(title: "레벨", value: "\(skillLevel)")
                }

                Stepper(value: $cooldownSeconds, in: 1...600, step: 5) {
                    SettingValueLabel(title: "쿨타임", value: cooldownSeconds.timerText)
                }
                .onChange(of: cooldownSeconds) { _, newValue in
                    alertBeforeSeconds = min(alertBeforeSeconds, newValue)
                }

                Stepper(value: $durationSeconds, in: 0...600, step: 5) {
                    SettingValueLabel(
                        title: "지속시간",
                        value: durationSeconds == 0 ? "없음" : durationSeconds.timerText
                    )
                }

                Stepper(value: $alertBeforeSeconds, in: 0...cooldownSeconds, step: 1) {
                    SettingValueLabel(title: "음성 알림", value: "\(alertBeforeSeconds)초 전")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("알림음")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        timerStore.reloadAlertSounds()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("알림음 목록 새로고침")

                    Button {
                        selectAlertSoundFile()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("알림음 파일 추가")
                }

                if let errorMessage = timerStore.alertSoundImportErrorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if timerStore.alertSounds.isEmpty {
                    Label("wav 또는 mp3 파일을 추가하면 선택할 수 있습니다", systemImage: "speaker.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("사전 알림", selection: $preAlertSoundID) {
                        Text("선택 안 함").tag("")
                        ForEach(timerStore.alertSounds) { alertSound in
                            Text("\(alertSound.displayName) · \(alertSound.formatLabel) · \(alertSound.sourceLabel)")
                                .tag(alertSound.id)
                        }
                    }

                    Picker("완료 알림", selection: $readyAlertSoundID) {
                        Text("선택 안 함").tag("")
                        ForEach(timerStore.alertSounds) { alertSound in
                            Text("\(alertSound.displayName) · \(alertSound.formatLabel) · \(alertSound.sourceLabel)")
                                .tag(alertSound.id)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    addManualTimer()
                } label: {
                    Label("타이머만 추가", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canAddSkill)

                Button {
                    registerDetectedSkill()
                } label: {
                    Label("감지 등록", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRegisterDetectedSkill)
            }
        }
    }

    private var iconSelectionView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)

                if let selectedIconImage {
                    Image(nsImage: selectedIconImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedIconName.isEmpty ? "아이콘 미선택" : selectedIconName)
                    .font(.subheadline)
                    .lineLimit(1)

                if let iconImportErrorMessage {
                    Text(iconImportErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    Text("감지 등록에 사용")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                selectSkillIconFile()
            } label: {
                Image(systemName: "photo.badge.plus")
                    .frame(width: 18, height: 18)
            }
            .help("스킬 아이콘 선택")
        }
    }

    private func addManualTimer() {
        timerStore.addTimer(
            name: skillName,
            cooldownSeconds: cooldownSeconds,
            alertBeforeSeconds: alertBeforeSeconds,
            preAlertSoundID: preAlertSoundID.isEmpty ? nil : preAlertSoundID,
            readyAlertSoundID: readyAlertSoundID.isEmpty ? nil : readyAlertSoundID
        )
        resetSkillInputs(keepingIcon: true)
    }

    private func registerDetectedSkill() {
        guard let selectedIconTemplate else {
            return
        }

        let trimmedName = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let skill = SkillDefinition(
            id: UUID().uuidString,
            displayName: trimmedName,
            iconTemplate: selectedIconTemplate,
            maxLevel: 30,
            cooldownSecondsByLevel: [
                skillLevel: cooldownSeconds
            ],
            durationSecondsByLevel: durationSeconds > 0
                ? [skillLevel: durationSeconds]
                : [:]
        )

        SkillTrackingRegistrationService().register(
            skill: skill,
            level: skillLevel,
            alertBeforeSeconds: alertBeforeSeconds,
            preAlertSoundID: preAlertSoundID.isEmpty ? nil : preAlertSoundID,
            readyAlertSoundID: readyAlertSoundID.isEmpty ? nil : readyAlertSoundID,
            timerStore: timerStore,
            ruleStore: ruleStore,
            trackedSkillStore: trackedSkillStore
        )
        resetSkillInputs(keepingIcon: false)
    }

    private func selectAlertSoundFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = AlertSoundService.supportedFileExtensions.compactMap {
            UTType(filenameExtension: $0)
        }

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        timerStore.importAlertSound(from: selectedURL)
    }

    private func selectSkillIconFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            selectedIconTemplate = try SkillIconTemplateImporter()
                .importTemplate(from: selectedURL)
            selectedIconImage = NSImage(contentsOf: selectedURL)
            selectedIconName = selectedURL.deletingPathExtension().lastPathComponent
            iconImportErrorMessage = nil

            if skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                skillName = selectedIconName
            }
        } catch {
            selectedIconTemplate = nil
            selectedIconImage = nil
            selectedIconName = ""
            iconImportErrorMessage = error.localizedDescription
        }
    }

    private func resetSkillInputs(keepingIcon: Bool) {
        skillName = ""
        skillLevel = 1
        cooldownSeconds = 60
        durationSeconds = 0
        alertBeforeSeconds = 5
        preAlertSoundID = ""
        readyAlertSoundID = ""

        guard !keepingIcon else {
            return
        }

        selectedIconTemplate = nil
        selectedIconImage = nil
        selectedIconName = ""
        iconImportErrorMessage = nil
    }
}

private struct SettingValueLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct SkillInputFormView_Previews: PreviewProvider {
    static var previews: some View {
        SkillInputFormView()
            .environmentObject(SkillTimerStore())
            .environmentObject(SkillDetectionRuleStore())
            .environmentObject(TrackedSkillStore())
            .padding()
    }
}
