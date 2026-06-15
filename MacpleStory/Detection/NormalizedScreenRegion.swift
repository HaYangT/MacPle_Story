//
//  NormalizedScreenRegion.swift
//  MacpleStory
//
//  Created by Hayangt on 6/12/26.
//

import Foundation

struct NormalizedScreenRegion: Codable, Equatable {
    nonisolated static let fullScreen = NormalizedScreenRegion(
        x: 0,
        y: 0,
        width: 1,
        height: 1
    )

    nonisolated static let quickSlotSearchArea = NormalizedScreenRegion(
        x: 0,
        y: 0,
        width: 1,
        height: 1
    )

    var x: Double
    var y: Double
    var width: Double
    var height: Double
}
