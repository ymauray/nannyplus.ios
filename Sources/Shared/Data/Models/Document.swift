import Foundation
import GRDB

/// Réplique de `lib/data/model/document.dart`.
///
/// **Deux générations de code coexistent** : un document ancien ne garde qu'un
/// chemin de fichier, un récent range ses octets dans la base. D'où l'icône
/// verte ou rouge de la fiche, selon que le fichier est retrouvable.
struct Document: Identifiable, Hashable, Sendable {
    var id: Int64?
    var childId: Int64
    var label: String
    var path: String = ""
    var bytes: Data?
}

extension Document {
    var isStoredInDatabase: Bool { !(bytes?.isEmpty ?? true) }

    var fileExists: Bool {
        !path.isEmpty && FileManager.default.fileExists(atPath: path)
    }

    var isReachable: Bool { isStoredInDatabase || fileExists }

    /// Les icônes de Font Awesome n'ont pas d'équivalent exact : on approche la
    /// base de données par un cylindre, le fichier retrouvé par une coche et le
    /// fichier manquant par un point d'exclamation.
    var iconName: String {
        if isStoredInDatabase { return "cylinder.split.1x2" }

        return fileExists ? "checkmark.circle" : "exclamationmark.circle"
    }
}

extension Document: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "documents"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
