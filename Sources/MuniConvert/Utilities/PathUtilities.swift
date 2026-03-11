// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct TargetResolution {
    let targetURL: URL?
    let skippedBecauseExists: Bool
}

enum PathUtilities {
    static func isTemporaryOrHiddenFile(named fileName: String, ignoreHiddenFiles: Bool) -> Bool {
        if fileName.hasPrefix("~$") {
            return true
        }

        if fileName == ".DS_Store" {
            return true
        }

        if fileName.hasPrefix(".~lock.") {
            return true
        }

        if fileName.hasSuffix("#") && fileName.contains("lock") {
            return true
        }

        if ignoreHiddenFiles && fileName.hasPrefix(".") {
            return true
        }

        return false
    }

    static func targetDirectory(for sourceFile: URL, options: ConversionOptions) throws -> URL {
        if !options.useSeparateOutputFolder {
            return sourceFile.deletingLastPathComponent()
        }

        guard let outputRoot = options.outputFolder else {
            throw MuniConvertError.outputFolderInvalid("Aucun dossier de sortie choisi")
        }

        guard options.preserveRelativeStructure else {
            return outputRoot
        }

        let sourceRoot = options.sourceFolder.standardizedFileURL
        let sourceDirectory = sourceFile.deletingLastPathComponent().standardizedFileURL

        guard let relativeDirectory = relativePath(from: sourceRoot, to: sourceDirectory) else {
            return outputRoot
        }

        if relativeDirectory.isEmpty {
            return outputRoot
        }

        return outputRoot.appendingPathComponent(relativeDirectory, isDirectory: true)
    }

    static func resolveTargetURL(
        for sourceFile: URL,
        options: ConversionOptions,
        fileManager: FileManager = .default
    ) throws -> TargetResolution {
        let outputDirectory = try targetDirectory(for: sourceFile, options: options)
        let baseName = sourceFile.deletingPathExtension().lastPathComponent
        let proposedTarget = outputDirectory
            .appendingPathComponent(baseName, isDirectory: false)
            .appendingPathExtension(options.profile.targetExtension)

        if proposedTarget.path.caseInsensitiveCompare(sourceFile.path) == .orderedSame {
            throw MuniConvertError.conversionFailed("Le fichier cible serait identique au fichier source: \(sourceFile.path)")
        }

        if !fileManager.fileExists(atPath: proposedTarget.path) {
            return TargetResolution(targetURL: proposedTarget, skippedBecauseExists: false)
        }

        switch options.collisionPolicy {
        case .skipExisting:
            return TargetResolution(targetURL: nil, skippedBecauseExists: true)
        case .overwrite:
            return TargetResolution(targetURL: proposedTarget, skippedBecauseExists: false)
        case .renameWithSuffix:
            let uniqueURL = uniqueTargetURL(from: proposedTarget, fileManager: fileManager)
            return TargetResolution(targetURL: uniqueURL, skippedBecauseExists: false)
        }
    }

    static func uniqueTargetURL(from url: URL, fileManager: FileManager = .default) -> URL {
        let directory = url.deletingLastPathComponent()
        let extensionPart = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent

        var index = 1
        var candidate = url

        while fileManager.fileExists(atPath: candidate.path) {
            let renamed = "\(baseName) (\(index))"
            candidate = directory.appendingPathComponent(renamed, isDirectory: false)
            if !extensionPart.isEmpty {
                candidate = candidate.appendingPathExtension(extensionPart)
            }
            index += 1
        }

        return candidate
    }

    static func relativePath(from baseDirectory: URL, to targetDirectory: URL) -> String? {
        let baseComponents = baseDirectory.standardizedFileURL.pathComponents
        let targetComponents = targetDirectory.standardizedFileURL.pathComponents

        guard targetComponents.count >= baseComponents.count else {
            return nil
        }

        for (basePart, targetPart) in zip(baseComponents, targetComponents) {
            if basePart != targetPart {
                return nil
            }
        }

        let remaining = Array(targetComponents.dropFirst(baseComponents.count))
        if remaining.isEmpty {
            return ""
        }

        return NSString.path(withComponents: remaining)
    }
}
