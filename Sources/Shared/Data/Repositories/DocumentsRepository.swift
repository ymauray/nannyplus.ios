import Foundation
import GRDB

/// Réplique de `lib/data/repository/files_repository.dart`.
struct DocumentsRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    func documents(childId: Int64) async throws -> [Document] {
        try await database.writer().read { db in
            try Document.fetchAll(
                db,
                sql: "SELECT * FROM documents WHERE childId = ? ORDER BY label",
                arguments: [childId]
            )
        }
    }
}
