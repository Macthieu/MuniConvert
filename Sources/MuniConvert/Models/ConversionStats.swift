// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct ConversionStats {
    var totalScanned: Int = 0
    var totalMatched: Int = 0
    var converted: Int = 0
    var ignored: Int = 0
    var errors: Int = 0
    var skippedExisting: Int = 0
    var dryRun: Int = 0

    var processed: Int {
        converted + skippedExisting + dryRun + errors
    }

    var summaryLine: String {
        summaryLine(language: .french)
    }

    func summaryLine(language: AppLanguage) -> String {
        LocalizationService.tr(
            "stats.summary",
            language: language,
            [
                totalScanned,
                totalMatched,
                converted,
                ignored,
                skippedExisting,
                dryRun,
                errors
            ]
        )
    }
}
