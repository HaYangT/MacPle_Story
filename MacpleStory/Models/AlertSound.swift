//
//  AlertSound.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import Foundation

struct AlertSound: Identifiable, Hashable {
    enum Source: String {
        case bundled
        case user
    }

    let id: String
    let displayName: String
    let fileExtension: String
    let source: Source
    let url: URL

    var formatLabel: String {
        fileExtension.uppercased()
    }

    var sourceLabel: String {
        switch source {
        case .bundled:
            return "기본"
        case .user:
            return "사용자"
        }
    }

    init(url: URL, rootURL: URL, source: Source) {
        let relativePath = url.path.replacingOccurrences(
            of: rootURL.path + "/",
            with: ""
        )
        let fileExtension = url.pathExtension.lowercased()
        let baseName = url.deletingPathExtension().lastPathComponent

        self.id = "\(source.rawValue):\(relativePath)"
        self.displayName = baseName
        self.fileExtension = fileExtension
        self.source = source
        self.url = url
    }
}
