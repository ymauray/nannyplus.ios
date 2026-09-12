import Foundation
import GRDB

/// Accès à `childcare.db`.
///
/// Le chemin reproduit exactement celui de sqflite côté Flutter
/// (`NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)`
/// puis `childcare.db`), de sorte que l'app native, publiée sous le même bundle
/// identifier, reprenne la base existante de l'utilisatrice sans copie ni import.
actor AppDatabase {
    static let shared = AppDatabase()

    private var queue: DatabaseQueue?

    static var databaseURL: URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        return documents.appendingPathComponent("childcare.db")
    }

    /// Ouvre la base (en la créant au schéma v13 si elle n'existe pas) et
    /// applique les migrations manquantes.
    func writer() throws -> DatabaseQueue {
        if let queue { return queue }

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true

        let queue = try DatabaseQueue(
            path: Self.databaseURL.path,
            configuration: configuration
        )
        try Schema.migrate(queue)

        self.queue = queue

        return queue
    }

    /// `DatabaseUtil.closeDatabase`. Nécessaire avant de partager ou de
    /// remplacer le fichier : la connexion ouverte est relâchée, et SQLite
    /// referme son journal. La base se rouvrira d'elle-même au prochain accès.
    func close() {
        queue = nil
    }

    /// `DatabaseUtil.deleteDatabase`. Réservé à l'élément de tiroir visible en
    /// compilation de debug uniquement.
    func delete() throws {
        queue = nil

        let url = Self.databaseURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        try FileManager.default.removeItem(at: url)
    }
}
