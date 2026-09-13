import Foundation
import GRDB

/// Réplique de `lib/data/model/vacation_period.dart`.
///
/// Les dates sont des chaînes `yyyy-MM-dd`, comparées telles quelles — l'ordre
/// lexicographique d'un tel format est l'ordre chronologique. Un `end` absent
/// désigne une journée isolée.
struct VacationPeriod: Identifiable, Hashable, Sendable {
    var id: Int64?
    var start: String
    var end: String?
    var sortOrder: Int = 0
}

extension VacationPeriod {
    /// Réplique du test de `monthColumnBuilder` : une journée isolée doit
    /// tomber pile, une période encadrer la date.
    func contains(_ day: String) -> Bool {
        guard let end else { return start == day }

        return start <= day && end >= day
    }
}

extension VacationPeriod: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "vacation_period"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
