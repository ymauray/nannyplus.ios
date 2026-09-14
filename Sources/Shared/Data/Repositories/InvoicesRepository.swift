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

    func invoice(id: Int64) async throws -> Invoice? {
        try await database.writer().read { db in
            try Invoice.fetchOne(db, key: id)
        }
    }

    /// Les factures d'un enfant pour une année, la plus récente en tête —
    /// `yearlyInvoicesProvider`.
    func invoices(childId: Int64, year: Int) async throws -> [Invoice] {
        try await database.writer().read { db in
            try Invoice.fetchAll(
                db,
                sql: """
                    SELECT * FROM invoices
                    WHERE childId = ? AND SUBSTRING(date, 1, 4) = ?
                    ORDER BY date DESC
                    """,
                arguments: [childId, String(year)]
            )
        }
    }

    /// Le numéro suivant : le plus grand déjà employé, plus un.
    func nextNumber() async throws -> Int {
        try await database.writer().read { db in
            try Int.fetchOne(db, sql: "SELECT MAX(number) FROM invoices").map { $0 + 1 } ?? 1
        }
    }

    /// Crée la facture d'un mois pour un enfant et, le cas échéant, la fratrie
    /// qui l'accompagne. Rend `false` quand il n'y a rien à facturer.
    ///
    /// **Le contrôle porte sur toutes les prestations non facturées**, pas sur
    /// celles du mois retenu : une facture peut donc naître d'un mois vide et
    /// ne porter que ses marqueurs, pour un total nul. Défaut conservé.
    func createInvoice(for child: Child, with others: [Child], month: String) async throws -> Bool {
        guard let childId = child.id else { return false }

        let services = ServicesRepository()
        let children = [child] + others
        var pending: [Service] = []

        for one in children {
            guard let id = one.id else { continue }
            pending += try await services.serviceDays(childId: id).flatMap(\.services)
        }

        guard !pending.isEmpty else { return false }

        var invoice = try await create(Invoice(
            number: try await nextNumber(),
            childId: childId,
            childFirstName: child.firstName,
            childLastName: child.lastName ?? "",
            date: ServicesRepository.today(),
            total: 0,
            parentsName: child.parentsName ?? "",
            address: child.address ?? "",
            paid: 0,
            hourCredits: ""
        ))

        var total = 0.0

        for one in children {
            guard let id = one.id else { continue }

            let marker = try await services.addMarker(childId: id)
            let billed = try await services.serviceDays(childId: id)
                .flatMap(\.services)
                .filter { $0.date.prefix(7) == month }

            for service in [marker] + billed {
                var invoiced = service
                invoiced.invoiced = 1
                invoiced.invoiceId = invoice.id
                try await services.update(invoiced)
                total += service.total
            }
        }

        invoice.total = total
        invoice.hourCredits = Self.hourCredits(of: children)
        try await update(invoice)

        return true
    }

    /// « Maé: 0, Ellie: 0 » — c'est ce que porte l'en-tête de la facture.
    static func hourCredits(of children: [Child]) -> String {
        children.map { "\($0.firstName): \($0.hourCredits)" }.joined(separator: ", ")
    }

    @discardableResult
    func create(_ invoice: Invoice) async throws -> Invoice {
        try await database.writer().write { db in
            var inserted = invoice
            try inserted.insert(db)

            return inserted
        }
    }

    func update(_ invoice: Invoice) async throws {
        try await database.writer().write { db in
            try invoice.update(db)
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
