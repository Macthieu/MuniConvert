// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum LocalizationService {
    static func tr(_ key: String, language: AppLanguage) -> String {
        let bundle = bundle(for: language)
        return NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
    }

    static func tr(_ key: String, language: AppLanguage, _ arguments: [CVarArg]) -> String {
        let format = tr(key, language: language)
        return String(format: format, locale: Locale(identifier: language.localeIdentifier), arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.module
        }
        return bundle
    }
}
