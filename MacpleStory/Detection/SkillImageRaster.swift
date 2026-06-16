//
//  SkillImageRaster.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import CoreGraphics
import Foundation

struct SkillImageRaster {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(image: CGImage) {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .none
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )

        self.width = width
        self.height = height
        self.bytes = bytes
    }

    func sample(
        region: NormalizedScreenRegion,
        size: Int
    ) -> SkillImageSample? {
        sample(
            rect: region.pixelRect(
                pixelWidth: width,
                pixelHeight: height
            ),
            size: size
        )
    }

    func sample(
        rect: CGRect,
        size: Int
    ) -> SkillImageSample? {
        let rect = clampedRect(rect)
        guard size > 0, rect.width >= 1, rect.height >= 1 else {
            return nil
        }

        var pixels: [SkillImageSample.Pixel] = []
        pixels.reserveCapacity(size * size)

        for y in 0..<size {
            for x in 0..<size {
                let pixelX = Int(
                    rect.minX + ((Double(x) + 0.5) * rect.width / Double(size))
                )
                let pixelY = Int(
                    rect.minY + ((Double(y) + 0.5) * rect.height / Double(size))
                )
                pixels.append(pixel(atX: pixelX, y: pixelY))
            }
        }

        return SkillImageSample(
            size: size,
            pixels: pixels
        )
    }

    private func pixel(atX x: Int, y: Int) -> SkillImageSample.Pixel {
        let clampedX = min(max(0, x), width - 1)
        let clampedY = min(max(0, y), height - 1)
        let offset = ((clampedY * width) + clampedX) * 4

        return SkillImageSample.Pixel(
            red: Double(bytes[offset]) / 255,
            green: Double(bytes[offset + 1]) / 255,
            blue: Double(bytes[offset + 2]) / 255
        )
    }

    private func clampedRect(_ rect: CGRect) -> CGRect {
        let minX = min(max(0, rect.minX), CGFloat(width))
        let minY = min(max(0, rect.minY), CGFloat(height))
        let maxX = min(max(minX, rect.maxX), CGFloat(width))
        let maxY = min(max(minY, rect.maxY), CGFloat(height))

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

struct SkillImageSample: Equatable {
    struct Pixel: Equatable {
        var red: Double
        var green: Double
        var blue: Double

        var luminance: Double {
            (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }

        var isCooldownDigitYellow: Bool {
            red > 0.55
                && green > 0.45
                && blue < 0.28
                && red >= green
        }

        var saturation: Double {
            max(red, green, blue) - min(red, green, blue)
        }
    }

    var size: Int
    var pixels: [Pixel]

    var averageLuminance: Double {
        guard !pixels.isEmpty else {
            return 0
        }

        return pixels.reduce(0) { partialResult, pixel in
            partialResult + pixel.luminance
        } / Double(pixels.count)
    }

    var cooldownDigitYellowRatio: Double {
        guard !pixels.isEmpty else {
            return 0
        }

        let yellowPixelCount = pixels.filter(\.isCooldownDigitYellow).count
        return Double(yellowPixelCount) / Double(pixels.count)
    }

    var averageSaturation: Double {
        guard !pixels.isEmpty else {
            return 0
        }

        return pixels.reduce(0) { partialResult, pixel in
            partialResult + pixel.saturation
        } / Double(pixels.count)
    }

    func similarity(to other: SkillImageSample) -> Double {
        guard pixels.count == other.pixels.count, !pixels.isEmpty else {
            return 0
        }

        let totalDifference = zip(pixels, other.pixels).reduce(0) { partialResult, pair in
            let redDifference = abs(pair.0.red - pair.1.red)
            let greenDifference = abs(pair.0.green - pair.1.green)
            let blueDifference = abs(pair.0.blue - pair.1.blue)

            return partialResult
                + ((redDifference + greenDifference + blueDifference) / 3)
        }
        let averageDifference = totalDifference / Double(pixels.count)

        return max(0, min(1, 1 - averageDifference))
    }
}

extension NormalizedScreenRegion {
    nonisolated func pixelRect(
        pixelWidth: Int,
        pixelHeight: Int
    ) -> CGRect {
        let normalizedMinX = min(max(0, x), 1)
        let normalizedMinY = min(max(0, y), 1)
        let normalizedMaxX = min(max(normalizedMinX, x + width), 1)
        let normalizedMaxY = min(max(normalizedMinY, y + height), 1)

        let minX = (normalizedMinX * Double(pixelWidth)).rounded(.down)
        let minY = (normalizedMinY * Double(pixelHeight)).rounded(.down)
        let maxX = (normalizedMaxX * Double(pixelWidth)).rounded(.up)
        let maxY = (normalizedMaxY * Double(pixelHeight)).rounded(.up)

        return CGRect(
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY)
        )
    }

    nonisolated static func fromPixelRect(
        _ rect: CGRect,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> NormalizedScreenRegion {
        NormalizedScreenRegion(
            x: Double(rect.minX) / Double(max(pixelWidth, 1)),
            y: Double(rect.minY) / Double(max(pixelHeight, 1)),
            width: Double(rect.width) / Double(max(pixelWidth, 1)),
            height: Double(rect.height) / Double(max(pixelHeight, 1))
        )
    }
}
