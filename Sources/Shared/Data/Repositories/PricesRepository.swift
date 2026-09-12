import Foundation
import GRDB

/// Réplique de `lib/data/repository/prices_repository.dart`.
struct PricesRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    func priceList() async throws -> [Price] {
        try await database.writer().read { db in
            try Price.fetchAll(
                db,
                sql: "SELECT * FROM prices WHERE deleted = 0 ORDER BY sortOrder ASC"
            )
        }
    }

    /// Le nouveau tarif se place en fin de liste.
    @discardableResult
    func create(_ price: Price) async throws -> Price {
        try await database.writer().write { db in
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM prices"
            ) ?? 0

            var inserted = price
            inserted.sortOrder = maxSortOrder + 1
            try inserted.insert(db)

            return inserted
        }
    }

    @discardableResult
    func update(_ price: Price) async throws -> Price {
        try await database.writer().write { db in
            try price.update(db)

            return price
        }
    }

    /// **Suppression physique**, alors que la table porte une colonne `deleted`.
    /// C'est ce que fait la version Flutter : la colonne existe mais n'est
    /// jamais mise à 1, et aucune ligne de la base réelle ne l'a.
    func delete(id: Int64) async throws {
        try await database.writer().write { db in
            try db.execute(sql: "DELETE FROM prices WHERE id = ?", arguments: [id])
        }
    }

    /// Réécrit les `sortOrder` de 0 à n-1 dans l'ordre donné.
    ///
    /// La version Flutter recharge ici **tous** les tarifs, y compris ceux
    /// marqués supprimés, alors que la liste affichée les exclut : les indices
    /// se décaleraient s'il en existait. Le défaut est latent — `delete` étant
    /// physique, aucune ligne n'est jamais marquée. On réordonne donc à partir
    /// de la liste visible, ce qui donne le même résultat sur des données
    /// saines et reste juste si des lignes supprimées apparaissaient un jour.
    func reorder(_ prices: [Price]) async throws {
        try await database.writer().write { db in
            for (index, price) in prices.enumerated() {
                try db.execute(
                    sql: "UPDATE prices SET sortOrder = ? WHERE id = ?",
                    arguments: [index, price.id]
                )
            }
        }
    }
}
