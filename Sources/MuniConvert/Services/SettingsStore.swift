// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct StoredSettings: Codable {
    var sourcePath: String?
    var outputPath: String?
    var includeSubdirectories: Bool
    var useSeparateOutputFolder: Bool
    var preserveRelativeStructure: Bool
    var dryRun: Bool
    var ignoreHiddenFiles: Bool
    var selectedProfileID: String?
    var collisionPolicy: String
    var libreOfficePath: String
    var appLanguage: String?

    static let `default` = StoredSettings(
        sourcePath: nil,
        outputPath: nil,
        includeSubdirectories: true,
        useSeparateOutputFolder: false,
        preserveRelativeStructure: false,
        dryRun: false,
        ignoreHiddenFiles: true,
        selectedProfileID: nil,
        collisionPolicy: CollisionPolicy.skipExisting.rawValue,
        libreOfficePath: "",
        appLanguage: AppLanguage.french.rawValue
    )
}

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "MuniConvert.StoredSettings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StoredSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        guard let stored = try? JSONDecoder().decode(StoredSettings.self, from: data) else {
            return .default
        }

        return stored
    }

    func save(_ settings: StoredSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
