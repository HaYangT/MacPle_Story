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

/// OpenCV(cv::matchTemplate) 기반 버프 아이콘 감지.
/// 불투명 템플릿은 TM_CCOEFF_NORMED, 알파 마스크 템플릿은 TM_SQDIFF_NORMED로
/// 버프 바 안에서 아이콘 위치와 점수를 구한다.
final class ExperienceBuffDetectionService: ExperienceBuffDetecting {
    private let matchThreshold: Double
    private let searchRegion: NormalizedScreenRegion
    private var lastMatchedRegionByEntryID: [String: NormalizedScreenRegion] = [:]
    /// 변형 이름(아이콘 파일명) → 디코딩된 CGImage 캐시. PNG→NSImage→CGImage 재디코딩 방지.
    private var templateImageCache: [String: CGImage] = [:]

    /// 버프 바는 우상단에서 왼쪽으로 쌓이므로, 우측을 넉넉히(폭 70%) 상단 띠(높이 30%)로
    /// 검색한다. 직전 매칭 위치 주변을 먼저 좁게 보는 추적 ROI로 비용을 줄인다.
    /// 하단 퀵슬롯은 제외.
    init(
        matchThreshold: Double = 0.75,
        searchRegion: NormalizedScreenRegion = NormalizedScreenRegion(
            x: 0.3,
            y: 0,
            width: 0.7,
            height: 0.3
        )
    ) {
        self.matchThreshold = matchThreshold
        self.searchRegion = searchRegion
    }

    func detectExperienceBuffs(
        in frame: ScreenCaptureFrame,
        entries: [ExperienceBuffEntry]
    ) async throws -> [ExperienceBuffDetectionResult] {
        let requests = entries.map { entry in
            makeDetectionRequest(for: entry, in: frame)
        }

        guard !requests.isEmpty else {
            return []
        }

        let frameImage = frame.image
        let matchThreshold = matchThreshold
        let capturedAt = frame.capturedAt
        let framePixelWidth = frame.image.width
        let framePixelHeight = frame.image.height

        let matches = await Task.detached(priority: .utility) {
            requests.map { request in
                autoreleasepool {
                    Self.matchRequest(
                        request,
                        in: frameImage,
                        threshold: matchThreshold
                    )
                }
            }
        }.value

        return matches.map { match in
            result(
                from: match,
                capturedAt: capturedAt,
                framePixelWidth: framePixelWidth,
                framePixelHeight: framePixelHeight
            )
        }
    }

    nonisolated private struct DetectionRequest {
        let entry: ExperienceBuffEntry
        let templates: [OpenCVBuffTemplate]
        let primarySearchRect: CGRect
        let fallbackSearchRect: CGRect?
    }

    nonisolated private struct DetectionMatch {
        let request: DetectionRequest
        let match: OpenCVBuffMatchResult?
    }

    private func makeDetectionRequest(
        for entry: ExperienceBuffEntry,
        in frame: ScreenCaptureFrame
    ) -> DetectionRequest {
        // 변형 전부를 배치로 한 번에 검사(프레임 Mat 1회 변환 + 템플릿 Mat 캐시).
        let templates = entry.variants.compactMap { variant -> OpenCVBuffTemplate? in
            guard let image = cachedCGImage(for: variant) else {
                return nil
            }
            return OpenCVBuffTemplate(identifier: variant.name, image: image)
        }

        let searchRegions = searchRegions(
            for: entry,
            framePixelWidth: frame.image.width,
            framePixelHeight: frame.image.height
        )

        return DetectionRequest(
            entry: entry,
            templates: templates,
            primarySearchRect: Self.cgRect(from: searchRegions.primary),
            fallbackSearchRect: searchRegions.fallback.map { Self.cgRect(from: $0) }
        )
    }

    nonisolated private static func matchRequest(
        _ request: DetectionRequest,
        in frameImage: CGImage,
        threshold: Double
    ) -> DetectionMatch {
        guard !request.templates.isEmpty else {
            return DetectionMatch(request: request, match: nil)
        }

        let primaryMatch = OpenCVBuffMatcher.match(
            request.templates,
            inFrame: frameImage,
            searchRegion: request.primarySearchRect,
            threshold: threshold
        )

        guard !primaryMatch.found,
              let fallbackSearchRect = request.fallbackSearchRect else {
            return DetectionMatch(request: request, match: primaryMatch)
        }

        let fallbackMatch = OpenCVBuffMatcher.match(
            request.templates,
            inFrame: frameImage,
            searchRegion: fallbackSearchRect,
            threshold: threshold
        )

        if fallbackMatch.found || fallbackMatch.score >= primaryMatch.score {
            return DetectionMatch(request: request, match: fallbackMatch)
        }

        return DetectionMatch(request: request, match: primaryMatch)
    }

    private func result(
        from detectionMatch: DetectionMatch,
        capturedAt: Date,
        framePixelWidth: Int,
        framePixelHeight: Int
    ) -> ExperienceBuffDetectionResult {
        guard let match = detectionMatch.match else {
            lastMatchedRegionByEntryID[detectionMatch.request.entry.id] = nil
            return inactiveResult(for: detectionMatch.request.entry, at: capturedAt)
        }

        let region = match.found
            ? NormalizedScreenRegion.fromPixelRect(
                match.regionInPixels,
                pixelWidth: framePixelWidth,
                pixelHeight: framePixelHeight
              )
            : nil

        if let region {
            lastMatchedRegionByEntryID[detectionMatch.request.entry.id] = region
        } else {
            lastMatchedRegionByEntryID[detectionMatch.request.entry.id] = nil
        }

        return ExperienceBuffDetectionResult(
            entryID: detectionMatch.request.entry.id,
            isActive: match.found,
            confidence: match.score,
            detectedAt: capturedAt,
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

    private func searchRegions(
        for entry: ExperienceBuffEntry,
        framePixelWidth: Int,
        framePixelHeight: Int
    ) -> (primary: NormalizedScreenRegion, fallback: NormalizedScreenRegion?) {
        guard let previousRegion = lastMatchedRegionByEntryID[entry.id] else {
            return (searchRegion, nil)
        }

        let trackingRegion = Self.trackingSearchRegion(
            around: previousRegion,
            constrainedTo: searchRegion,
            framePixelWidth: framePixelWidth,
            framePixelHeight: framePixelHeight
        )

        guard trackingRegion != searchRegion else {
            return (searchRegion, nil)
        }

        return (trackingRegion, searchRegion)
    }

    private static func trackingSearchRegion(
        around region: NormalizedScreenRegion,
        constrainedTo baseRegion: NormalizedScreenRegion,
        framePixelWidth: Int,
        framePixelHeight: Int
    ) -> NormalizedScreenRegion {
        let baseRect = baseRegion.pixelRect(
            pixelWidth: framePixelWidth,
            pixelHeight: framePixelHeight
        )
        let matchedRect = region.pixelRect(
            pixelWidth: framePixelWidth,
            pixelHeight: framePixelHeight
        )
        let margin = max(max(matchedRect.width, matchedRect.height) * 2, 48)
        let expandedRect = matchedRect
            .insetBy(dx: -margin, dy: -margin)
            .intersection(baseRect)

        guard !expandedRect.isNull, !expandedRect.isEmpty else {
            return baseRegion
        }

        return .fromPixelRect(
            expandedRect.integral,
            pixelWidth: framePixelWidth,
            pixelHeight: framePixelHeight
        )
    }

    private static func cgRect(from region: NormalizedScreenRegion) -> CGRect {
        CGRect(
            x: region.x,
            y: region.y,
            width: region.width,
            height: region.height
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
