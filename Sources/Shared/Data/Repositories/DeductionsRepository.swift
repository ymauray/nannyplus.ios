import Foundation
import GRDB

/// Réplique de `lib/data/repository/deduction_repository.dart`.
struct DeductionsRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    func readAll() async throws -> [Deduction] {
        try await database.writer().read { db in
            try Deduction.fetchAll(db, sql: "SELECT * FROM deductions ORDER BY sortOrder ASC")
        }
    }

    /// La nouvelle déduction se place en fin de liste, puis les rangs sont
    /// renumérotés — côté Flutter, `create` insère avec `sortOrder: 999999`
    /// avant d'appeler `reorder`.
    func create(_ deduction: Deduction) async throws {
        try await database.writer().write { db in
            var inserted = deduction
            inserted.sortOrder = 999_999
            try inserted.insert(db)
            try Self.renumber(db)
        }
    }

    func update(_ deduction: Deduction) async throws {
        try await database.writer().write { db in
            try deduction.update(db)
            try Self.renumber(db)
        }
    }

    func delete(_ deduction: Deduction) async throws {
        guard let id = deduction.id else { return }

        try await database.writer().write { db in
            try db.execute(sql: "DELETE FROM deductions WHERE id = ?", arguments: [id])
            try Self.renumber(db)
        }
    }

    func reorder(_ deductions: [Deduction]) async throws {
        try await database.writer().write { db in
            for (index, deduction) in deductions.enumerated() {
                try db.execute(
                    sql: "UPDATE deductions SET sortOrder = ? WHERE id = ?",
                    arguments: [index, deduction.id]
                )
            }
        }
    }

    /// Réécrit les rangs de 0 à n-1 dans l'ordre courant, pour qu'ils restent
    /// contigus après une insertion ou une suppression.
    private static func renumber(_ db: Database) throws {
        let ids = try Int64.fetchAll(db, sql: "SELECT id FROM deductions ORDER BY sortOrder ASC")

        for (index, id) in ids.enumerated() {
            try db.execute(
                sql: "UPDATE deductions SET sortOrder = ? WHERE id = ?",
                arguments: [index, id]
            )
        }
    }
}
