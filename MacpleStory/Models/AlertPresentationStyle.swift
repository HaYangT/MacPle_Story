//
//  AlertPresentationStyle.swift
//  MacpleStory
//
//  Created by Hayangt on 6/22/26.
//

import Foundation

/// 알림을 어떤 형태로 표시할지: 팝업 알림창 / 화면 테두리 점등 / 둘 다.
enum AlertPresentationStyle: String, Codable, CaseIterable, Identifiable {
    case popup
    case borderGlow
    case both

    static let defaultValue: AlertPresentationStyle = .both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .popup: "알림창"
        case .borderGlow: "점등형"
        case .both: "둘 다"
        }
    }

    var showsPopup: Bool {
        self == .popup || self == .both
    }

    var showsBorderGlow: Bool {
        self == .borderGlow || self == .both
    }
}
