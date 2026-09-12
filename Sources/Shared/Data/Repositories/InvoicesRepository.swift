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
}
