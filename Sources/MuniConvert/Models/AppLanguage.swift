// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case french = "fr"
    case english = "en"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    func displayName(in language: AppLanguage) -> String {
        switch (self, language) {
        case (.french, .french):
            return "Français"
        case (.english, .french):
            return "Anglais"
        case (.french, .english):
            return "French"
        case (.english, .english):
            return "English"
        }
    }
}
