// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum CollisionPolicy: String, CaseIterable, Identifiable, Codable {
    case skipExisting
    case overwrite
    case renameWithSuffix

    var id: String { rawValue }

    var displayName: String {
        displayName(language: .french)
    }

    var compactDisplayName: String {
        compactDisplayName(language: .french)
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .skipExisting:
            return LocalizationService.tr("collision.skip", language: language)
        case .overwrite:
            return LocalizationService.tr("collision.overwrite", language: language)
        case .renameWithSuffix:
            return LocalizationService.tr("collision.rename", language: language)
        }
    }

    func compactDisplayName(language: AppLanguage) -> String {
        switch self {
        case .skipExisting:
            return LocalizationService.tr("collision.skip.compact", language: language)
        case .overwrite:
            return LocalizationService.tr("collision.overwrite.compact", language: language)
        case .renameWithSuffix:
            return LocalizationService.tr("collision.rename.compact", language: language)
        }
    }
}
