import Testing
import Foundation
@testable import NannyPlus

/// Ce que le formulaire de facture calcule.
struct InvoiceFormTests {
    private func child(_ firstName: String, credits: Int = 0) -> Child {
        Child(id: 1, firstName: firstName, hourCredits: credits)
    }

    @Test("Le mois s'écrit en toutes lettres et en minuscules")
    func monthIsSpelledOut() {
        #expect(InvoiceMonth.name("2026-09") == "septembre 2026")
        #expect(InvoiceMonth.name("2026-01") == "janvier 2026")
    }

    /// C'est ce que porte l'en-tête « Crédits d'heures » de la facture.
    @Test("Les crédits d'heures listent chaque enfant de la facture")
    func hourCreditsListEveryChild() {
        #expect(
            InvoicesRepository.hourCredits(of: [child("Maé"), child("Ellie")])
                == "Maé: 0, Ellie: 0"
        )
        #expect(InvoicesRepository.hourCredits(of: [child("Maé", credits: 3)]) == "Maé: 3")
        #expect(InvoicesRepository.hourCredits(of: []).isEmpty)
    }
}
