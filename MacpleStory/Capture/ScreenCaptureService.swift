//
//  ScreenCaptureService.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import Foundation

protocol ScreenCaptureProviding {
    func captureFrame() async throws -> ScreenCaptureFrame?
}

final class ScreenCaptureService: ScreenCaptureProviding {
    func captureFrame() async throws -> ScreenCaptureFrame? {
        nil
    }
}
