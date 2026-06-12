//
//  SkillDetectionService.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Foundation

protocol SkillDetectionProviding {
    func detectSkills(
        in frame: ScreenCaptureFrame,
        using rules: [SkillDetectionRule]
    ) async throws -> [SkillDetectionResult]
}

final class SkillDetectionService: SkillDetectionProviding {
    func detectSkills(
        in frame: ScreenCaptureFrame,
        using rules: [SkillDetectionRule]
    ) async throws -> [SkillDetectionResult] {
        []
    }
}
