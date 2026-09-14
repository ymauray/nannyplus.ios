import Testing
import Foundation
@testable import NannyPlus

/// Ce que la fiche d'un enfant présente.
struct ChildInfoTests {
    @Test("Une date de la base s'écrit en toutes lettres")
    func datesAreSpelledOut() {
        #expect(FrenchDate.long("2015-04-14") == "14 avril 2015")
        #expect(FrenchDate.long("2026-08-24") == "24 août 2026")
        // Un champ absent ne donne rien plutôt qu'une date de repli.
        #expect(FrenchDate.long(nil).isEmpty)
    }

    /// Deux générations de code coexistent : un document ancien ne garde qu'un
    /// chemin, un récent range ses octets dans la base.
    @Test("L'icône d'un document dit où il se trouve")
    func documentIconTellsWhereItLives() {
        let inDatabase = Document(childId: 1, label: "Convention.pdf", bytes: Data([0x25, 0x50]))
        #expect(inDatabase.isStoredInDatabase)
        #expect(inDatabase.isReachable)
        #expect(inDatabase.iconName == "cylinder.split.1x2")

        let missing = Document(childId: 1, label: "Ancien.pdf", path: "/tmp/absent-\(UUID()).pdf")
        #expect(!missing.isStoredInDatabase)
        #expect(!missing.isReachable)
        #expect(missing.iconName == "exclamationmark.circle")
    }

    @Test("Un document retrouvé sur le disque porte la coche")
    func foundFileIsTicked() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nannyplus-test-\(UUID()).txt")
        try Data("bonjour".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let found = Document(childId: 1, label: "Present.txt", path: url.path)

        #expect(found.fileExists)
        #expect(found.iconName == "checkmark.circle")
    }
}
