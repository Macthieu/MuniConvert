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
        "Scannés: \(totalScanned) | Correspondants: \(totalMatched) | Convertis: \(converted) | Ignorés: \(ignored) | Existant ignoré: \(skippedExisting) | Simulation: \(dryRun) | Erreurs: \(errors)"
    }
}
