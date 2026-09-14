import Testing
import Foundation
@testable import NannyPlus

/// La relance par SMS : le texte, le numéro, l'adresse.
struct InvoiceNotificationTests {
    private let invoice = Invoice(
        number: 278,
        childId: 24,
        date: "2026-08-24",
        total: 1281,
        paid: 0
    )

    @Test("Le gabarit reçoit la date et le montant")
    func templateIsFilled() {
        let message = InvoiceNotification.message(
            template: "Facture du {{date}} pour un montant de {{total}}.",
            invoice: invoice
        )

        #expect(message == "Facture du 24 août 2026 pour un montant de 1281.00.")
    }

    @Test("Le numéro perd tout ce qui n'est ni chiffre, ni point, ni tiret, ni plus")
    func numberIsSanitized() {
        #expect(InvoiceNotification.sanitized("Maman : +41 79 123 45 67") == "+41791234567")
        #expect(InvoiceNotification.sanitized("079.123-45-67") == "079.123-45-67")
    }

    @Test("L'adresse suit la forme attendue par iOS")
    func urlUsesTheIOSShape() throws {
        let url = try #require(InvoiceNotification.url(
            phoneNumber: "079 123 45 67",
            message: "Bonjour"
        ))

        // L'esperluette, et non le point d'interrogation d'Android.
        #expect(url.absoluteString == "sms:0791234567&body=Bonjour")
    }

    @Test("Le message est encodé, espaces et accents compris")
    func messageIsEncoded() throws {
        let url = try #require(InvoiceNotification.url(
            phoneNumber: "0791234567",
            message: "Facture du 24 août"
        ))

        #expect(url.absoluteString == "sms:0791234567&body=Facture%20du%2024%20ao%C3%BBt")
    }

    @Test("Un dossier sans numéro ne donne aucune adresse")
    func noNumberNoURL() {
        #expect(InvoiceNotification.url(phoneNumber: "", message: "Bonjour") == nil)
        // Un libellé sans le moindre chiffre ne fait pas un numéro.
        #expect(InvoiceNotification.url(phoneNumber: "Maman", message: "Bonjour") == nil)
    }
}
