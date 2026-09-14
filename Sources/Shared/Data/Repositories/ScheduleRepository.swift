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

    /// Un nouveau créneau, sans jour et de 7:00 à 18:00, posé en fin de liste.
    @discardableResult
    func addPeriod(childId: Int64) async throws -> Period {
        try await create(Period(
            childId: childId,
            day: "",
            hourFrom: 7,
            minuteFrom: 0,
            hourTo: 18,
            minuteTo: 0,
            sortOrder: 9999
        ))
    }

    /// Le double d'un créneau, posé en fin de liste.
    @discardableResult
    func duplicate(_ period: Period) async throws -> Period {
        var copy = period
        copy.id = nil
        copy.sortOrder = 9999

        return try await create(copy)
    }

    @discardableResult
    func create(_ period: Period) async throws -> Period {
        try await database.writer().write { db in
            var inserted = period
            try inserted.insert(db)

            return inserted
        }
    }

    func update(_ period: Period) async throws {
        try await database.writer().write { db in
            try period.update(db)
        }
    }

    func delete(_ period: Period) async throws {
        guard let id = period.id else { return }

        try await database.writer().write { db in
            _ = try Period.deleteOne(db, key: id)
        }
    }

    /// Renumérote les `sortOrder` d'un enfant dans l'ordre des jours puis des
    /// heures. Flutter l'appelle au retour de l'écran de planning.
    func sortPeriods(childId: Int64) async throws {
        let sorted = try await periods(childId: childId).sorted(by: Period.isBefore)

        try await database.writer().write { db in
            for (order, period) in sorted.enumerated() {
                var renumbered = period
                renumbered.sortOrder = order
                try renumbered.update(db)
            }
        }
    }

    /// La couleur d'un enfant dans les plannings.
    ///
    /// **Lire crée** : un enfant sans couleur s'en voit attribuer une, violette,
    /// enregistrée aussitôt. Défaut conservé.
    func color(childId: Int64) async throws -> Int64 {
        let existing = try await database.writer().read { db in
            try ScheduleColor.fetchOne(
                db,
                sql: "SELECT * FROM schedule_colors WHERE childId = ?",
                arguments: [childId]
            )
        }

        if let existing { return existing.color }

        let purple: Int64 = 0xFF9C_27B0
        try await database.writer().write { db in
            var created = ScheduleColor(childId: childId, color: purple)
            try created.insert(db)
        }

        return purple
    }

    func updateColor(childId: Int64, to color: Int64) async throws {
        try await database.writer().write { db in
            try db.execute(
                sql: "UPDATE schedule_colors SET color = ? WHERE childId = ?",
                arguments: [color, childId]
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
