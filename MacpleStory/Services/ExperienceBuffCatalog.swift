//
//  ExperienceBuffCatalog.swift
//  MacpleStory
//
//  앱 번들에 넣어둔 버프 아이콘 PNG들을 프리셋 목록으로 읽어온다.
//  개발자는 MacpleStory/BuffIcons/ 에 PNG를 넣기만 하면 자동으로 메뉴에 등장한다.
//  (파일명이 표시 이름이 된다.)
//

import AppKit
import Foundation

enum ExperienceBuffCatalog {
    static func loadPresets(bundle: Bundle = .main) -> [ExperienceBuffPreset] {
        let urls = bundle.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []

        let presets = urls.compactMap { url -> ExperienceBuffPreset? in
            guard let data = try? Data(contentsOf: url),
                  let image = NSImage(data: data) else {
                return nil
            }

            var proposedRect = CGRect(origin: .zero, size: image.size)
            guard let cgImage = image.cgImage(
                forProposedRect: &proposedRect,
                context: nil,
                hints: nil
            ) else {
                return nil
            }

            let name = url.deletingPathExtension().lastPathComponent
            let template = SkillIconTemplate(
                pngData: data,
                pixelWidth: cgImage.width,
                pixelHeight: cgImage.height
            )

            return ExperienceBuffPreset(
                id: name,
                displayName: name,
                iconTemplate: template
            )
        }

        return presets.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }
}
