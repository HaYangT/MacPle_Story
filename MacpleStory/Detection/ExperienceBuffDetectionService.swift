//
//  ExperienceBuffDetectionService.swift
//  MacpleStory
//
//  Created by Codex on 6/16/26.
//

import AppKit
import Foundation

struct ExperienceBuffDetectionResult: Equatable {
    var entryID: String
    var isActive: Bool
    var confidence: Double
    var detectedAt: Date
    var iconRegion: NormalizedScreenRegion?
}

protocol ExperienceBuffDetecting {
    func detectExperienceBuffs(
        in frame: ScreenCaptureFrame,
        entries: [ExperienceBuffEntry]
    ) async throws -> [ExperienceBuffDetectionResult]
}

/// OpenCV(cv::matchTemplate, TM_CCOEFF_NORMED) 기반 버프 아이콘 감지.
/// 밝기/대비 변화에 강한 정규화 교차상관으로 전체 화면에서 아이콘 위치와 점수를 구한다.
final class ExperienceBuffDetectionService: ExperienceBuffDetecting {
    private let matchThreshold: Double
    private let searchRegion: NormalizedScreenRegion

    /// 버프는 화면 우상단에 위치한다. 스킬 퀵슬롯(하단/중앙)의 동일 아이콘 오인식을
    /// 막기 위해 우상단 영역만 검색한다.
    init(
        matchThreshold: Double = 0.75,
        searchRegion: NormalizedScreenRegion = NormalizedScreenRegion(
            x: 0.5,
            y: 0,
            width: 0.5,
            height: 0.5
        )
    ) {
        self.matchThreshold = matchThreshold
        self.searchRegion = searchRegion
    }

    func detectExperienceBuffs(
        in frame: ScreenCaptureFrame,
        entries: [ExperienceBuffEntry]
    ) async throws -> [ExperienceBuffDetectionResult] {
        entries.map { entry in
            autoreleasepool {
                detectEntry(entry, in: frame)
            }
        }
    }

    private func detectEntry(
        _ entry: ExperienceBuffEntry,
        in frame: ScreenCaptureFrame
    ) -> ExperienceBuffDetectionResult {
        guard entry.iconTemplate.hasImageData,
              let templateImage = Self.cgImage(from: entry.iconTemplate) else {
            return inactiveResult(for: entry, at: frame.capturedAt)
        }

        let match = OpenCVBuffMatcher.matchTemplate(
            templateImage,
            inFrame: frame.image,
            searchRegion: CGRect(
                x: searchRegion.x,
                y: searchRegion.y,
                width: searchRegion.width,
                height: searchRegion.height
            ),
            threshold: matchThreshold
        )

        guard match.found else {
            return inactiveResult(for: entry, at: frame.capturedAt)
        }

        let region = NormalizedScreenRegion.fromPixelRect(
            match.regionInPixels,
            pixelWidth: frame.image.width,
            pixelHeight: frame.image.height
        )

        return ExperienceBuffDetectionResult(
            entryID: entry.id,
            isActive: true,
            confidence: match.score,
            detectedAt: frame.capturedAt,
            iconRegion: region
        )
    }

    private func inactiveResult(
        for entry: ExperienceBuffEntry,
        at detectedAt: Date
    ) -> ExperienceBuffDetectionResult {
        ExperienceBuffDetectionResult(
            entryID: entry.id,
            isActive: false,
            confidence: 0,
            detectedAt: detectedAt,
            iconRegion: nil
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
