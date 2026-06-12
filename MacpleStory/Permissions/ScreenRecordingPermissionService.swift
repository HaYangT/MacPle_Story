//
//  ScreenRecordingPermissionService.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import CoreGraphics
import Foundation

protocol ScreenRecordingPermissionProviding {
    var hasPermission: Bool { get }

    @discardableResult
    func requestPermission() -> Bool

    @discardableResult
    func requestPermissionIfNeeded() -> Bool

    @discardableResult
    func requestPermissionOnceIfNeeded() -> Bool
}

final class ScreenRecordingPermissionService: ScreenRecordingPermissionProviding {
    private static let didRequestPermissionDefaultsKey = "screenRecordingPermissionDidRequest"

    var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestPermission() -> Bool {
        UserDefaults.standard.set(true, forKey: Self.didRequestPermissionDefaultsKey)
        return CGRequestScreenCaptureAccess()
    }

    @discardableResult
    func requestPermissionIfNeeded() -> Bool {
        guard !hasPermission else {
            return true
        }

        return requestPermission()
    }

    @discardableResult
    func requestPermissionOnceIfNeeded() -> Bool {
        guard !hasPermission else {
            return true
        }

        guard !UserDefaults.standard.bool(forKey: Self.didRequestPermissionDefaultsKey) else {
            return false
        }

        return requestPermission()
    }
}
