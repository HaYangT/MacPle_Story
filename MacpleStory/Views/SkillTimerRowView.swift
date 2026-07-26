//
//  SkillTimerRowView.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import SwiftUI

struct SkillTimerRowView: View {
    @EnvironmentObject private var timerStore: SkillTimerStore

    let skillTimer: SkillTimer

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: skillTimer.isRunning ? "bolt.circle.fill" : "bolt.circle")
                .foregroundStyle(skillTimer.isRunning ? .green : .secondary)
                .frame(width: 20)

            Circle()
                .fill(effectiveAlertColor)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.4)))
                .help(skillTimer.alertColor == nil ? "전역 알림 색상 사용 중" : "이 스킬 전용 알림 색상")

            VStack(alignment: .leading, spacing: 2) {
                Text(skillTimer.name)
                    .font(.headline)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(skillTimer.remainingSeconds.timerText)
                .font(.system(.body, design: .monospaced))
                .contentTransition(.numericText())
                .frame(width: 54, alignment: .trailing)

            HStack(spacing: 4) {
                Menu {
                    Button("색상 설정") {
                        timerStore.beginSkillAlertColorSelection(id: skillTimer.id)
                    }

                    if skillTimer.alertColor != nil {
                        Button("기본 색으로") {
                            timerStore.resetSkillAlertColor(id: skillTimer.id)
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .frame(width: 18, height: 18)
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("알림 색상")

                Button {
                    timerStore.toggleTimer(id: skillTimer.id)
                } label: {
                    Image(systemName: skillTimer.isRunning ? "pause.fill" : "play.fill")
                        .frame(width: 18, height: 18)
                }
                .help(skillTimer.isRunning ? "일시정지" : "시작")

                Button {
                    timerStore.resetTimer(id: skillTimer.id)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 18, height: 18)
                }
                .help("초기화")

                Button(role: .destructive) {
                    timerStore.removeTimer(id: skillTimer.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 18, height: 18)
                }
                .help("삭제")
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var effectiveAlertColor: Color {
        skillTimer.alertColor?.color ?? timerStore.alertAccentColor.color
    }

    private var detailText: String {
        if skillTimer.remainingSeconds == 0 {
            return "사용 가능"
        }

        let preAlertText = skillTimer.preAlertSoundID == nil ? "알림음 없음" : "\(skillTimer.alertBeforeSeconds)초 전 알림"
        return "\(skillTimer.cooldownSeconds.timerText) 쿨타임 · \(preAlertText)"
    }
}

struct SkillTimerRowView_Previews: PreviewProvider {
    static var previews: some View {
        SkillTimerRowView(
            skillTimer: SkillTimer(
                name: "샘플 스킬",
                cooldownSeconds: 90,
                alertBeforeSeconds: 5,
                remainingSeconds: 90
            )
        )
        .environmentObject(SkillTimerStore())
        .padding()
    }
}
