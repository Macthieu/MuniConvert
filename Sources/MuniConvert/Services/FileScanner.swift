// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct ScanResult {
    let matchedFiles: [URL]
    let logs: [LogEntry]
    let totalScanned: Int
    let totalIgnored: Int
}

final class FileScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(options: ConversionOptions) throws -> ScanResult {
        let sourcePath = options.sourceFolder.path
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: sourcePath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw MuniConvertError.sourceFolderInvalid(sourcePath)
        }

        if options.useSeparateOutputFolder {
            guard let outputFolder = options.outputFolder else {
                throw MuniConvertError.outputFolderInvalid("Aucun dossier de sortie")
            }

            var outputIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: outputFolder.path, isDirectory: &outputIsDirectory), outputIsDirectory.boolValue else {
                throw MuniConvertError.outputFolderInvalid(outputFolder.path)
            }
        }

        let fileURLs = try collectCandidateFiles(
            in: options.sourceFolder,
            includeSubdirectories: options.includeSubdirectories
        )

        let allowedExtensions = Set(options.profile.sourceExtensions.map { $0.lowercased() })

        var matched: [URL] = []
        var logs: [LogEntry] = []
        var scanned = 0
        var ignored = 0

        for fileURL in fileURLs.sorted(by: { $0.path < $1.path }) {
            let fileName = fileURL.lastPathComponent
            scanned += 1

            if PathUtilities.isTemporaryOrHiddenFile(named: fileName, ignoreHiddenFiles: options.ignoreHiddenFiles) {
                ignored += 1
                logs.append(LogEntry(
                    sourcePath: fileURL.path,
                    status: .ignored,
                    message: "Fichier temporaire/système ignoré"
                ))
                continue
            }

            if !fileManager.isReadableFile(atPath: fileURL.path) {
                ignored += 1
                logs.append(LogEntry(
                    sourcePath: fileURL.path,
                    status: .ignored,
                    message: "Fichier inaccessible"
                ))
                continue
            }

            let sourceExtension = fileURL.pathExtension.lowercased()
            guard !sourceExtension.isEmpty else {
                ignored += 1
                logs.append(LogEntry(
                    sourcePath: fileURL.path,
                    status: .ignored,
                    message: "Aucune extension"
                ))
                continue
            }

            if allowedExtensions.contains(sourceExtension) {
                matched.append(fileURL)
                logs.append(LogEntry(
                    sourcePath: fileURL.path,
                    status: .matched,
                    message: "Fichier correspondant au profil \(options.profile.displayName)"
                ))
            } else {
                ignored += 1
                logs.append(LogEntry(
                    sourcePath: fileURL.path,
                    status: .ignored,
                    message: "Extension .\(sourceExtension) hors filtre"
                ))
            }
        }

        return ScanResult(
            matchedFiles: matched,
            logs: logs,
            totalScanned: scanned,
            totalIgnored: ignored
        )
    }

    private func collectCandidateFiles(in rootFolder: URL, includeSubdirectories: Bool) throws -> [URL] {
        if includeSubdirectories {
            let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: rootFolder,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            )

            var files: [URL] = []
            while let nextObject = enumerator?.nextObject() as? URL {
                let values = try? nextObject.resourceValues(forKeys: Set(keys))
                if values?.isRegularFile == true {
                    files.append(nextObject)
                }
            }

            return files
        }

        let values = try fileManager.contentsOfDirectory(
            at: rootFolder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        )

        return values.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
    }
}
