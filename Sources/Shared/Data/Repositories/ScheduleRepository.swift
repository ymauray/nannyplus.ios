import Foundation
import GRDB

/// Réplique de `lib/data/repository/schedule_repository.dart` et de
/// `schedule_color_repository.dart`, réunis : les deux ne servent qu'au
/// planning.
struct ScheduleRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    /// Toutes les lignes de `periods`, sans filtre — y compris celles rattachées
    /// à un `planningId`, que la version Flutter ne distingue pas non plus.
    func readPeriods() async throws -> [Period] {
        try await database.writer().read { db in
            try Period.fetchAll(db, sql: "SELECT * FROM periods")
        }
    }

    /// Les créneaux d'un enfant, dans l'ordre où l'écran les montre.
    func periods(childId: Int64) async throws -> [Period] {
        try await database.writer().read { db in
            try Period.fetchAll(
                db,
                sql: "SELECT * FROM periods WHERE childId = ? ORDER BY sortOrder ASC",
                arguments: [childId]
            )
        }
    }

    func readScheduleColors() async throws -> [ScheduleColor] {
        try await database.writer().read { db in
            try ScheduleColor.fetchAll(db, sql: "SELECT * FROM schedule_colors")
        }
    }

    /// Réplique de `weeklyScheduleProvider`.
    ///
    /// Les enfants retenus sont ceux qui ont au moins un créneau, ordonnés par
    /// la liste des dossiers : un dossier archivé disparaît donc du planning,
    /// ses créneaux avec lui.
    func weeklySchedule() async throws -> Schedule {
        let periods = try await readPeriods()
        let withPeriods = Set(periods.map(\.childId))

        let repository = ChildrenRepository()
        let children = try await repository.childList(showArchived: false)
        let childIds = children.compactMap(\.id).filter { withPeriods.contains($0) }

        return Schedule(
            childIds: childIds,
            periods: periods,
            scheduleColors: try await readScheduleColors(),
            childrenNames: try await repository.readChildrenNGrams()
        )
    }
}
