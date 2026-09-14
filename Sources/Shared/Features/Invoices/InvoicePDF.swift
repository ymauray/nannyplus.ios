import UIKit

/// Réplique de `lib/src/invoice_view/invoice_view.dart`.
///
/// Une facture peut couvrir **plusieurs enfants** : chacun y est rattaché par
/// une prestation marqueur à `priceId = -1`, de libellé vide et de total nul.
/// Le cartouche du titre les nomme tous ; le tableau, lui, écarte les marqueurs
/// et ne montre donc que les vraies prestations.
enum InvoicePDF {
    /// Ce que la vue doit rassembler avant de composer le document.
    struct Content {
        let invoice: Invoice
        /// Toutes les prestations de la facture, marqueurs compris.
        let services: [Service]
        /// Prénom de chaque enfant concerné, marqueurs compris, dans l'ordre
        /// des prestations.
        let children: [(id: Int64, firstName: String)]
    }

    static func document(for content: Content) -> Data {
        let preferences = AppPreferences.shared
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: InvoiceDocument.pageSize)
        )
        let days = groupedByDay(content.services.filter { $0.priceId >= 0 })
        let pages = paginate(days)

        return renderer.pdfData { context in
            for (index, page) in pages.enumerated() {
                context.beginPage()

                let ctx = context.cgContext
                var y = InvoiceDocument.margin

                if index == 0 {
                    y = InvoiceDocument.header(at: y, in: ctx)
                    y = InvoiceDocument.titleBox(title(for: content), at: y, in: ctx) + 28
                    y = meta(content.invoice, at: y, in: ctx) + 18
                    y = total(content.invoice, at: y, in: ctx) + 42
                }

                if !page.isEmpty {
                    _ = InvoiceDocument.table(
                        rows(for: page, content: content),
                        at: y,
                        in: ctx
                    )
                }

                if index == 0 {
                    InvoiceDocument.drawLogo(in: ctx)
                }

                if index == pages.count - 1 {
                    InvoiceDocument.footerBlock(
                        title: "Détails bancaires",
                        body: preferences.bankDetails,
                        alignment: .left,
                        in: ctx
                    )
                    InvoiceDocument.footerBlock(
                        title: "Adresse",
                        body: preferences.address,
                        alignment: .right,
                        in: ctx
                    )
                }
            }
        }
    }

    // MARK: Contenu

    /// Un seul enfant : son nom tel que l'affiche l'app, dans l'ordre réglé.
    /// Plusieurs : leurs prénoms, le dernier amené par « et ».
    static func title(for content: Content) -> String {
        guard content.children.count > 1 else {
            let invoice = content.invoice

            return AppPreferences.shared.showFirstNameBeforeLastName
                ? "\(invoice.childFirstName) \(invoice.childLastName)"
                    .trimmingCharacters(in: .whitespaces)
                : "\(invoice.childLastName) \(invoice.childFirstName)"
                    .trimmingCharacters(in: .whitespaces)
        }

        let names = content.children.map(\.firstName)

        return "\(names.dropLast().joined(separator: ", ")) et \(names[names.count - 1])"
    }

    private static func meta(_ invoice: Invoice, at y: CGFloat, in ctx: CGContext) -> CGFloat {
        let half = InvoiceDocument.contentWidth / 2
        let body = PdfText.helvetica(14)
        let label = PdfText.helveticaBold(14)
        var left = y

        // Les intitulés du bloc méta sont des textes nus, sans la marge de 6
        // points que porte l'intitulé d'une colonne.
        func metaLabel(_ text: String, at y: CGFloat, x: CGFloat, alignment: NSTextAlignment) -> CGFloat {
            InvoiceDocument.draw(
                text,
                font: label,
                color: InvoiceDocument.blue,
                x: x,
                width: half,
                alignment: alignment,
                top: y,
                in: ctx
            )

            return y + label.lineHeight
        }

        left = metaLabel("Numéro de facture", at: left, x: InvoiceDocument.margin, alignment: .left)
        InvoiceDocument.draw(
            String(format: "%06d", invoice.number),
            font: body,
            x: InvoiceDocument.margin,
            width: half,
            alignment: .left,
            top: left,
            in: ctx
        )
        left += body.lineHeight + 8

        left = metaLabel("Date", at: left, x: InvoiceDocument.margin, alignment: .left)
        InvoiceDocument.draw(
            FrenchDate.long(invoice.date),
            font: body,
            x: InvoiceDocument.margin,
            width: half,
            alignment: .left,
            top: left,
            in: ctx
        )
        left += body.lineHeight

        if !invoice.hourCredits.isEmpty {
            left += 8
            left = metaLabel("Crédits d'heures", at: left, x: InvoiceDocument.margin, alignment: .left)
            InvoiceDocument.draw(
                invoice.hourCredits,
                font: body,
                x: InvoiceDocument.margin,
                width: half,
                alignment: .left,
                top: left,
                in: ctx
            )
            left += body.lineHeight
        }

        var right = metaLabel(
            "Facturé à",
            at: y,
            x: InvoiceDocument.margin + half,
            alignment: .right
        )

        for line in ([invoice.parentsName] + invoice.address.components(separatedBy: "\n")) {
            InvoiceDocument.draw(
                line,
                font: body,
                x: InvoiceDocument.margin + half,
                width: half,
                alignment: .right,
                top: right,
                in: ctx
            )
            right += body.lineHeight
        }

        return max(left, right)
    }

    private static func total(_ invoice: Invoice, at y: CGFloat, in ctx: CGContext) -> CGFloat {
        let font = PdfText.helveticaBold(16)
        let amount = invoice.total.twoDecimals
        let amountWidth = PdfText.width(of: amount, font: font)
        let labelWidth = InvoiceDocument.contentWidth - amountWidth

        InvoiceDocument.draw(
            "Total TTC : ",
            font: font,
            color: InvoiceDocument.blue,
            x: InvoiceDocument.margin,
            width: labelWidth,
            alignment: .right,
            top: y,
            in: ctx
        )
        InvoiceDocument.draw(
            amount,
            font: font,
            x: InvoiceDocument.margin + labelWidth,
            width: amountWidth,
            alignment: .right,
            top: y,
            in: ctx
        )

        let credits = PdfText.helvetica(12)
        InvoiceDocument.draw(
            "Crédit d'heure : \(invoice.hourCredits)",
            font: credits,
            x: InvoiceDocument.margin,
            width: InvoiceDocument.contentWidth,
            alignment: .right,
            top: y + font.lineHeight,
            in: ctx
        )

        return y + font.lineHeight + credits.lineHeight
    }

    /// Une ligne par journée, puis une par prestation de cette journée.
    private static func rows(
        for days: [(date: String, services: [Service])],
        content: Content
    ) -> [InvoiceDocument.Row] {
        let body = PdfText.helvetica(14)
        let single = content.children.count == 1
        var rows: [InvoiceDocument.Row] = [
            InvoiceDocument.Row(
                cells: ["Date", "Prestation", "Heures", "Prix"].enumerated().map { index, title in
                    InvoiceDocument.Cell(
                        title,
                        font: PdfText.helveticaBold(14),
                        color: InvoiceDocument.blue,
                        alignment: index == 2 ? .center : (index == 3 ? .right : .left),
                        bottomPadding: 6
                    )
                },
                borderColor: .black
            ),
        ]

        for day in days {
            rows.append(InvoiceDocument.Row(
                cells: [InvoiceDocument.Cell(FrenchDate.long(day.date), font: body, verticalPadding: 8)],
                borderColor: InvoiceDocument.grey
            ))

            for service in day.services {
                let hours = service.isHourly
                    ? "\(service.hours ?? 0)h\(String(format: "%02d", service.minutes ?? 0))"
                        + " x \((service.priceAmount ?? 0).twoDecimals)"
                    : "-"

                rows.append(InvoiceDocument.Row(
                    cells: [
                        // La colonne du prénom reste vide tant que la facture ne
                        // couvre qu'un enfant.
                        InvoiceDocument.Cell(
                            single ? "" : firstName(of: service, in: content),
                            font: PdfText.helveticaOblique(12),
                            verticalPadding: 4
                        ),
                        InvoiceDocument.Cell(service.priceLabel ?? "Dummy service", font: body, verticalPadding: 4),
                        InvoiceDocument.Cell(hours, font: body, alignment: .center, verticalPadding: 4),
                        InvoiceDocument.Cell(service.total.twoDecimals, font: body, alignment: .right, verticalPadding: 4),
                    ],
                    borderColor: nil
                ))
            }
        }

        return rows
    }

    private static func firstName(of service: Service, in content: Content) -> String {
        content.children.first { $0.id == service.childId }?.firstName ?? ""
    }

    // MARK: Pagination

    static func groupedByDay(_ services: [Service]) -> [(date: String, services: [Service])] {
        Dictionary(grouping: services, by: \.date)
            .map { (date: $0.key, services: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Réplique du découpage en pages : quatorze unités de hauteur sur la
    /// première page, trente sur les suivantes, une unité et demie par journée
    /// plus une par prestation. Une page vide s'ajoute si le pied de page n'a
    /// plus la place de tenir.
    static func paginate(
        _ days: [(date: String, services: [Service])]
    ) -> [[(date: String, services: [Service])]] {
        var pages: [[(date: String, services: [Service])]] = [[]]
        var maxHeight = 14.0
        var currentHeight = 0.0

        for day in days {
            let height = 1.5 + Double(day.services.count)

            if height + currentHeight > maxHeight {
                pages.append([])
                maxHeight = 30
                currentHeight = 0
            }

            currentHeight += height
            pages[pages.count - 1].append(day)
        }

        if currentHeight > 11 {
            pages.append([])
        }

        return pages
    }
}
