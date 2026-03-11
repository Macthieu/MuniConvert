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
        switch self {
        case .matched:
            return "matched"
        case .ignored:
            return "ignored"
        case .converted:
            return "converted"
        case .failed:
            return "failed"
        case .skippedExisting:
            return "skippedExisting"
        case .dryRun:
            return "dryRun"
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
