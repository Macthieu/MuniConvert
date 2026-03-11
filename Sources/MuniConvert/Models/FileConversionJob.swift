// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct FileConversionJob: Identifiable, Hashable {
    let id = UUID()
    let sourceURL: URL
    let targetURL: URL
    let profile: ConversionProfile
}
