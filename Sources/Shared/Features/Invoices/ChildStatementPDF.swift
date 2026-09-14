import UIKit

/// Réplique de `lib/src/invoice_view/child_statement_view.dart`.
///
/// Le relevé annuel d'un enfant : une ligne par facture de l'année, et **une
/// sous-ligne par enfant qu'elle couvre**, les prestations marqueurs rattachant
/// une fratrie à une même facture. Un enfant qui n'a que des marqueurs sort donc
/// à 0.00 en face d'une facture pourtant payée.
///
/// **Une facture impayée est notée 0.00**, comme l'annoncent les deux mentions
/// sous le titre.
enum ChildStatementPDF {
    /// Une facture de l'année, avec ce qu'il faut pour en dresser la ligne.
    struct Entry {
        let invoice: Invoice
        /// Les enfants de la facture, classés par identifiant croissant, avec
        /// leur nom affiché et le total de leurs prestations.
        let children: [(id: Int64, name: String, amount: Double)]
    }

    static func document(year: Int, entries: [Entry]) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: InvoiceDocument.pageSize)
        )

        return renderer.pdfData { context in
            context.beginPage()

            let ctx = context.cgContext
            var y = InvoiceDocument.margin

            y = InvoiceDocument.header(at: y, in: ctx)
            y = InvoiceDocument.titleBox("Décompte annuel \(year)", at: y, in: ctx)

            let note = PdfText.helvetica(10)
            for line in [
                "Les montants dus sont indiqués sur les factures correspondantes.",
                "Les factures impayées sont notées avec un montant de 0.00",
            ] {
                InvoiceDocument.draw(
                    line,
                    font: note,
                    x: InvoiceDocument.margin,
                    width: InvoiceDocument.contentWidth,
                    alignment: .center,
                    top: y,
                    in: ctx
                )
                y += note.lineHeight
            }

            y = InvoiceDocument.table(rows(for: entries), at: y + 28, in: ctx)

            // Le total vit dans une `Row` dont un `SizedBox` fixe la hauteur à
            // 70 points, et dont l'alignement transversal centre les enfants :
            // le texte tombe donc au milieu de la bande, pas en haut.
            let total = entries.reduce(0.0) { $0 + ($1.invoice.isPaid ? $1.invoice.total : 0) }
            let font = PdfText.helveticaBold(16)
            InvoiceDocument.draw(
                "Total : \(total.twoDecimals)",
                font: font,
                color: InvoiceDocument.blue,
                x: InvoiceDocument.margin,
                width: InvoiceDocument.contentWidth,
                alignment: .right,
                top: y + (70 - font.lineHeight) / 2,
                in: ctx
            )

            InvoiceDocument.drawLogo(in: ctx)
        }
    }

    private static func rows(for entries: [Entry]) -> [InvoiceDocument.Row] {
        let body = PdfText.helvetica(14)
        var rows: [InvoiceDocument.Row] = [
            InvoiceDocument.Row(
                cells: [
                    InvoiceDocument.Cell(
                        "Date de la facture",
                        font: PdfText.helveticaBold(14),
                        color: InvoiceDocument.blue,
                        bottomPadding: 6
                    ),
                    InvoiceDocument.Cell(
                        "Enfant",
                        font: PdfText.helveticaBold(14),
                        color: InvoiceDocument.blue,
                        bottomPadding: 6
                    ),
                    InvoiceDocument.Cell(
                        "Montant payé",
                        font: PdfText.helveticaBold(14),
                        color: InvoiceDocument.blue,
                        alignment: .right,
                        bottomPadding: 6
                    ),
                ],
                borderColor: .black
            ),
        ]

        for entry in entries {
            rows.append(InvoiceDocument.Row(
                cells: [
                    InvoiceDocument.Cell(
                        FrenchDate.long(entry.invoice.date),
                        font: body,
                        verticalPadding: 2
                    ),
                    InvoiceDocument.Cell(
                        entry.children.map(\.name),
                        font: body,
                        verticalPadding: 2
                    ),
                    InvoiceDocument.Cell(
                        entry.children.map { $0.amount.twoDecimals },
                        font: body,
                        alignment: .right,
                        verticalPadding: 2
                    ),
                ],
                borderColor: InvoiceDocument.grey
            ))
        }

        return rows
    }

    /// Le montant porté en face de chaque enfant : la somme de ses prestations
    /// sur la facture, ou zéro si la facture est impayée.
    static func amounts(of invoice: Invoice, services: [Service]) -> [Int64: Double] {
        services.reduce(into: [Int64: Double]()) { amounts, service in
            amounts[service.childId] = invoice.isPaid
                ? (amounts[service.childId] ?? 0) + service.total
                : 0
        }
    }
}
