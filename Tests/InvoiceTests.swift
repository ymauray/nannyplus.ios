import Testing
import Foundation
@testable import NannyPlus

/// Le retard d'une facture, et l'arrondi des montants.
struct InvoiceTests {
    private func invoice(_ date: String, paid: Int = 0) -> Invoice {
        Invoice(number: 1, childId: 1, date: date, total: 100, paid: paid)
    }

    private let now = Date(timeIntervalSince1970: 1_789_000_000) // 2026-09-09

    @Test("Une facture impayée passe en retard au-delà du délai réglé")
    func lateAfterTheDelay() {
        // Dix jours par défaut : le 2026-08-20 est en retard, le 2026-09-05 non.
        #expect(invoice("2026-08-20").isLate(daysBefore: 10, now: now))
        #expect(!invoice("2026-09-05").isLate(daysBefore: 10, now: now))
    }

    @Test("Une facture payée n'est jamais en retard")
    func paidIsNeverLate() {
        #expect(!invoice("2020-01-01", paid: 1).isLate(daysBefore: 10, now: now))
    }

    @Test("L'année vient des quatre premiers caractères de la date")
    func yearComesFromTheDate() {
        #expect(invoice("2026-08-20").year == 2026)
    }

    /// `toStringAsFixed(2)` de Dart arrondit la moitié vers le haut, là où
    /// `%.2f` l'arrondit vers le pair le plus proche.
    @Test("Une moitié s'arrondit vers le haut")
    func halvesRoundUp() {
        #expect(636.125.twoDecimals == "636.13")
        #expect((-636.125).twoDecimals == "-636.13")
        #expect(285.681_818_181_818.twoDecimals == "285.68")
        #expect(1281.0.twoDecimals == "1281.00")
    }
}
