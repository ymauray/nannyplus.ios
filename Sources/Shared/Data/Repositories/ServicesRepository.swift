import Foundation
import GRDB

struct ServicesRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    /// Total affiché dans le bandeau du dossier d'un enfant : somme des
    /// prestations non facturées, hors tarifs techniques.
    ///
    /// Côté Flutter, `loadServices` écarte les prestations dont le `priceId` est
    /// négatif avant d'additionner — on reproduit ce filtre.
    func pendingTotal(childId: Int64) async throws -> Double {
        try await database.writer().read { db in
            try Double.fetchOne(db, sql: """
                SELECT COALESCE(SUM(total), 0) FROM services
                WHERE childId = ? AND invoiced = 0 AND priceId >= 0
                """, arguments: [childId]) ?? 0
        }
    }

    /// Réplique de `getStatementsSummary` puis du regroupement fait par
    /// `StatementListCubit.loadStatements`.
    ///
    /// Ne comptent que les prestations **facturées et dont la facture est
    /// payée**. Le mois en cours est écarté : il n'est pas encore clos.
    /// Les prestations **non facturées** d'un enfant, groupées par journée, les
    /// journées les plus récentes d'abord.
    ///
    /// Réplique de `ServiceListCubit.loadServices` : les tarifs techniques
    /// (`priceId < 0`) sont écartés, puis les prestations sont classées selon
    /// l'ordre de la grille tarifaire — ce qui détermine leur ordre à
    /// l'intérieur d'une journée.
    ///
    /// Côté Flutter, une prestation dont le tarif a été supprimé ferait échouer
    /// le tri et vider l'onglet ; on la classe ici en fin de liste. Aucune
    /// n'existe dans la base réelle.
    func serviceDays(childId: Int64) async throws -> [ServiceDay] {
        let services = try await database.writer().read { db in
            try Service.fetchAll(
                db,
                sql: """
                    SELECT * FROM services
                    WHERE childId = ? AND invoiced = 0
                    ORDER BY date DESC
                    """,
                arguments: [childId]
            )
        }

        let sorted = try await sortedByPrice(services)

        return Dictionary(grouping: sorted, by: \.date)
            .map { ServiceDay(date: $0.key, services: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Les prestations non facturées d'un enfant pour une journée, dans l'ordre
    /// de la grille tarifaire — `getServicesForChildAndDate`.
    func services(childId: Int64, date: String) async throws -> [Service] {
        let services = try await database.writer().read { db in
            try Service.fetchAll(
                db,
                sql: """
                    SELECT * FROM services
                    WHERE childId = ? AND date = ? AND invoiced = 0
                    """,
                arguments: [childId, date]
            )
        }

        return try await sortedByPrice(services)
    }

    @discardableResult
    func create(_ service: Service) async throws -> Service {
        try await database.writer().write { db in
            var inserted = service
            try inserted.insert(db)

            return inserted
        }
    }

    func update(_ service: Service) async throws {
        try await database.writer().write { db in
            try service.update(db)
        }
    }

    func delete(_ service: Service) async throws {
        guard let id = service.id else { return }

        try await database.writer().write { db in
            _ = try Service.deleteOne(db, key: id)
        }
    }

    /// Écarte les tarifs techniques puis classe selon l'ordre de la grille
    /// tarifaire. Côté Flutter, une prestation dont le tarif a été supprimé
    /// ferait lever une exception ; on la classe en fin de liste.
    private func sortedByPrice(_ services: [Service]) async throws -> [Service] {
        let order = try await PricesRepository().priceList()
            .reduce(into: [Int64: Int]()) { order, price in
                guard let id = price.id else { return }
                order[id] = price.sortOrder
            }

        return services
            .filter { $0.priceId >= 0 }
            .sorted { (order[$0.priceId] ?? .max) < (order[$1.priceId] ?? .max) }
    }

    /// Supprime toute une journée, facturée ou non — la requête Flutter ne
    /// filtre pas sur `invoiced`.
    func deleteDay(childId: Int64, date: String) async throws {
        try await database.writer().write { db in
            try db.execute(
                sql: "DELETE FROM services WHERE childId = ? AND date = ?",
                arguments: [childId, date]
            )
        }
    }

    func statements(deductions: [Deduction]) async throws -> [YearlyStatement] {
        let rows = try await database.writer().read { db in
            try Row.fetchAll(db, sql: """
                SELECT STRFTIME('%Y-%m', s.date) AS month, SUM(s.total) AS total
                FROM services s, invoices i
                WHERE s.invoiced = 1 AND s.invoiceId = i.id AND i.paid = 1
                GROUP BY month
                ORDER BY month DESC
                """)
        }

        let currentMonth = DateFormatter.month.string(from: Date())
        var byYear: [Int: [MonthlyStatement]] = [:]

        for row in rows {
            guard let month: String = row["month"], month != currentMonth else { continue }

            let parts = month.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let monthNumber = Int(parts[1])
            else { continue }

            let amount: Double = row["total"] ?? 0
            byYear[year, default: []].append(
                MonthlyStatement(
                    year: year,
                    month: monthNumber,
                    amount: amount,
                    netAmount: Self.net(of: amount, deductions: deductions)
                )
            )
        }

        return byYear.keys.sorted(by: >).map { year in
            YearlyStatement(
                year: year,
                monthlyStatements: byYear[year]!.sorted { $0.month > $1.month }
            )
        }
    }

    /// Réplique de `getStatementLines` pour un relevé mensuel : les prestations
    /// facturées et payées du mois, regroupées par libellé de tarif.
    ///
    /// Le filtre est `priceId != -1`, et non `priceId >= 0` comme pour le total
    /// du dossier enfant : les deux coexistent dans la version Flutter.
    func statementLines(year: Int, month: Int) async throws -> [StatementLine] {
        let start = String(format: "%04d-%02d-01", year, month)
        let end = month == 12
            ? String(format: "%04d-01-01", year + 1)
            : String(format: "%04d-%02d-01", year, month + 1)

        return try await database.writer().read { db in
            try Row.fetchAll(db, sql: """
                SELECT
                  s.priceLabel,
                  s.priceAmount,
                  s.isFixedPrice,
                  SUM(s.hours) + CAST(SUM(s.minutes) / 60 AS int) AS hours,
                  SUM(s.minutes) - 60 * CAST(SUM(s.minutes) / 60 AS int) AS minutes,
                  COUNT(1) AS count,
                  SUM(s.total) AS total
                FROM services s, invoices i
                WHERE s.priceId != -1
                  AND s.date >= ? AND s.date < ?
                  AND s.invoiced = 1 AND s.invoiceId = i.id AND i.paid = 1
                GROUP BY s.priceLabel
                ORDER BY s.isFixedPrice, s.priceLabel
                """, arguments: [start, end])
                .map { row in
                    StatementLine(
                        priceLabel: row["priceLabel"] ?? "",
                        priceAmount: row["priceAmount"] ?? 0,
                        isFixedPrice: row["isFixedPrice"] ?? 0,
                        hours: row["hours"] ?? 0,
                        minutes: row["minutes"] ?? 0,
                        count: row["count"] ?? 0,
                        total: row["total"] ?? 0
                    )
                }
        }
    }

    /// Applique les déductions **mensuelles** : un pourcentage se calcule sur le
    /// brut du mois, un montant se retranche tel quel.
    private static func net(of amount: Double, deductions: [Deduction]) -> Double {
        deductions
            .filter(\.isMonthly)
            .reduce(amount) { running, deduction in
                deduction.isPercent
                    ? running - amount * deduction.value / 100
                    : running - deduction.value
            }
    }

    /// Réplique de `getServiceInfoPerChild` (`services_repository.dart`).
    ///
    /// La suite d'opérations est conservée telle quelle, y compris ses
    /// particularités :
    /// - le total en attente ne filtre **pas** les dossiers archivés, alors que
    ///   la dernière saisie, elle, les exclut ;
    /// - le montant des factures impayées n'est reporté que sur les enfants
    ///   déjà présents dans la table ; un enfant qui a des factures impayées
    ///   mais aucune prestation reste donc absent du résultat, et sa tuile
    ///   affiche « ... » et 0.00.
    func serviceInfoPerChild() async throws -> [Int64: ServiceInfo] {
        try await database.writer().read { db in
            var map: [Int64: ServiceInfo] = [:]

            // 1. Total des prestations non facturées, par enfant.
            let pendingRows = try Row.fetchAll(db, sql: """
                SELECT childId, SUM(COALESCE(total, 0)) AS pendingTotal
                FROM services
                WHERE invoiced = 0
                GROUP BY childId
                """)

            for row in pendingRows {
                map[row["childId"]] = ServiceInfo(
                    pendingTotal: row["pendingTotal"] ?? 0,
                    lastEntry: nil,
                    pendingInvoice: 0
                )
            }

            // 2. Date de dernière saisie, dossiers archivés exclus.
            let lastEntryRows = try Row.fetchAll(db, sql: """
                SELECT childId, MAX(date) AS lastEntry
                FROM services, children
                WHERE children.id = services.childId AND children.archived = 0
                GROUP BY childId
                """)

            var lastEntries: [Int64: Date] = [:]
            for row in lastEntryRows {
                guard let text: String = row["lastEntry"],
                      let date = DateFormatter.databaseDate.date(from: text)
                else { continue }

                lastEntries[row["childId"]] = date
            }

            for (childId, date) in lastEntries {
                if map[childId] != nil {
                    map[childId]?.lastEntry = date
                } else {
                    // Enfant sans prestation en attente mais avec un historique.
                    map[childId] = ServiceInfo(
                        pendingTotal: 0,
                        lastEntry: date,
                        pendingInvoice: 0
                    )
                }
            }

            // 3. Total des factures impayées, reporté sur les seuls enfants
            //    déjà présents dans la table.
            let unpaidRows = try Row.fetchAll(db, sql: """
                SELECT childId, SUM(total) AS unpaid
                FROM invoices
                WHERE paid = 0
                GROUP BY childId
                """)

            for row in unpaidRows {
                let childId: Int64 = row["childId"]
                guard map[childId] != nil else { continue }

                map[childId]?.pendingInvoice = row["unpaid"] ?? 0
            }

            return map
        }
    }
}

extension DateFormatter {
    /// `yyyy-MM`, pour comparer au mois courant.
    static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"

        return formatter
    }()

    /// Les dates sont stockées en `yyyy-MM-dd`, sans fuseau ni heure.
    static let databaseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()
}
