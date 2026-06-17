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
    /// 활성일 때 어떤 변형(2배/3배 등)이 매칭됐는지.
    var matchedVariantName: String?

    init(
        entryID: String,
        isActive: Bool,
        confidence: Double,
        detectedAt: Date,
        iconRegion: NormalizedScreenRegion?,
        matchedVariantName: String? = nil
    ) {
        self.entryID = entryID
        self.isActive = isActive
        self.confidence = confidence
        self.detectedAt = detectedAt
        self.iconRegion = iconRegion
        self.matchedVariantName = matchedVariantName
    }
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
    /// 변형 이름(아이콘 파일명) → 디코딩된 CGImage 캐시. PNG→NSImage→CGImage 재디코딩 방지.
    private var templateImageCache: [String: CGImage] = [:]

    /// 버프는 화면 우상단 버프 바에 위치한다. 스킬 퀵슬롯(하단/중앙) 오인식을 막고
    /// 상관맵 면적을 줄이기 위해 우상단 띠(상단 ~22%)만 검색한다.
    /// 버프는 화면 상단(우측 위주)의 버프 바에 위치하고 여러 줄로 왼쪽·아래로 확장된다.
    /// 하단 스킬 퀵슬롯 오인식은 막으면서 버프 바 전체를 포함하도록 상단 40%를 검색한다.
    init(
        matchThreshold: Double = 0.75,
        searchRegion: NormalizedScreenRegion = NormalizedScreenRegion(
            x: 0,
            y: 0,
            width: 1.0,
            height: 0.4
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
        let searchRect = CGRect(
            x: searchRegion.x,
            y: searchRegion.y,
            width: searchRegion.width,
            height: searchRegion.height
        )

        // 변형 전부를 배치로 한 번에 검사(프레임 Mat 1회 변환 + 템플릿 Mat 캐시).
        let templates = entry.variants.compactMap { variant -> OpenCVBuffTemplate? in
            guard let image = cachedCGImage(for: variant) else {
                return nil
            }
            return OpenCVBuffTemplate(identifier: variant.name, image: image)
        }

        guard !templates.isEmpty else {
            return inactiveResult(for: entry, at: frame.capturedAt)
        }

        let match = OpenCVBuffMatcher.match(
            templates,
            inFrame: frame.image,
            searchRegion: searchRect,
            threshold: matchThreshold
        )

        // 미감지여도 최고 점수를 confidence로 실어 UI에서 근접도를 볼 수 있게 한다.
        let region = match.found
            ? NormalizedScreenRegion.fromPixelRect(
                match.regionInPixels,
                pixelWidth: frame.image.width,
                pixelHeight: frame.image.height
              )
            : nil

        return ExperienceBuffDetectionResult(
            entryID: entry.id,
            isActive: match.found,
            confidence: match.score,
            detectedAt: frame.capturedAt,
            iconRegion: region,
            matchedVariantName: match.found ? match.matchedTemplateId : nil
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

    private func cachedCGImage(for variant: BuffIconVariant) -> CGImage? {
        if let cached = templateImageCache[variant.name] {
            return cached
        }

        guard variant.iconTemplate.hasImageData,
              let image = Self.cgImage(from: variant.iconTemplate) else {
            return nil
        }

        templateImageCache[variant.name] = image
        return image
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
