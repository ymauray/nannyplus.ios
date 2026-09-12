import Foundation
import GRDB
import Testing

@testable import NannyPlus

/// Le portage ne vaut que si une base créée par la version native est
/// indiscernable de celle produite par sqflite : c'est ce qui permet aux deux
/// versions de travailler sur les mêmes données pendant la transition.
///
/// Les colonnes attendues ci-dessous sont relevées sur une base Flutter réelle
/// en version 13, et non recopiées depuis `Schema.swift` — sans quoi le test ne
/// vérifierait que sa propre cohérence.
struct SchemaTests {
    private static let expectedColumns: [String: [String]] = [
        "children": [
            "id", "firstName", "lastName", "birthdate", "phoneNumber",
            "allergies", "parentsName", "address", "archived", "preschool",
            "labelForPhoneNumber2", "phoneNumber2", "labelForPhoneNumber3",
            "phoneNumber3", "freeText", "pic", "hourCredits",
        ],
        "prices": ["id", "label", "amount", "fixedPrice", "sortOrder", "deleted"],
        "services": [
            "id", "childId", "date", "priceId", "priceLabel", "priceAmount",
            "isFixedPrice", "hours", "minutes", "total", "invoiced", "invoiceId",
        ],
        "invoices": [
            "id", "number", "childId", "date", "total", "parentsName", "address",
            "paid", "childFirstName", "childLastName", "hourCredits",
        ],
        "documents": ["id", "childId", "label", "path", "bytes"],
        "deductions": ["id", "sortOrder", "label", "value", "type", "periodicity"],
        "periods": [
            "id", "childId", "day", "hourFrom", "minuteFrom", "hourTo",
            "minuteTo", "sortOrder", "planningId",
        ],
        "schedule_colors": ["id", "childId", "color"],
        "vacation_period": ["id", "start", "end", "sortOrder"],
        "plannings": ["id", "start", "end"],
    ]

    private func migratedDatabase() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try Schema.migrate(queue)

        return queue
    }

    @Test("Une base neuve annonce la version 13, comme sqflite")
    func versionAfterCreation() throws {
        let version = try migratedDatabase().read { db in
            try Int.fetchOne(db, sql: "PRAGMA user_version")
        }

        #expect(version == Schema.version)
        #expect(version == 13)
    }

    @Test("Les colonnes correspondent à celles d'une base Flutter réelle", arguments: expectedColumns.sorted { $0.key < $1.key })
    func columns(table: String, expected: [String]) throws {
        let actual = try migratedDatabase().read { db in
            try db.columns(in: table).map(\.name)
        }

        #expect(actual == expected, "colonnes divergentes pour \(table)")
    }

    @Test("Rejouer les migrations sur une base à jour ne la modifie pas")
    func migratingTwiceIsInert() throws {
        let queue = try migratedDatabase()
        let before = try queue.read { try String.fetchAll($0, sql: "SELECT sql FROM sqlite_master ORDER BY name") }

        try Schema.migrate(queue)

        let after = try queue.read { try String.fetchAll($0, sql: "SELECT sql FROM sqlite_master ORDER BY name") }
        #expect(before == after)
    }

    @Test("Une base plus récente que le code est refusée plutôt que dégradée")
    func downgradeIsRejected() throws {
        let queue = try DatabaseQueue()
        try queue.write { db in
            try db.execute(sql: "PRAGMA user_version = \(Schema.version + 1)")
        }

        #expect(throws: SchemaError.self) {
            try Schema.migrate(queue)
        }
    }
}
