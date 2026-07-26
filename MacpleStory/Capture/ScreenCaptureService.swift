//
//  ScreenCaptureService.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import AppKit
import Foundation
import CoreGraphics
import ScreenCaptureKit

protocol ScreenCaptureProviding {
    var hasScreenCapturePermission: Bool { get }

    @MainActor
    @discardableResult
    func requestScreenCapturePermissionIfNeeded() -> Bool

    @MainActor func requestUserSelectedWindow() async throws -> UserSelectedCaptureSource
    /// 열린 창 목록에서 메이플스토리 창을 찾아 자동으로 캡처 대상으로 선택한다.
    /// 찾지 못하면 `MapleWindowDetectionError.notFound`를 던진다.
    @MainActor func autoDetectMapleWindow() async throws -> UserSelectedCaptureSource
    func captureFrame() async throws -> ScreenCaptureFrame?
}

extension ScreenCaptureProviding {
    /// 기본 구현: 자동 감지를 지원하지 않는 구현(테스트 스텁 등)은 실패로 처리한다.
    func autoDetectMapleWindow() async throws -> UserSelectedCaptureSource {
        throw MapleWindowDetectionError.notFound
    }
}

enum MapleWindowDetectionError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "메이플스토리 창을 찾지 못했습니다. 게임이 실행 중인지 확인하거나 창을 직접 선택해 주세요."
    }
}

final class ScreenCaptureService: ScreenCaptureProviding {
    private let permissionService: ScreenRecordingPermissionProviding
    private var pickerObserver: ContentSharingPickerObserver?
    private var userSelectedFilter: SCContentFilter?

    init(
        permissionService: ScreenRecordingPermissionProviding = ScreenRecordingPermissionService()
    ) {
        self.permissionService = permissionService
    }

    var hasScreenCapturePermission: Bool {
        permissionService.hasPermission
    }

    @MainActor
    @discardableResult
    func requestScreenCapturePermissionIfNeeded() -> Bool {
        permissionService.requestPermissionIfNeeded()
    }

    @MainActor
    func requestUserSelectedWindow() async throws -> UserSelectedCaptureSource {
        guard requestScreenCapturePermissionIfNeeded() else {
            throw ScreenCaptureError.screenRecordingPermissionRequired(
                appPath: Bundle.main.bundlePath
            )
        }

        NSApp.activate(ignoringOtherApps: true)

        return try await withCheckedThrowingContinuation { continuation in
            let picker = SCContentSharingPicker.shared
            var observer: ContentSharingPickerObserver?

            observer = ContentSharingPickerObserver { [weak self] result in
                if let observer {
                    picker.remove(observer)
                }

                self?.pickerObserver = nil

                switch result {
                case .success(let filter):
                    self?.userSelectedFilter = filter
                    continuation.resume(
                        returning: Self.userSelectedCaptureSource(from: filter)
                    )
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            guard let observer else {
                continuation.resume(throwing: ScreenCaptureError.windowPickerUnavailable)
                return
            }

            pickerObserver = observer
            picker.add(observer)
            picker.defaultConfiguration = windowPickerConfiguration
            picker.maximumStreamCount = 1
            picker.isActive = true

            Task { @MainActor in
                await Task.yield()
                picker.present(using: .window)
            }
        }
    }

    @MainActor
    func autoDetectMapleWindow() async throws -> UserSelectedCaptureSource {
        guard requestScreenCapturePermissionIfNeeded() else {
            throw ScreenCaptureError.screenRecordingPermissionRequired(
                appPath: Bundle.main.bundlePath
            )
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let window = Self.bestMapleWindow(in: content.windows) else {
            throw MapleWindowDetectionError.notFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        userSelectedFilter = filter
        return Self.userSelectedCaptureSource(from: filter)
    }

    /// 메이플로 추정되는 창을 찾을 때 쓰는 키워드. 앞쪽일수록 우선순위가 높다.
    /// (Wine으로 실행 시 창 제목/프로세스명이 `MapleStory.exe`로 나오는 경우를 우선 감지)
    private static let mapleWindowKeywords = [
        "maplestory.exe",
        "maplestory",
        "메이플스토리",
        "메이플",
        "maple"
    ]

    private static func bestMapleWindow(in windows: [SCWindow]) -> SCWindow? {
        let ownBundleID = Bundle.main.bundleIdentifier

        let candidates = windows.compactMap { window -> (window: SCWindow, priority: Int, area: CGFloat)? in
            guard window.isOnScreen else {
                return nil
            }

            guard window.frame.width >= 200, window.frame.height >= 200 else {
                return nil
            }

            if let bundleID = window.owningApplication?.bundleIdentifier,
               bundleID == ownBundleID {
                return nil
            }

            let haystacks = [window.title, window.owningApplication?.applicationName]
                .compactMap { $0?.lowercased() }

            guard let priority = mapleWindowKeywords.firstIndex(where: { keyword in
                haystacks.contains { $0.contains(keyword) }
            }) else {
                return nil
            }

            return (window, priority, window.frame.width * window.frame.height)
        }

        // 우선순위가 높은(인덱스가 작은) 창 우선, 같은 우선순위면 가장 큰 창.
        return candidates.min { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }

            return lhs.area > rhs.area
        }?.window
    }

    func captureFrame() async throws -> ScreenCaptureFrame? {
        guard let userSelectedFilter else {
            throw ScreenCaptureError.userSelectedWindowUnavailable
        }

        return try await captureFrame(
            contentFilter: userSelectedFilter,
            configuration: screenshotConfiguration(for: userSelectedFilter)
        )
    }

    private func captureFrame(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> ScreenCaptureFrame {
        let image = try await captureImage(
            contentFilter: contentFilter,
            configuration: configuration
        )

        return ScreenCaptureFrame(
            image: image,
            capturedAt: Date()
        )
    }

    private func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(
                contentFilter: contentFilter,
                configuration: configuration
            ) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenCaptureError.emptyImage)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private var windowPickerConfiguration: SCContentSharingPickerConfiguration {
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow]
        configuration.allowsChangingSelectedContent = true

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            configuration.excludedBundleIDs = [bundleIdentifier]
        }

        return configuration
    }

    private func screenshotConfiguration(for filter: SCContentFilter) -> SCStreamConfiguration {
        let source = Self.userSelectedCaptureSource(from: filter)
        let configuration = SCStreamConfiguration()
        configuration.width = source.pixelWidth
        configuration.height = source.pixelHeight
        configuration.showsCursor = false
        return configuration
    }

    private static func userSelectedCaptureSource(from filter: SCContentFilter) -> UserSelectedCaptureSource {
        let info = SCShareableContent.info(for: filter)
        let title = filter.includedWindows.first.map { window in
            let applicationName = window.owningApplication?.applicationName ?? "선택한 창"

            if let windowTitle = window.title, !windowTitle.isEmpty {
                return "\(applicationName) - \(windowTitle)"
            }

            return applicationName
        } ?? "선택한 창"

        return UserSelectedCaptureSource(
            displayName: title,
            contentRect: info.contentRect,
            pointPixelScale: CGFloat(info.pointPixelScale)
        )
    }
}

private enum ScreenCaptureError: LocalizedError {
    case emptyImage
    case screenRecordingPermissionRequired(appPath: String)
    case userSelectedWindowUnavailable
    case windowPickerCancelled
    case windowPickerFailed(String)
    case windowPickerUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            "화면 캡처 이미지가 비어 있습니다."
        case .screenRecordingPermissionRequired(let appPath):
            "화면 기록 권한이 필요합니다. 권한 허용 후 앱을 재실행해 주세요. 현재 앱: \(appPath)"
        case .userSelectedWindowUnavailable:
            "직접 선택한 창이 없습니다. 창 선택 버튼으로 메이플스토리 창을 선택해 주세요."
        case .windowPickerCancelled:
            "창 선택이 취소되었습니다."
        case .windowPickerFailed(let message):
            "창 선택을 시작하지 못했습니다. \(message)"
        case .windowPickerUnavailable:
            "창 선택기를 준비하지 못했습니다."
        }
    }
}

private final class ContentSharingPickerObserver: NSObject, SCContentSharingPickerObserver {
    private let completion: (Result<SCContentFilter, Error>) -> Void
    private var didComplete = false

    init(completion: @escaping (Result<SCContentFilter, Error>) -> Void) {
        self.completion = completion
    }

    func contentSharingPicker(
        _ picker: SCContentSharingPicker,
        didCancelFor stream: SCStream?
    ) {
        complete(.failure(ScreenCaptureError.windowPickerCancelled))
    }

    func contentSharingPicker(
        _ picker: SCContentSharingPicker,
        didUpdateWith filter: SCContentFilter,
        for stream: SCStream?
    ) {
        complete(.success(filter))
    }

    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        complete(.failure(ScreenCaptureError.windowPickerFailed(error.localizedDescription)))
    }

    private func complete(_ result: Result<SCContentFilter, Error>) {
        guard !didComplete else {
            return
        }

        didComplete = true
        completion(result)
    }
}
