//
//  ScreenRecordingPermissionService.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import CoreGraphics

protocol ScreenRecordingPermissionProviding {
    var hasPermission: Bool { get }

    @discardableResult
    func requestPermission() -> Bool
}

final class ScreenRecordingPermissionService: ScreenRecordingPermissionProviding {
    var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
