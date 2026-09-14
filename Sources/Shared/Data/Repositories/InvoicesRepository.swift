import Foundation
import GRDB

struct InvoicesRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    /// Réplique de `getInvoicesInfoPerChild` (`invoices_repository.dart`).
    ///
    /// Renvoie les enfants ayant au moins une facture impayée antérieure à
    /// `daysBeforeUnpaidInvoiceNotification` jours (10 par défaut). Leur nom
    /// s'affiche en rouge dans la liste.
    func childrenWithOverdueInvoices() async throws -> Set<Int64> {
        let days = AppPreferences.shared.daysBeforeUnpaidInvoiceNotification
        let threshold = Date().addingTimeInterval(-Double(days) * 86_400)
        let cutoff = DateFormatter.databaseDate.string(from: threshold)

        // Côté Flutter la comparaison porte sur un `DateTime` : la date de
        // facture, à minuit, est comparée à « maintenant moins N jours », qui
        // porte une heure. Une facture datée pile du jour de bascule est donc
        // retenue. La comparaison sur la seule date doit être `<=` pour
        // reproduire ce comportement.

        return try await database.writer().read { db in
            let ids = try Int64.fetchAll(db, sql: """
                SELECT DISTINCT childId
                FROM invoices
                WHERE paid = 0 AND date <= ?
                """, arguments: [cutoff])

            return Set(ids)
        }
    }

    /// Les factures d'un enfant, groupées par année, la plus récente en tête.
    ///
    /// Le filtre des payées est appliqué **après** la requête côté Flutter ; on
    /// fait de même, l'ordre de la liste étant le même dans les deux cas.
    func invoiceYears(childId: Int64, includePaid: Bool) async throws -> [InvoiceYear] {
        let invoices = try await database.writer().read { db in
            try Invoice.fetchAll(
                db,
                sql: "SELECT * FROM invoices WHERE childId = ? ORDER BY date DESC",
                arguments: [childId]
            )
        }
        .filter { includePaid || !$0.isPaid }

        return Dictionary(grouping: invoices, by: \.year)
            .map { InvoiceYear(year: $0.key, invoices: $0.value) }
            .sorted { $0.year > $1.year }
    }

    /// La moyenne d'une facture par année. **Toutes les factures comptent**,
    /// payées ou non : la moyenne ne suit pas le filtre de la liste.
    func monthlyAverages(childId: Int64) async throws -> [Int: Double] {
        try await database.writer().read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT SUBSTRING(date, 1, 4) AS year, AVG(total) AS average
                    FROM invoices
                    WHERE childId = ?
                    GROUP BY SUBSTRING(date, 1, 4)
                    """,
                arguments: [childId]
            )
            .reduce(into: [Int: Double]()) { averages, row in
                guard let year = Int(row["year"] as String? ?? "") else { return }
                averages[year] = row["average"] ?? 0
            }
        }
    }

    func markAsPaid(_ invoice: Invoice) async throws {
        guard let id = invoice.id else { return }

        try await database.writer().write { db in
            try db.execute(sql: "UPDATE invoices SET paid = 1 WHERE id = ?", arguments: [id])
        }
    }

    /// Supprimer une facture **rend ses prestations à facturer** plutôt que de
    /// les supprimer avec elle.
    func delete(_ invoice: Invoice) async throws {
        guard let id = invoice.id else { return }

        try await database.writer().write { db in
            try db.execute(
                sql: "UPDATE services SET invoiceId = NULL, invoiced = 0 WHERE invoiceId = ?",
                arguments: [id]
            )
            try db.execute(sql: "DELETE FROM invoices WHERE id = ?", arguments: [id])
        }
    }
}
