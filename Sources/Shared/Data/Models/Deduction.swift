import Foundation
import GRDB

/// Réplique de `lib/data/model/deduction.dart`.
///
/// `type` vaut `amount` ou `percent`, `periodicity` vaut `monthly` ou
/// `yearly` : ce sont les chaînes stockées en base, conservées telles quelles.
struct Deduction: Identifiable, Hashable, Sendable {
    var id: Int64?
    var sortOrder: Int
    var label: String
    var value: Double
    var type: String
    var periodicity: String

    var isPercent: Bool { type == "percent" }
    var isMonthly: Bool { periodicity == "monthly" }

    /// « Mensuel, 10.27% » ou « Annuel, 150.00 ».
    var detail: String {
        let periodicity = isMonthly ? "Mensuel" : "Annuel"

        return "\(periodicity), \(value.twoDecimals)\(isPercent ? "%" : "")"
    }
}

extension Deduction: FetchableRecord, MutablePersistableRecord, Codable {
    static let databaseTableName = "deductions"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
