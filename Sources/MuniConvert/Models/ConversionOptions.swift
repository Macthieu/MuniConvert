// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct ConversionOptions {
    let sourceFolder: URL
    let outputFolder: URL?
    let useSeparateOutputFolder: Bool
    let preserveRelativeStructure: Bool
    let includeSubdirectories: Bool
    let dryRun: Bool
    let ignoreHiddenFiles: Bool
    let collisionPolicy: CollisionPolicy
    let profile: ConversionProfile
}
