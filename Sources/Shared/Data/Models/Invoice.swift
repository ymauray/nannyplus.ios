import Foundation
import GRDB

/// Réplique de `lib/data/model/invoice.dart`.
///
/// Le nom de l'enfant, celui des parents et l'adresse sont **recopiés dans la
/// facture** au moment de l'émission : une facture ancienne garde donc les
/// coordonnées d'alors.
struct Invoice: Identifiable, Hashable, Sendable {
    var id: Int64?
    var number: Int
    var childId: Int64
    var childFirstName: String = ""
    var childLastName: String = ""
    /// `yyyy-MM-dd`, comparable tel quel.
    var date: String
    var total: Double
    var parentsName: String = ""
    var address: String = ""
    /// 0 ou 1 : la base stocke un entier, pas un booléen.
    var paid: Int = 0
    var hourCredits: String = ""
}

extension Invoice {
    var isPaid: Bool { paid == 1 }

    var year: Int { Int(date.prefix(4)) ?? 0 }

    /// Une facture impayée passe en retard au-delà du délai réglé dans les
    /// paramètres de l'application — c'est ce qui la fait virer au rouge.
    func isLate(daysBefore: Int, now: Date = Date()) -> Bool {
        guard !isPaid, let issued = Self.formatter.date(from: date) else { return false }

        return issued < now.addingTimeInterval(-Double(daysBefore) * 86_400)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()
}

extension Invoice: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "invoices"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Les factures d'une même année, telles que la carte les affiche.
struct InvoiceYear: Identifiable, Hashable, Sendable {
    var id: Int { year }

    let year: Int
    let invoices: [Invoice]
}
