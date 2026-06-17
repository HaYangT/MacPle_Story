//
//  ExperienceBuffCatalog.swift
//  MacpleStory
//
//  앱 번들의 버프 아이콘 PNG와 명시적 목록(BuffCatalog.json)을 합쳐 프리셋 목록을 만든다.
//
//  - 개발자는 MacpleStory/BuffIcons/ 에 PNG를 넣고,
//    같은 폴더의 BuffCatalog.json 에 묶음을 직접 적는다.
//      [
//        { "name": "경험치 쿠폰", "icons": ["EXP_2", "EXP_3", "EXP_4"] },
//        { "name": "VIP",        "icons": ["VIP"] }
//      ]
//    icons에 여러 개를 넣으면 한 번에 하나만 켜지는 버프(변형)로 묶여,
//    그 중 하나라도 감지되면 활성으로 본다.
//  - 매니페스트가 없으면 각 PNG를 단독 버프로 처리한다(폴백).
//

import AppKit
import Foundation

enum ExperienceBuffCatalog {
    struct ManifestEntry: Decodable, Equatable {
        let name: String
        /// 목록 대표 아이콘 파일명(선택). 생략하면 icons의 첫 번째.
        let icon: String?
        let icons: [String]
        /// 지속시간 옵션(분, 선택). 있으면 시간 기반 알림 버프.
        let durations: [Int]?

        init(name: String, icon: String? = nil, icons: [String], durations: [Int]? = nil) {
            self.name = name
            self.icon = icon
            self.icons = icons
            self.durations = durations
        }
    }

    static func loadPresets(bundle: Bundle = .main) -> [ExperienceBuffPreset] {
        buildPresets(
            manifest: loadManifest(bundle: bundle),
            templatesByStem: loadTemplates(bundle: bundle)
        )
    }

    /// 매니페스트 + 아이콘 템플릿으로 프리셋을 조립한다(순수 함수, 테스트 용이).
    static func buildPresets(
        manifest: [ManifestEntry]?,
        templatesByStem: [String: SkillIconTemplate]
    ) -> [ExperienceBuffPreset] {
        if let manifest, !manifest.isEmpty {
            // 매니페스트 순서를 그대로 따른다.
            return manifest.compactMap { entry in
                let variants = entry.icons.compactMap { stem -> BuffIconVariant? in
                    guard let template = templatesByStem[stem] else {
                        return nil
                    }
                    return BuffIconVariant(name: stem, iconTemplate: template)
                }

                guard !variants.isEmpty else {
                    return nil
                }

                let representative = entry.icon
                    .flatMap { iconName in variants.first { $0.name == iconName } }
                    ?? variants.first

                return ExperienceBuffPreset(
                    id: entry.name,
                    displayName: entry.name,
                    variants: variants,
                    representativeVariant: representative,
                    durationsMinutes: entry.durations ?? []
                )
            }
        }

        // 폴백: 각 PNG를 단독 그룹으로(파일명=이름), 이름순 정렬.
        return templatesByStem.keys
            .sorted { $0.localizedCompare($1) == .orderedAscending }
            .map { stem in
                ExperienceBuffPreset(
                    id: stem,
                    displayName: stem,
                    variants: [BuffIconVariant(name: stem, iconTemplate: templatesByStem[stem]!)]
                )
            }
    }

    private static func loadTemplates(bundle: Bundle) -> [String: SkillIconTemplate] {
        let urls = bundle.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        var templatesByStem: [String: SkillIconTemplate] = [:]

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let image = NSImage(data: data) else {
                continue
            }

            var proposedRect = CGRect(origin: .zero, size: image.size)
            guard let cgImage = image.cgImage(
                forProposedRect: &proposedRect,
                context: nil,
                hints: nil
            ) else {
                continue
            }

            let stem = url.deletingPathExtension().lastPathComponent
            templatesByStem[stem] = SkillIconTemplate(
                pngData: data,
                pixelWidth: cgImage.width,
                pixelHeight: cgImage.height
            )
        }

        return templatesByStem
    }

    private static func loadManifest(bundle: Bundle) -> [ManifestEntry]? {
        guard let url = bundle.url(forResource: "BuffCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ManifestEntry].self, from: data) else {
            return nil
        }

        return entries
    }
}
