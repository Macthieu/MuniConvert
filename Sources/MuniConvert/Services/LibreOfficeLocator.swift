// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct LibreOfficeInfo {
    let isFound: Bool
    let executablePath: String
    let version: String
    let message: String

    static let notFound = LibreOfficeInfo(
        isFound: false,
        executablePath: "",
        version: "",
        message: "LibreOffice non trouvé"
    )
}

final class LibreOfficeLocator {
    private let fileManager: FileManager
    private let processRunner: ProcessRunner

    init(fileManager: FileManager = .default, processRunner: ProcessRunner = ProcessRunner()) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    func locate(preferredPath: String?) -> LibreOfficeInfo {
        var candidates: [String] = []

        if let preferredPath, !preferredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates.append(preferredPath)
        }

        candidates.append(contentsOf: [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/Applications/LibreOfficeDev.app/Contents/MacOS/soffice",
            "/opt/homebrew/bin/soffice",
            "/usr/local/bin/soffice"
        ])

        if let fromPath = locateFromPATH() {
            candidates.append(fromPath)
        }

        for candidate in deduplicated(candidates) {
            if fileManager.isExecutableFile(atPath: candidate) {
                let version = readVersion(atPath: candidate)
                let message = version.isEmpty
                    ? "LibreOffice trouvé"
                    : "LibreOffice trouvé (\(version))"

                return LibreOfficeInfo(
                    isFound: true,
                    executablePath: candidate,
                    version: version,
                    message: message
                )
            }
        }

        return .notFound
    }

    func test(path: String) -> LibreOfficeInfo {
        guard fileManager.isExecutableFile(atPath: path) else {
            return .notFound
        }

        let version = readVersion(atPath: path)
        return LibreOfficeInfo(
            isFound: true,
            executablePath: path,
            version: version,
            message: version.isEmpty ? "LibreOffice trouvé" : "LibreOffice trouvé (\(version))"
        )
    }

    private func locateFromPATH() -> String? {
        let whichURL = URL(fileURLWithPath: "/usr/bin/which")
        guard fileManager.isExecutableFile(atPath: whichURL.path) else {
            return nil
        }

        guard let result = try? processRunner.run(executableURL: whichURL, arguments: ["soffice"]) else {
            return nil
        }

        guard result.terminationStatus == 0 else {
            return nil
        }

        let path = result.standardOutput
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return path.isEmpty ? nil : path
    }

    private func readVersion(atPath path: String) -> String {
        guard fileManager.isExecutableFile(atPath: path) else {
            return ""
        }

        let executableURL = URL(fileURLWithPath: path)
        guard let result = try? processRunner.run(executableURL: executableURL, arguments: ["--version"]),
              result.terminationStatus == 0
        else {
            return ""
        }

        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty {
            return result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return output
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let normalized = URL(fileURLWithPath: value).standardizedFileURL.path
            if seen.contains(normalized) {
                return false
            }
            seen.insert(normalized)
            return true
        }
    }
}
