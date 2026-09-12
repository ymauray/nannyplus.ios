import Foundation
import GRDB

/// Réplique fidèle de `lib/utils/database_util.dart`.
///
/// On n'utilise volontairement **pas** `DatabaseMigrator` de GRDB : celui-ci
/// tient son journal dans une table `grdb_migrations` qui n'existe pas dans les
/// bases produites par sqflite. On reproduit donc le mécanisme de sqflite,
/// fondé sur `PRAGMA user_version`, pour rester binairement compatible avec les
/// bases existantes (une base Flutter à jour est en version 13 et ne subit
/// aucune modification à l'ouverture).
enum Schema {
    static let version = 13

    static func migrate(_ writer: DatabaseQueue) throws {
        let target = version

        try writer.write { db in
            let current = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0

            guard current != target else { return }

            if current > target {
                throw SchemaError.downgradeNotSupported(from: current, to: target)
            }

            if current == 0 {
                try createV1(db)
                for step in 2...target {
                    try upgrade(to: step, db)
                }
            } else {
                for step in (current + 1)...target {
                    try upgrade(to: step, db)
                }
            }

            try db.execute(sql: "PRAGMA user_version = \(target)")
        }
    }

    // MARK: - Schéma initial (version 1)

    private static func createV1(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE children (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              firstName TEXT NOT NULL,
              lastName TEXT,
              birthdate TEXT,
              phoneNumber TEXT,
              allergies TEXT,
              parentsName TEXT,
              address TEXT,
              archived INTEGER NOT NULL DEFAULT 0,
              preschool INTEGER NOT NULL DEFAULT 1
            )
            """)

        try db.execute(sql: """
            CREATE TABLE prices(
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              label TEXT,
              amount DOUBLE,
              fixedPrice INTEGER
            )
            """)

        try db.execute(sql: """
            CREATE TABLE services(
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              childId INTEGER NOT NULL,
              date TEXT,
              priceId INTEGER NOT NULL,
              priceLabel TEXT,
              priceAmount DOUBLE,
              isFixedPrice INTEGER,
              hours INTEGER,
              minutes INTEGER,
              total DOUBLE,
              invoiced INTEGER,
              invoiceId INTEGER
            )
            """)

        try db.execute(sql: """
            CREATE TABLE invoices(
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              number INTEGER NOT NULL,
              childId INTEGER NOT NULL,
              date TEXT,
              total DOUBLE NOT NULL,
              parentsName TEXT NOT NULL,
              address TEXT NOT NULL
            )
            """)

        // NOTE: côté Flutter, `_create` enchaîne sur `insertSampleData` (tarifs,
        // enfants, prestations et facture d'exemple + valeurs par défaut des
        // préférences de facturation et logo). Pas encore porté — à faire au
        // moment du portage de l'onboarding.
    }

    // MARK: - Migrations

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func upgrade(to version: Int, _ db: Database) throws {
        switch version {
        case 2:
            try db.execute(sql: "ALTER TABLE children ADD labelForPhoneNumber2 TEXT")
            try db.execute(sql: "ALTER TABLE children ADD phoneNumber2 TEXT")
            try db.execute(sql: "ALTER TABLE children ADD labelForPhoneNumber3 TEXT")
            try db.execute(sql: "ALTER TABLE children ADD phoneNumber3 TEXT")
            try db.execute(sql: "ALTER TABLE children ADD freeText TEXT")

        case 3:
            try db.execute(sql: """
                ALTER TABLE prices ADD sortOrder INTEGER NOT NULL DEFAULT 0
                """)
            let ids = try Int64.fetchAll(
                db,
                sql: "SELECT id FROM prices ORDER BY label ASC"
            )
            for (offset, id) in ids.enumerated() {
                try db.execute(
                    sql: "UPDATE prices SET sortOrder = ? WHERE id = ?",
                    arguments: [offset + 1, id]
                )
            }

        case 4:
            try db.execute(sql: """
                ALTER TABLE invoices ADD paid INTEGER NOT NULL DEFAULT 0
                """)

        case 5:
            try db.execute(sql: """
                ALTER TABLE prices ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0
                """)

        case 6:
            try db.execute(sql: """
                CREATE TABLE documents (
                  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                  childId INTEGER NOT NULL,
                  label TEXT NOT NULL,
                  path TEXT NOT NULL,
                  FOREIGN KEY(childId) REFERENCES children(id)
                )
                """)

        case 7:
            try db.execute(sql: "ALTER TABLE children ADD COLUMN pic BLOB")

        case 8:
            try db.execute(sql: "ALTER TABLE documents ADD COLUMN bytes BLOB")

        case 9:
            try db.execute(sql: """
                ALTER TABLE invoices ADD COLUMN childFirstName TEXT NOT NULL DEFAULT ''
                """)
            try db.execute(sql: """
                ALTER TABLE invoices ADD COLUMN childLastName TEXT NOT NULL DEFAULT ''
                """)
            try db.execute(sql: """
                UPDATE invoices
                SET
                  childFirstName = (SELECT firstName FROM children WHERE children.id = invoices.childId),
                  childLastName = (SELECT lastName FROM children WHERE children.id = invoices.childId)
                """)

        case 10:
            try db.execute(sql: """
                CREATE TABLE deductions (
                  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                  sortOrder INTEGER NOT NULL DEFAULT 0,
                  label TEXT,
                  value REAL NOT NULL DEFAULT 0,
                  type TEXT,
                  periodicity TEXT
                )
                """)

        case 11:
            try db.execute(sql: """
                CREATE TABLE periods(
                  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                  childId INTEGER NOT NULL,
                  day TEXT,
                  hourFrom INTEGER,
                  minuteFrom INTEGER,
                  hourTo INTEGER,
                  minuteTo INTEGER,
                  sortOrder INTEGER NOT NULL DEFAULT 0
                )
                """)
            try db.execute(sql: """
                CREATE TABLE schedule_colors(
                  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                  childId INTEGER NOT NULL,
                  color INTEGER NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE vacation_period(
                  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                  start TEXT,
                  end TEXT,
                  sortOrder INTEGER NOT NULL DEFAULT 0
                )
                """)

        case 12:
            try db.execute(sql: """
                CREATE TABLE plannings(
                  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                  start TEXT NOT NULL,
                  end TEXT NOT NULL
                )
                """)
            try db.execute(sql: "ALTER TABLE periods ADD COLUMN planningId INTEGER")

            let count = try Int.fetchOne(db, sql: "SELECT COUNT(1) FROM periods") ?? 0
            if count > 0 {
                try db.execute(
                    sql: "INSERT INTO plannings (start, end) VALUES (?, ?)",
                    arguments: ["2023-08-01", "2024-07-31"]
                )
                let planningId = db.lastInsertedRowID
                try db.execute(
                    sql: "UPDATE periods SET planningId = ?",
                    arguments: [planningId]
                )
            }

        case 13:
            try db.execute(sql: """
                ALTER TABLE children ADD COLUMN hourCredits INTEGER NOT NULL DEFAULT 0
                """)
            try db.execute(sql: """
                ALTER TABLE invoices ADD COLUMN hourCredits TEXT NOT NULL DEFAULT ''
                """)

        default:
            break
        }
    }
}

enum SchemaError: Error {
    case downgradeNotSupported(from: Int, to: Int)
}
