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

    @State private var skillName = ""
    @State private var cooldownSeconds = 60
    @State private var alertBeforeSeconds = 5
    @State private var preAlertSoundID = ""
    @State private var readyAlertSoundID = ""

    private var canAddSkill: Bool {
        !skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("스킬 추가")
                .font(.headline)

            TextField("스킬 이름", text: $skillName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: $cooldownSeconds, in: 1...600, step: 5) {
                    SettingValueLabel(title: "쿨타임", value: cooldownSeconds.timerText)
                }
                .onChange(of: cooldownSeconds) { _, newValue in
                    alertBeforeSeconds = min(alertBeforeSeconds, newValue)
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

            Button {
                timerStore.addTimer(
                    name: skillName,
                    cooldownSeconds: cooldownSeconds,
                    alertBeforeSeconds: alertBeforeSeconds,
                    preAlertSoundID: preAlertSoundID.isEmpty ? nil : preAlertSoundID,
                    readyAlertSoundID: readyAlertSoundID.isEmpty ? nil : readyAlertSoundID
                )
                skillName = ""
            } label: {
                Label("추가", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAddSkill)
        }
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
            .padding()
    }
}
