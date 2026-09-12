import Foundation
import GRDB

struct ServicesRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
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
    /// Les dates sont stockées en `yyyy-MM-dd`, sans fuseau ni heure.
    static let databaseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()
}
