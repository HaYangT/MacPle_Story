//
//  AlertTargetDisplay.swift
//  MacpleStory
//
//  Created by Hayangt on 6/22/26.
//

import AppKit
import CoreGraphics

/// 알림 팝업을 띄울 대상 디스플레이. `id == 0`이면 주 화면(자동)을 의미한다.
struct AlertTargetDisplay: Identifiable, Equatable {
    /// 주 화면(자동)을 나타내는 센티넬 값.
    static let mainDisplayID: CGDirectDisplayID = 0

    let id: CGDirectDisplayID
    let name: String

    /// 메뉴/피커 맨 위에 표시할 "주 화면(자동)" 옵션.
    static let mainDisplayOption = AlertTargetDisplay(
        id: mainDisplayID,
        name: "주 화면(자동)"
    )

    /// 현재 연결된 디스플레이 목록(주 화면 자동 옵션 포함).
    static func availableDisplays() -> [AlertTargetDisplay] {
        let screens = NSScreen.screens.enumerated().map { index, screen in
            AlertTargetDisplay(
                id: screen.displayID,
                name: screen.localizedName.isEmpty ? "디스플레이 \(index + 1)" : screen.localizedName
            )
        }

        return [mainDisplayOption] + screens
    }
}

extension NSScreen {
    /// `CGDirectDisplayID`. 식별에 실패하면 0을 반환한다.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value ?? AlertTargetDisplay.mainDisplayID
    }
}
