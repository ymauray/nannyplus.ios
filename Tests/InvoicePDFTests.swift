import Testing
import Foundation
import CoreGraphics
@testable import NannyPlus

/// Ce que la facture et le relevé annuel calculent avant de se composer.
struct InvoicePDFTests {
    private func invoice(total: Double = 100, paid: Int = 1) -> Invoice {
        Invoice(
            id: 1,
            number: 278,
            childId: 24,
            childFirstName: "Maé",
            childLastName: "Burri",
            date: "2026-08-24",
            total: total,
            paid: paid
        )
    }

    private func service(childId: Int64, priceId: Int64, total: Double, date: String = "2026-08-01") -> Service {
        Service(childId: childId, date: date, priceId: priceId, isFixedPrice: 1, total: total)
    }

    @Test("Le cartouche nomme l'enfant seul par son nom affiché")
    func titleForASingleChild() {
        let content = InvoicePDF.Content(
            invoice: invoice(),
            services: [service(childId: 24, priceId: 18, total: 1281)],
            children: [(id: 24, firstName: "Maé")]
        )

        #expect(InvoicePDF.title(for: content) == "Maé Burri")
    }

    @Test("Une fratrie est nommée par ses prénoms, le dernier amené par « et »")
    func titleForSeveralChildren() {
        let content = InvoicePDF.Content(
            invoice: invoice(),
            services: [],
            children: [(id: 24, firstName: "Maé"), (id: 28, firstName: "Ellie")]
        )

        #expect(InvoicePDF.title(for: content) == "Maé et Ellie")

        let three = InvoicePDF.Content(
            invoice: invoice(),
            services: [],
            children: [
                (id: 1, firstName: "Maé"),
                (id: 2, firstName: "Ellie"),
                (id: 3, firstName: "Zoé"),
            ]
        )

        #expect(InvoicePDF.title(for: three) == "Maé, Ellie et Zoé")
    }

    /// Les prestations marqueurs rattachent un enfant à la facture sans rien
    /// lui ajouter : il sort donc à 0.00, même sur une facture payée.
    @Test("Un enfant qui n'a qu'un marqueur est porté à zéro")
    func markersAmountToNothing() {
        let amounts = ChildStatementPDF.amounts(
            of: invoice(total: 1281),
            services: [
                service(childId: 24, priceId: 18, total: 1281),
                service(childId: 24, priceId: -1, total: 0),
                service(childId: 28, priceId: -1, total: 0),
            ]
        )

        #expect(amounts[24] == 1281)
        #expect(amounts[28] == 0)
    }

    @Test("Une facture impayée porte tout le monde à zéro")
    func unpaidAmountsToNothing() {
        let amounts = ChildStatementPDF.amounts(
            of: invoice(total: 1281, paid: 0),
            services: [service(childId: 24, priceId: 18, total: 1281)]
        )

        #expect(amounts[24] == 0)
    }

    /// Quatorze unités de hauteur sur la première page, trente sur les
    /// suivantes ; une journée en vaut 1,5 plus une par prestation. Et une page
    /// vide s'ajoute au-delà de onze, pour que le pied de page ait la place de
    /// tenir.
    @Test("Le découpage en pages suit les unités de hauteur")
    func pagination() {
        let days = { (count: Int) in
            (1 ... count).map { index in
                let date = String(format: "2026-08-%02d", index)

                return (date: date, services: [self.service(
                    childId: 24,
                    priceId: 1,
                    total: 10,
                    date: date
                )])
            }
        }

        // Quatre journées de 2,5 font 10 : une page, et le pied y tient.
        #expect(InvoicePDF.paginate(days(4)).count == 1)

        // Cinq font 12,5 : la page reste unique, mais le pied est chassé sur
        // une seconde, vide.
        let five = InvoicePDF.paginate(days(5))
        #expect(five.count == 2)
        #expect(five[1].isEmpty)

        // Sept font 17,5 : la sixième journée ouvre une page, où les deux
        // dernières tiennent sans chasser le pied.
        let seven = InvoicePDF.paginate(days(7))
        #expect(seven.count == 2)
        #expect(seven[0].count == 5)
        #expect(seven[1].count == 2)
    }

    @Test("Les deux documents tiennent sur des pages A4 portrait")
    func pageFormat() throws {
        let data = ChildStatementPDF.document(year: 2026, entries: [])
        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))
        let box = try #require(document.page(at: 1)).getBoxRect(.mediaBox)

        #expect(abs(box.width - 595.275_59) < 0.01)
        #expect(abs(box.height - 841.889_76) < 0.01)
    }
}
