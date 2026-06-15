//
//  SkillCooldownStateDetector.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import AppKit
import CoreGraphics
import Foundation

enum SkillSlotVisualState: String, Codable, Equatable {
    case ready
    case cooldown
    case unknown
}

struct SkillCooldownStateDetection: Equatable {
    var state: SkillSlotVisualState
    var confidence: Double
    var slotRegion: NormalizedScreenRegion
}

protocol SkillCooldownStateDetecting {
    func detectState(
        in frame: ScreenCaptureFrame,
        rule: SkillDetectionRule,
        slotRegion: NormalizedScreenRegion
    ) -> SkillCooldownStateDetection
}

final class SkillCooldownStateDetector: SkillCooldownStateDetecting {
    private let sampleSize: Int
    private let readySimilarityThreshold: Double
    private let cooldownConfidenceThreshold: Double
    private let comparisonInsetRatio: Double

    init(
        sampleSize: Int = 24,
        readySimilarityThreshold: Double = 0.65,
        cooldownConfidenceThreshold: Double = 0.35,
        comparisonInsetRatio: Double = 0.18
    ) {
        self.sampleSize = sampleSize
        self.readySimilarityThreshold = readySimilarityThreshold
        self.cooldownConfidenceThreshold = cooldownConfidenceThreshold
        self.comparisonInsetRatio = comparisonInsetRatio
    }

    func detectState(
        in frame: ScreenCaptureFrame,
        rule: SkillDetectionRule,
        slotRegion: NormalizedScreenRegion
    ) -> SkillCooldownStateDetection {
        guard let template = rule.iconTemplate,
              template.hasImageData,
              let templateImage = Self.cgImage(from: template),
              let frameRaster = SkillImageRaster(image: frame.image),
              let templateRaster = SkillImageRaster(image: templateImage),
              let currentSample = frameRaster.sample(
                rect: comparisonRect(
                    in: slotRegion.pixelRect(
                        pixelWidth: frameRaster.width,
                        pixelHeight: frameRaster.height
                    )
                ),
                size: sampleSize
              ),
              let templateSample = templateRaster.sample(
                rect: comparisonRect(
                    in: CGRect(
                    x: 0,
                    y: 0,
                    width: templateRaster.width,
                    height: templateRaster.height
                    )
                ),
                size: sampleSize
              ) else {
            return SkillCooldownStateDetection(
                state: .unknown,
                confidence: 0,
                slotRegion: slotRegion
            )
        }

        let similarity = currentSample.similarity(to: templateSample)
        let differenceScore = 1 - similarity
        let luminanceDrop = max(
            0,
            (templateSample.averageLuminance - currentSample.averageLuminance)
                / max(templateSample.averageLuminance, 0.01)
        )
        let yellowDigitScore = min(
            currentSample.cooldownDigitYellowRatio / 0.025,
            1
        )
        let cooldownConfidence = min(
            1,
            (differenceScore * 0.55)
                + (luminanceDrop * 0.3)
                + (yellowDigitScore * 0.15)
        )

        if similarity >= readySimilarityThreshold,
           luminanceDrop < 0.25 {
            return SkillCooldownStateDetection(
                state: .ready,
                confidence: similarity,
                slotRegion: slotRegion
            )
        }

        let hasCooldownOverlay = luminanceDrop >= 0.18
        let hasCooldownDigits = yellowDigitScore >= 0.25
            && differenceScore >= 0.2

        if cooldownConfidence >= cooldownConfidenceThreshold,
           hasCooldownOverlay || hasCooldownDigits {
            return SkillCooldownStateDetection(
                state: .cooldown,
                confidence: cooldownConfidence,
                slotRegion: slotRegion
            )
        }

        return SkillCooldownStateDetection(
            state: .unknown,
            confidence: max(similarity, cooldownConfidence),
            slotRegion: slotRegion
        )
    }

    private func comparisonRect(in rect: CGRect) -> CGRect {
        rect.insetBy(
            dx: rect.width * comparisonInsetRatio,
            dy: rect.height * comparisonInsetRatio
        )
    }

    private static func cgImage(from template: SkillIconTemplate) -> CGImage? {
        guard let image = NSImage(data: template.pngData) else {
            return nil
        }

        var proposedRect = CGRect(
            origin: .zero,
            size: image.size
        )

        return image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        )
    }
}
