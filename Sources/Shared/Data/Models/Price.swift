import Foundation
import GRDB

/// Réplique de `lib/data/model/price.dart`.
struct Price: Identifiable, Hashable, Sendable {
    var id: Int64?
    var label: String
    var amount: Double
    /// 0 ou 1 : la base stocke un entier, pas un booléen.
    var fixedPrice: Int
    var sortOrder: Int
    var deleted: Int

    var isFixedPrice: Bool { fixedPrice == 1 }

    /// « Tarif fixe de 5.00 » ou « Tarif horaire de 8.00 ».
    var detail: String {
        let kind = isFixedPrice ? "Tarif fixe" : "Tarif horaire"

        return "\(kind) de \(amount.twoDecimals)"
    }
}

extension Price: FetchableRecord, MutablePersistableRecord, Codable {
    static let databaseTableName = "prices"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
