import Foundation
import GRDB

/// Réplique de `lib/data/repository/vacation_period_repository.dart`.
struct VacationPeriodRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    /// **Le filtre porte sur la date de début seule** : une période à cheval
    /// sur deux années n'appartient qu'à celle où elle commence, et ne grise
    /// donc rien en janvier de la suivante. Défaut conservé.
    func loadForYear(_ year: Int) async throws -> [VacationPeriod] {
        try await database.writer().read { db in
            try VacationPeriod.fetchAll(
                db,
                sql: """
                    SELECT * FROM vacation_period
                    WHERE start LIKE ?
                    ORDER BY sortOrder
                    """,
                arguments: ["\(year)%"]
            )
        }
    }

    /// `sortOrder` à 9999 : la nouvelle période se pose en fin de liste, jusqu'au
    /// prochain tri.
    func create(start: String, end: String? = nil) async throws {
        try await database.writer().write { db in
            var period = VacationPeriod(start: start, end: end, sortOrder: 9999)
            try period.insert(db)
        }
    }

    func update(_ period: VacationPeriod) async throws {
        try await database.writer().write { db in
            try period.update(db)
        }
    }

    func delete(_ period: VacationPeriod) async throws {
        guard let id = period.id else { return }

        try await database.writer().write { db in
            _ = try VacationPeriod.deleteOne(db, key: id)
        }
    }

    /// Renumérote les `sortOrder` d'une année selon l'ordre des dates, une
    /// journée isolée passant avant une période qui commence le même jour.
    ///
    /// Flutter l'appelle en quittant l'écran et à chaque changement d'année par
    /// les flèches — mais **pas** quand on touche l'année pour revenir à
    /// l'année en cours. Incohérence conservée.
    func sort(_ periods: [VacationPeriod]) async throws {
        let sorted = VacationPeriodEdit.sorted(periods)

        try await database.writer().write { db in
            for (order, period) in sorted.enumerated() {
                var renumbered = period
                renumbered.sortOrder = order
                try renumbered.update(db)
            }
        }
    }
}
