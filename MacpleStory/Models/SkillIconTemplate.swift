//
//  SkillIconTemplate.swift
//  MacpleStory
//
//  Created by Codex on 6/15/26.
//

import Foundation

struct SkillIconTemplate: Codable, Equatable {
    var pngData: Data
    var pixelWidth: Int
    var pixelHeight: Int

    init(
        pngData: Data = Data(),
        pixelWidth: Int = 0,
        pixelHeight: Int = 0
    ) {
        self.pngData = pngData
        self.pixelWidth = max(0, pixelWidth)
        self.pixelHeight = max(0, pixelHeight)
    }

    var hasImageData: Bool {
        !pngData.isEmpty && pixelWidth > 0 && pixelHeight > 0
    }
}
