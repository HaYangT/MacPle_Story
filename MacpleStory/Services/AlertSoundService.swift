//
//  AlertSoundService.swift
//  MacpleStory
//
//  Created by Codex on 6/12/26.
//

import AVFoundation
import Foundation

final class AlertSoundService {
    static let supportedFileExtensions: Set<String> = ["wav", "mp3"]

    private var audioPlayer: AVAudioPlayer?

    func availableSounds() -> [AlertSound] {
        (bundledSounds() + userSounds())
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    func importSound(from sourceURL: URL) throws -> AlertSound {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard Self.supportedFileExtensions.contains(fileExtension) else {
            throw AlertSoundImportError.unsupportedFormat
        }

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let alertSoundsDirectory = try userAlertSoundsDirectory()
        let destinationURL = uniqueDestinationURL(
            for: sourceURL.lastPathComponent,
            in: alertSoundsDirectory
        )

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        return AlertSound(
            url: destinationURL,
            rootURL: alertSoundsDirectory,
            source: .user
        )
    }

    func play(_ alertSound: AlertSound) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: alertSound.url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play alert sound: \(error)")
        }
    }

    func playSound(id: AlertSound.ID, from alertSounds: [AlertSound]) {
        guard let alertSound = alertSounds.first(where: { $0.id == id }) else {
            return
        }

        play(alertSound)
    }

    private func bundledSounds() -> [AlertSound] {
        guard let resourceURL = Bundle.main.resourceURL else {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return Self.supportedFileExtensions.contains(fileExtension)
            }
            .map { AlertSound(url: $0, rootURL: resourceURL, source: .bundled) }
    }

    private func userSounds() -> [AlertSound] {
        guard let alertSoundsDirectory = try? userAlertSoundsDirectory() else {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: alertSoundsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return Self.supportedFileExtensions.contains(fileExtension)
            }
            .map { AlertSound(url: $0, rootURL: alertSoundsDirectory, source: .user) }
    }

    private func userAlertSoundsDirectory() throws -> URL {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directoryURL = applicationSupportURL
            .appendingPathComponent("MacpleStory", isDirectory: true)
            .appendingPathComponent("AlertSounds", isDirectory: true)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL
    }

    private func uniqueDestinationURL(for fileName: String, in directoryURL: URL) -> URL {
        let sourceURL = URL(fileURLWithPath: fileName)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension

        var candidateURL = directoryURL.appendingPathComponent(fileName)
        var duplicateIndex = 2

        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL = directoryURL.appendingPathComponent(
                "\(baseName) \(duplicateIndex).\(fileExtension)"
            )
            duplicateIndex += 1
        }

        return candidateURL
    }
}

enum AlertSoundImportError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "wav 또는 mp3 파일만 추가할 수 있습니다."
        }
    }
}
