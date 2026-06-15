//
//  SkillIconTemplateImporter.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import AppKit
import CoreGraphics
import Foundation

struct SkillIconTemplateImporter {
    func importTemplate(from url: URL) throws -> SkillIconTemplate {
        guard let image = NSImage(contentsOf: url) else {
            throw SkillIconTemplateImportError.unreadableImage
        }

        var proposedRect = CGRect(
            origin: .zero,
            size: image.size
        )

        guard let cgImage = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            throw SkillIconTemplateImportError.unreadableImage
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        guard let pngData = bitmap.representation(
            using: .png,
            properties: [:]
        ) else {
            throw SkillIconTemplateImportError.pngEncodingFailed
        }

        return SkillIconTemplate(
            pngData: pngData,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height
        )
    }
}

enum SkillIconTemplateImportError: LocalizedError {
    case pngEncodingFailed
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .pngEncodingFailed:
            "스킬 아이콘을 PNG로 변환하지 못했습니다."
        case .unreadableImage:
            "스킬 아이콘 이미지를 읽지 못했습니다."
        }
    }
}
