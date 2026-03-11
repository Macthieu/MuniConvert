// SPDX-License-Identifier: GPL-3.0-only

import Foundation

final class ConversionEngine {
    private let processRunner: ProcessRunner
    private let fileManager: FileManager

    init(processRunner: ProcessRunner = ProcessRunner(), fileManager: FileManager = .default) {
        self.processRunner = processRunner
        self.fileManager = fileManager
    }

    func convert(
        job: FileConversionJob,
        libreOfficeExecutable: URL,
        overwriteIfNeeded: Bool
    ) throws -> String {
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("MuniConvert-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        let arguments = [
            "--headless",
            "--convert-to", job.profile.libreOfficeTarget,
            "--outdir", tempDirectory.path,
            job.sourceURL.path
        ]

        let processResult = try processRunner.run(executableURL: libreOfficeExecutable, arguments: arguments)

        if processResult.terminationStatus != 0 {
            let details = [processResult.standardOutput, processResult.standardError]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw MuniConvertError.conversionFailed(details.isEmpty ? "Code \(processResult.terminationStatus)" : details)
        }

        guard let generatedFile = try locateGeneratedFile(for: job, in: tempDirectory) else {
            throw MuniConvertError.conversionFailed("Fichier cible non produit pour \(job.sourceURL.lastPathComponent)")
        }

        let targetDirectory = job.targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: job.targetURL.path) {
            if overwriteIfNeeded {
                try fileManager.removeItem(at: job.targetURL)
            } else {
                throw MuniConvertError.nameCollision(job.targetURL.path)
            }
        }

        do {
            try fileManager.moveItem(at: generatedFile, to: job.targetURL)
        } catch {
            throw MuniConvertError.conversionFailed(error.localizedDescription)
        }

        let message = [processResult.standardOutput, processResult.standardError]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return message.isEmpty ? "Conversion terminée" : message
    }

    func cancelCurrentProcess() {
        processRunner.terminateRunningProcess()
    }

    private func locateGeneratedFile(for job: FileConversionJob, in directory: URL) throws -> URL? {
        let expectedName = job.sourceURL.deletingPathExtension().lastPathComponent
        let expectedExtension = job.profile.targetExtension.lowercased()

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for fileURL in contents {
            let fileExtension = fileURL.pathExtension.lowercased()
            let baseName = fileURL.deletingPathExtension().lastPathComponent

            if fileExtension == expectedExtension && baseName == expectedName {
                return fileURL
            }
        }

        return contents.first { $0.pathExtension.lowercased() == expectedExtension }
    }
}
