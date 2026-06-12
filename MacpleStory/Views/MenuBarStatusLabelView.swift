//
//  MenuBarStatusLabelView.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import SwiftUI

struct MenuBarStatusLabelView: View {
    let status: MenuBarTimerStatus

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.systemImageName)
                .imageScale(.small)

            Text(status.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .contentTransition(.numericText())
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, status.tone == .idle ? 0 : 7)
        .padding(.vertical, status.tone == .idle ? 0 : 3)
        .frame(maxWidth: 180)
        .background(backgroundColor, in: Capsule())
        .animation(.easeInOut(duration: 0.18), value: status)
    }

    private var foregroundStyle: Color {
        switch status.tone {
        case .idle, .running:
            return .primary
        case .warning:
            return Color(red: 1.0, green: 0.96, blue: 0.72)
        case .ready:
            return Color(red: 0.78, green: 1.0, blue: 0.78)
        }
    }

    private var backgroundColor: Color {
        switch status.tone {
        case .idle:
            Color.clear
        case .running:
            Color.primary.opacity(0.10)
        case .warning:
            Color(red: 0.47, green: 0.36, blue: 0.12).opacity(0.85)
        case .ready:
            Color(red: 0.12, green: 0.38, blue: 0.18).opacity(0.85)
        }
    }
}

struct MenuBarStatusLabelView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 10) {
            MenuBarStatusLabelView(
                status: MenuBarTimerStatus(
                    title: "젠다이브 00:05 남음",
                    systemImageName: "bell.fill",
                    tone: .warning
                )
            )

            MenuBarStatusLabelView(
                status: MenuBarTimerStatus(
                    title: "MacpleStory",
                    systemImageName: "timer",
                    tone: .idle
                )
            )
        }
        .padding()
    }
}
