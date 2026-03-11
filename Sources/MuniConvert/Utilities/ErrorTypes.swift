// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum MuniConvertError: LocalizedError {
    case libreOfficeNotFound
    case sourceFolderInvalid(String)
    case outputFolderInvalid(String)
    case fileInaccessible(String)
    case conversionFailed(String)
    case nameCollision(String)
    case invalidProfile
    case processLaunchFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .libreOfficeNotFound:
            return "LibreOffice est introuvable. Installez LibreOffice ou configurez le chemin de soffice."
        case .sourceFolderInvalid(let path):
            return "Dossier source invalide: \(path)"
        case .outputFolderInvalid(let path):
            return "Dossier de sortie invalide: \(path)"
        case .fileInaccessible(let path):
            return "Fichier inaccessible: \(path)"
        case .conversionFailed(let details):
            return "Conversion échouée: \(details)"
        case .nameCollision(let path):
            return "Collision de nom pour: \(path)"
        case .invalidProfile:
            return "Profil de conversion invalide."
        case .processLaunchFailed(let details):
            return "Impossible de lancer le processus de conversion: \(details)"
        case .cancelled:
            return "Opération annulée par l'utilisateur."
        }
    }
}
