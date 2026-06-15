//
//  SkillIconLocator.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import AppKit
import CoreGraphics
import Foundation

struct SkillIconLocation: Equatable {
    var region: NormalizedScreenRegion
    var confidence: Double
}

protocol SkillIconLocating {
    func locateIcon(
        matching template: SkillIconTemplate,
        in frame: ScreenCaptureFrame,
        searchRegion: NormalizedScreenRegion
    ) -> SkillIconLocation?
}

final class SkillIconLocator: SkillIconLocating {
    private let sampleSize: Int
    private let minimumConfidence: Double
    private let scaleCandidates: [Double]
    private let maximumCandidateEvaluations: Int
    private let comparisonInsetRatio: Double

    init(
        sampleSize: Int = 8,
        minimumConfidence: Double = 0.62,
        scaleCandidates: [Double] = [1.0, 2.0, 1.5, 1.25, 0.75],
        maximumCandidateEvaluations: Int = 25_000,
        comparisonInsetRatio: Double = 0.18
    ) {
        self.sampleSize = sampleSize
        self.minimumConfidence = minimumConfidence
        self.scaleCandidates = scaleCandidates
        self.maximumCandidateEvaluations = maximumCandidateEvaluations
        self.comparisonInsetRatio = comparisonInsetRatio
    }

    func locateIcon(
        matching template: SkillIconTemplate,
        in frame: ScreenCaptureFrame,
        searchRegion: NormalizedScreenRegion
    ) -> SkillIconLocation? {
        guard template.hasImageData,
              let templateImage = Self.cgImage(from: template),
              let frameRaster = SkillImageRaster(image: frame.image),
              let templateRaster = SkillImageRaster(image: templateImage),
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
            return nil
        }

        let searchRect = searchRegion.pixelRect(
            pixelWidth: frameRaster.width,
            pixelHeight: frameRaster.height
        )

        guard let coarseMatch = bestMatch(
            frameRaster: frameRaster,
            template: template,
            templateSample: templateSample,
            searchRect: searchRect
        ) else {
            return nil
        }

        let refinedMatch = refine(
            coarseMatch,
            frameRaster: frameRaster,
            templateSample: templateSample,
            searchRect: searchRect
        )

        guard refinedMatch.confidence >= minimumConfidence else {
            return nil
        }

        return SkillIconLocation(
            region: .fromPixelRect(
                refinedMatch.rect,
                pixelWidth: frameRaster.width,
                pixelHeight: frameRaster.height
            ),
            confidence: refinedMatch.confidence
        )
    }

    private struct Match {
        var rect: CGRect
        var confidence: Double
        var coarseStep: Int
    }

    private func bestMatch(
        frameRaster: SkillImageRaster,
        template: SkillIconTemplate,
        templateSample: SkillImageSample,
        searchRect: CGRect
    ) -> Match? {
        var bestMatch: Match?
        var evaluatedCandidateCount = 0
        let aspectRatio = Double(max(template.pixelWidth, 1)) / Double(max(template.pixelHeight, 1))

        for candidateWidth in candidateWidths(
            templateWidth: template.pixelWidth,
            searchWidth: Int(searchRect.width)
        ) {
            let candidateHeight = max(
                1,
                Int((Double(candidateWidth) / aspectRatio).rounded())
            )

            guard candidateWidth <= Int(searchRect.width),
                  candidateHeight <= Int(searchRect.height) else {
                continue
            }

            let coarseStep = max(4, min(candidateWidth, candidateHeight) / 2)
            let maxX = Int(searchRect.maxX) - candidateWidth
            let maxY = Int(searchRect.maxY) - candidateHeight

            guard maxX >= Int(searchRect.minX),
                  maxY >= Int(searchRect.minY) else {
                continue
            }

            for y in prioritizedPositions(
                minimum: Int(searchRect.minY),
                maximum: maxY,
                step: coarseStep
            ) {
                for x in stride(
                    from: Int(searchRect.minX),
                    through: maxX,
                    by: coarseStep
                ) {
                    guard evaluatedCandidateCount < maximumCandidateEvaluations else {
                        return bestMatch
                    }

                    let rect = CGRect(
                        x: x,
                        y: y,
                        width: candidateWidth,
                        height: candidateHeight
                    )
                    guard let sample = frameRaster.sample(
                        rect: comparisonRect(in: rect),
                        size: sampleSize
                    ) else {
                        continue
                    }

                    evaluatedCandidateCount += 1
                    let confidence = sample.similarity(to: templateSample)

                    if bestMatch == nil || confidence > (bestMatch?.confidence ?? 0) {
                        bestMatch = Match(
                            rect: rect,
                            confidence: confidence,
                            coarseStep: coarseStep
                        )
                    }
                }
            }
        }

        return bestMatch
    }

    private func refine(
        _ match: Match,
        frameRaster: SkillImageRaster,
        templateSample: SkillImageSample,
        searchRect: CGRect
    ) -> Match {
        var bestMatch = match
        let radius = max(1, match.coarseStep)
        let minX = max(Int(searchRect.minX), Int(match.rect.minX) - radius)
        let minY = max(Int(searchRect.minY), Int(match.rect.minY) - radius)
        let maxX = min(
            Int(searchRect.maxX - match.rect.width),
            Int(match.rect.minX) + radius
        )
        let maxY = min(
            Int(searchRect.maxY - match.rect.height),
            Int(match.rect.minY) + radius
        )

        guard minX <= maxX, minY <= maxY else {
            return bestMatch
        }

        for y in minY...maxY {
            for x in minX...maxX {
                let rect = CGRect(
                    x: CGFloat(x),
                    y: CGFloat(y),
                    width: match.rect.width,
                    height: match.rect.height
                )
                guard let sample = frameRaster.sample(
                    rect: comparisonRect(in: rect),
                    size: sampleSize
                ) else {
                    continue
                }

                let confidence = sample.similarity(to: templateSample)

                if confidence > bestMatch.confidence {
                    bestMatch = Match(
                        rect: rect,
                        confidence: confidence,
                        coarseStep: match.coarseStep
                    )
                }
            }
        }

        return bestMatch
    }

    private func candidateWidths(
        templateWidth: Int,
        searchWidth: Int
    ) -> [Int] {
        var seenWidths = Set<Int>()

        return scaleCandidates.compactMap { scale in
            let width = Int((Double(templateWidth) * scale).rounded())

            guard width >= 12,
                  width <= searchWidth,
                  !seenWidths.contains(width) else {
                return nil
            }

            seenWidths.insert(width)
            return width
        }
    }

    private func comparisonRect(in rect: CGRect) -> CGRect {
        rect.insetBy(
            dx: rect.width * comparisonInsetRatio,
            dy: rect.height * comparisonInsetRatio
        )
    }

    private func prioritizedPositions(
        minimum: Int,
        maximum: Int,
        step: Int
    ) -> [Int] {
        guard minimum <= maximum else {
            return []
        }

        var positions: [Int] = []
        var seenPositions = Set<Int>()
        var low = minimum
        var high = maximum

        while low <= high {
            if !seenPositions.contains(high) {
                positions.append(high)
                seenPositions.insert(high)
            }

            if !seenPositions.contains(low) {
                positions.append(low)
                seenPositions.insert(low)
            }

            low += step
            high -= step
        }

        return positions
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
