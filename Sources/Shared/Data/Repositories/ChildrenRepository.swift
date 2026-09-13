import Foundation
import GRDB

/// Réplique de `lib/data/repository/children_repository.dart`.
struct ChildrenRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    /// `archived <= 0` masque les dossiers archivés, `archived <= 1` les inclut —
    /// c'est littéralement la clause utilisée côté Flutter.
    func childList(showArchived: Bool) async throws -> [Child] {
        let orderBy = AppPreferences.shared.sortListByLastName
            ? "lastName, firstName"
            : "firstName, lastName"

        return try await database.writer().read { db in
            try Child.fetchAll(
                db,
                sql: """
                    SELECT * FROM children
                    WHERE archived <= ?
                    ORDER BY \(orderBy)
                    """,
                arguments: [showArchived ? 1 : 0]
            )
        }
    }

    /// Les initiales de **tous** les dossiers, archivés compris : le planning
    /// hebdomadaire y puise les libellés de ses colonnes.
    func readChildrenNGrams() async throws -> [Int64: String] {
        let children = try await database.writer().read { db in
            try Child.fetchAll(db, sql: "SELECT * FROM children")
        }

        return children.reduce(into: [Int64: String]()) { names, child in
            guard let id = child.id else { return }
            names[id] = child.nGram
        }
    }

    func read(id: Int64) async throws -> Child? {
        try await database.writer().read { db in
            try Child.fetchOne(db, key: id)
        }
    }

    @discardableResult
    func create(_ child: Child) async throws -> Child {
        try await database.writer().write { db in
            var inserted = child
            try inserted.insert(db)

            return inserted
        }
    }

    @discardableResult
    func update(_ child: Child) async throws -> Child {
        try await database.writer().write { db in
            try child.update(db)

            return child
        }
    }

    /// Supprime en cascade les factures et prestations, comme côté Flutter.
    func delete(_ child: Child) async throws {
        guard let id = child.id else { return }

        try await database.writer().write { db in
            try db.execute(sql: "DELETE FROM invoices WHERE childId = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM services WHERE childId = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM children WHERE id = ?", arguments: [id])
        }
    }
}
