// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct ConversionProfile: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let sourceExtensions: [String]
    let targetExtension: String
    let libreOfficeTarget: String

    init(
        id: String,
        displayName: String,
        sourceExtensions: [String],
        targetExtension: String,
        libreOfficeTarget: String
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceExtensions = sourceExtensions.map { $0.lowercased() }
        self.targetExtension = targetExtension.lowercased()
        self.libreOfficeTarget = libreOfficeTarget
    }
}

extension ConversionProfile {
    static let all: [ConversionProfile] = [
        .init(id: "doc_to_docx", displayName: "DOC -> DOCX", sourceExtensions: ["doc"], targetExtension: "docx", libreOfficeTarget: "docx"),
        .init(id: "doc_to_pdf", displayName: "DOC -> PDF", sourceExtensions: ["doc"], targetExtension: "pdf", libreOfficeTarget: "pdf"),
        .init(id: "docx_to_pdf", displayName: "DOCX -> PDF", sourceExtensions: ["docx"], targetExtension: "pdf", libreOfficeTarget: "pdf"),
        .init(id: "xls_to_xlsx", displayName: "XLS -> XLSX", sourceExtensions: ["xls"], targetExtension: "xlsx", libreOfficeTarget: "xlsx"),
        .init(id: "xls_to_pdf", displayName: "XLS -> PDF", sourceExtensions: ["xls"], targetExtension: "pdf", libreOfficeTarget: "pdf"),
        .init(id: "xlsx_to_pdf", displayName: "XLSX -> PDF", sourceExtensions: ["xlsx"], targetExtension: "pdf", libreOfficeTarget: "pdf"),
        .init(id: "ppt_to_pptx", displayName: "PPT -> PPTX", sourceExtensions: ["ppt"], targetExtension: "pptx", libreOfficeTarget: "pptx"),
        .init(id: "ppt_to_pdf", displayName: "PPT -> PDF", sourceExtensions: ["ppt"], targetExtension: "pdf", libreOfficeTarget: "pdf"),
        .init(id: "pptx_to_pdf", displayName: "PPTX -> PDF", sourceExtensions: ["pptx"], targetExtension: "pdf", libreOfficeTarget: "pdf"),
        .init(id: "rtf_to_docx", displayName: "RTF -> DOCX", sourceExtensions: ["rtf"], targetExtension: "docx", libreOfficeTarget: "docx"),
        .init(id: "rtf_to_pdf", displayName: "RTF -> PDF", sourceExtensions: ["rtf"], targetExtension: "pdf", libreOfficeTarget: "pdf"),
        .init(id: "txt_to_pdf", displayName: "TXT -> PDF", sourceExtensions: ["txt"], targetExtension: "pdf", libreOfficeTarget: "pdf")
    ]

    static func byID(_ id: String?) -> ConversionProfile? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}
