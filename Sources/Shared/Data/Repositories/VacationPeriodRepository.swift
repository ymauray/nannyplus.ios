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

}
