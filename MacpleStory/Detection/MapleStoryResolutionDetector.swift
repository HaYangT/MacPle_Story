//
//  MapleStoryResolutionDetector.swift
//  MacpleStory
//
//  Created by Codex on 6/13/26.
//

import CoreGraphics
import Foundation

protocol MapleStoryResolutionDetecting {
    func detectResolution(in frame: ScreenCaptureFrame) -> MapleStoryResolutionDetectionResult?
    func detectResolution(pixelWidth: Int, pixelHeight: Int) -> MapleStoryResolutionDetectionResult?
}

final class MapleStoryResolutionDetector: MapleStoryResolutionDetecting {
    private struct Candidate {
        let result: MapleStoryResolutionDetectionResult
        let totalPixelDelta: Int
    }

    private let pixelTolerance: Int
    private let scaleCandidates: [Double]

    init(
        pixelTolerance: Int = 2,
        scaleCandidates: [Double] = [1.0, 1.25, 1.5, 2.0, 3.0]
    ) {
        self.pixelTolerance = pixelTolerance
        self.scaleCandidates = scaleCandidates
    }

    func detectResolution(in frame: ScreenCaptureFrame) -> MapleStoryResolutionDetectionResult? {
        detectResolution(
            pixelWidth: frame.image.width,
            pixelHeight: frame.image.height
        )
    }

    func detectResolution(pixelWidth: Int, pixelHeight: Int) -> MapleStoryResolutionDetectionResult? {
        guard pixelWidth > 0, pixelHeight > 0 else {
            return nil
        }

        return MapleStoryResolution.allCases
            .flatMap { resolution in
                candidates(
                    for: resolution,
                    pixelWidth: pixelWidth,
                    pixelHeight: pixelHeight
                )
            }
            .min { lhs, rhs in
                if lhs.totalPixelDelta == rhs.totalPixelDelta {
                    return lhs.result.scale < rhs.result.scale
                }

                return lhs.totalPixelDelta < rhs.totalPixelDelta
            }?
            .result
    }

    private func candidates(
        for resolution: MapleStoryResolution,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> [Candidate] {
        scaleCandidates.compactMap { scale in
            let expectedWidth = Int((Double(resolution.width) * scale).rounded())
            let expectedHeight = Int((Double(resolution.height) * scale).rounded())
            let widthDelta = abs(pixelWidth - expectedWidth)
            let heightDelta = abs(pixelHeight - expectedHeight)

            guard widthDelta <= pixelTolerance, heightDelta <= pixelTolerance else {
                return nil
            }

            let totalPixelDelta = widthDelta + heightDelta
            let confidence = confidence(
                totalPixelDelta: totalPixelDelta,
                expectedWidth: expectedWidth,
                expectedHeight: expectedHeight
            )

            return Candidate(
                result: MapleStoryResolutionDetectionResult(
                    resolution: resolution,
                    observedPixelSize: CGSize(
                        width: CGFloat(pixelWidth),
                        height: CGFloat(pixelHeight)
                    ),
                    scale: scale,
                    confidence: confidence
                ),
                totalPixelDelta: totalPixelDelta
            )
        }
    }

    private func confidence(
        totalPixelDelta: Int,
        expectedWidth: Int,
        expectedHeight: Int
    ) -> Double {
        let expectedPixelSpan = max(expectedWidth + expectedHeight, 1)
        let normalizedDelta = Double(totalPixelDelta) / Double(expectedPixelSpan)

        return max(0, 1 - normalizedDelta)
    }
}

