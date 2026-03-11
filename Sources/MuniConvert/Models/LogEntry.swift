// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum LogStatus: String, Codable, CaseIterable {
    case matched
    case ignored
    case converted
    case failed
    case skippedExisting
    case dryRun

    var displayName: String {
        displayName(language: .french)
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .matched:
            return LocalizationService.tr("log_status.matched", language: language)
        case .ignored:
            return LocalizationService.tr("log_status.ignored", language: language)
        case .converted:
            return LocalizationService.tr("log_status.converted", language: language)
        case .failed:
            return LocalizationService.tr("log_status.failed", language: language)
        case .skippedExisting:
            return LocalizationService.tr("log_status.skipped_existing", language: language)
        case .dryRun:
            return LocalizationService.tr("log_status.dry_run", language: language)
        }
    }
}

struct LogEntry: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let sourcePath: String
    let status: LogStatus
    let outputPath: String
    let message: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        sourcePath: String,
        status: LogStatus,
        outputPath: String = "",
        message: String
    ) {
        self.id = id
        self.date = date
        self.sourcePath = sourcePath
        self.status = status
        self.outputPath = outputPath
        self.message = message
    }
}
