import Foundation
import GRDB

/// Réplique de `lib/data/model/child.dart`.
///
/// Les colonnes sont nommées comme en base (camelCase) et les types restent
/// ceux du schéma sqflite : `archived` et `preschool` sont des entiers 0/1,
/// `birthdate` une chaîne `yyyy-MM-dd`.
struct Child: Identifiable, Hashable, Sendable {
    var id: Int64?
    var firstName: String
    var lastName: String?
    var birthdate: String?
    var phoneNumber: String?
    var allergies: String?
    var parentsName: String?
    var address: String?
    var preschool: Int = 1
    var archived: Int = 0
    var labelForPhoneNumber2: String?
    var phoneNumber2: String?
    var labelForPhoneNumber3: String?
    var phoneNumber3: String?
    var freeText: String?
    var pic: Data?
    var hourCredits: Int = 0
}

// MARK: - Propriétés dérivées

extension Child {
    /// Dépend de la préférence `showFirstNameBeforeLastName`, comme côté Flutter
    /// où `displayName` lit `PrefsUtil.getInstanceSync()`.
    var displayName: String {
        if AppPreferences.shared.showFirstNameBeforeLastName {
            return "\(firstName) \(lastName ?? "")"
                .trimmingCharacters(in: .whitespaces)
        }

        let prefix = lastName.map { "\($0), " } ?? ""

        return "\(prefix)\(firstName)".trimmingCharacters(in: .whitespaces)
    }

    /// Initiales affichées dans la pastille de la liste.
    var nGram: String {
        displayName
            .split(separator: " ")
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    var hasPhoneNumber: Bool { !(phoneNumber?.isEmpty ?? true) }

    var hasAllergies: Bool { !(allergies?.isEmpty ?? true) }

    var isArchived: Bool { archived == 1 }
}

// MARK: - Persistance

extension Child: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "children"

    enum Columns {
        static let id = Column("id")
        static let firstName = Column("firstName")
        static let lastName = Column("lastName")
        static let archived = Column("archived")
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Child: Codable {}
