//
//  SkillAutoTriggerCoordinator.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Combine
import Foundation

@MainActor
final class SkillAutoTriggerCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastDetectedResult: SkillDetectionResult?

    private let screenCaptureService: ScreenCaptureProviding
    private let skillDetectionService: SkillDetectionProviding

    init() {
        self.screenCaptureService = ScreenCaptureService()
        self.skillDetectionService = SkillDetectionService()
    }

    init(
        screenCaptureService: ScreenCaptureProviding,
        skillDetectionService: SkillDetectionProviding
    ) {
        self.screenCaptureService = screenCaptureService
        self.skillDetectionService = skillDetectionService
    }

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
        lastDetectedResult = nil
    }

    func processOnce(using rules: [SkillDetectionRule]) async throws {
        guard isRunning, let frame = try await screenCaptureService.captureFrame() else {
            return
        }

        lastDetectedResult = try await skillDetectionService
            .detectSkills(in: frame, using: rules)
            .first
    }
}
