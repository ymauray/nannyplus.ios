import UIKit

/// Réplique de `_DocumentBuilder` dans `lib/src/statement_view/statement_view.dart`.
///
/// Le paquet `pdf` de Flutter compose en points avec une échelle de 0,75
/// appliquée à chaque taille de police ; on reprend les mêmes valeurs, déjà
/// multipliées. Le corps du document est en Helvetica, la police par défaut du
/// paquet — seules les deux lignes d'en-tête utilisent la police choisie dans
/// les réglages de facture.
enum StatementPDF {
    /// A4, marge de 50 points sur les quatre côtés.
    private static let pageSize = CGSize(width: 595.28, height: 841.89)
    private static let margin: CGFloat = 50

    private static let blue = UIColor(red: 0x21 / 255, green: 0x96 / 255, blue: 0xF3 / 255, alpha: 1)
    private static let rowGrey = UIColor(white: 0xEE / 255, alpha: 1)

    static func yearly(
        year: Int,
        months: [MonthlyStatement],
        deductions: [Deduction]
    ) -> Data {
        let preferences = AppPreferences.shared
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize)
        )

        return renderer.pdfData { context in
            context.beginPage()

            let width = pageSize.width - 2 * margin
            var y = margin

            y = drawHeader(preferences: preferences, at: y, width: width)
            y = drawTitle("Décompte annuel \(year)", at: y, width: width)
            y = drawMeta(preferences: preferences, at: y, width: width)

            let gross = months.reduce(0) { $0 + $1.amount }
            y = drawMonthsTable(months, at: y, width: width)
            y = drawTotal("Total brut : \(gross.twoDecimals)", at: y, width: width)
            y = drawDeductionsTable(
                deductions,
                gross: gross,
                monthCount: months.count,
                at: y,
                width: width
            )

            let net = netTotal(gross: gross, deductions: deductions, monthCount: months.count)
            _ = drawTotal("Total net : \(net.twoDecimals)", at: y, width: width)

            drawLogo(width: width)
        }
    }

    static func monthly(
        year: Int,
        month: Int,
        monthName: String,
        lines: [StatementLine],
        deductions: [Deduction]
    ) -> Data {
        let preferences = AppPreferences.shared
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize)
        )

        // Le relevé mensuel ne retient que les déductions mensuelles, là où le
        // décompte annuel les prend toutes.
        let applicable = deductions.filter(\.isMonthly)

        return renderer.pdfData { context in
            context.beginPage()

            let width = pageSize.width - 2 * margin
            var y = margin

            y = drawHeader(preferences: preferences, at: y, width: width)
            y = drawTitle("Relevé mensuel \(monthName) \(year)", at: y, width: width)
            y = drawMeta(preferences: preferences, at: y, width: width)

            let gross = lines.reduce(0) { $0 + $1.total }
            y = drawLinesTable(lines, at: y, width: width)
            y = drawTotal("Total brut : \(gross.twoDecimals)", at: y, width: width)
            y = drawDeductionsTable(
                applicable,
                gross: gross,
                monthCount: 1,
                at: y,
                width: width
            )

            let net = netTotal(gross: gross, deductions: applicable, monthCount: 1)
            _ = drawTotal("Total net : \(net.twoDecimals)", at: y, width: width)

            drawLogo(width: width)
        }
    }

    /// Le net reprend le calcul de `statementDeductionsRows` : un pourcentage
    /// porte sur le brut, un montant fixe mensuel est multiplié par le nombre de
    /// mois du décompte.
    static func netTotal(gross: Double, deductions: [Deduction], monthCount: Int) -> Double {
        deductions.reduce(gross) { running, deduction in
            deduction.isPercent
                ? running - gross * deduction.value / 100
                : running - deduction.value * Double(deduction.isMonthly ? monthCount : 1)
        }
    }

    // MARK: Blocs

    private static func drawHeader(
        preferences: AppPreferences,
        at y: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        var y = y
        y += draw(
            preferences.line1,
            at: CGPoint(x: margin, y: y),
            font: preferences.line1Font.uiFont(size: 22.5)
        )
        y += draw(
            preferences.line2,
            at: CGPoint(x: margin, y: y),
            font: preferences.line2Font.uiFont(size: 9.75)
        )

        return y + 45
    }

    private static func drawTitle(_ title: String, at y: CGFloat, width: CGFloat) -> CGFloat {
        let font = helvetica(12.75)
        let textHeight = title.size(withAttributes: [.font: font]).height
        let boxHeight = textHeight + 16

        let box = CGRect(x: margin, y: y, width: width, height: boxHeight)
        UIColor.black.setStroke()
        UIBezierPath(rect: box).stroke()

        _ = draw(
            title,
            in: CGRect(x: margin, y: y + 8, width: width, height: textHeight),
            font: font,
            alignment: .center
        )

        return y + boxHeight + 28
    }

    private static func drawMeta(
        preferences: AppPreferences,
        at y: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        var y = y
        let font = helvetica(10.5)

        if !preferences.name.isEmpty {
            y += draw(preferences.name, at: CGPoint(x: margin, y: y), font: font)
        }
        y += draw(preferences.address, at: CGPoint(x: margin, y: y), font: font, width: width)

        return y + 18
    }

    private static func drawMonthsTable(
        _ months: [MonthlyStatement],
        at y: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        var y = drawTableHeader(["Mois": CGFloat(0)], at: y, width: width, columns: [
            (title: "Mois", alignment: .left, x: margin, width: width * 0.7),
            (title: "Montant", alignment: .right, x: margin + width * 0.7, width: width * 0.3),
        ])

        // La première ligne est grisée : `highlight` bascule avant d'être lu.
        var highlighted = true
        let font = helvetica(10.5)

        for month in months {
            let rowHeight = font.lineHeight + 4

            if highlighted {
                rowGrey.setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: width, height: rowHeight)).fill()
            }
            highlighted.toggle()

            _ = draw(
                "\(month.monthName) \(month.year)",
                in: CGRect(x: margin, y: y + 2, width: width * 0.7, height: font.lineHeight),
                font: font,
                alignment: .left
            )
            _ = draw(
                month.amount.twoDecimals,
                in: CGRect(x: margin + width * 0.7, y: y + 2, width: width * 0.3, height: font.lineHeight),
                font: font,
                alignment: .right
            )

            y += rowHeight
        }

        return y
    }

    private static func drawLinesTable(
        _ lines: [StatementLine],
        at y: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let columns: [(title: String, alignment: NSTextAlignment, x: CGFloat, width: CGFloat)] = [
            ("Prestation", .left, margin, width * 0.40),
            ("Prix", .right, margin + width * 0.40, width * 0.20),
            ("Quantité", .center, margin + width * 0.60, width * 0.20),
            ("Montant", .right, margin + width * 0.80, width * 0.20),
        ]
        var y = drawTableHeader([:], at: y, width: width, columns: columns)

        let font = helvetica(10.5)
        var highlighted = true

        for line in lines {
            let rowHeight = font.lineHeight + 4

            if highlighted {
                rowGrey.setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: width, height: rowHeight)).fill()
            }
            highlighted.toggle()

            let values = [
                line.priceLabel,
                line.priceAmount.twoDecimals,
                line.quantity,
                line.total.twoDecimals,
            ]

            for (index, column) in columns.enumerated() {
                _ = draw(
                    values[index],
                    in: CGRect(x: column.x, y: y + 2, width: column.width, height: font.lineHeight),
                    font: font,
                    alignment: column.alignment
                )
            }

            y += rowHeight
        }

        return y
    }

    private static func drawDeductionsTable(
        _ deductions: [Deduction],
        gross: Double,
        monthCount: Int,
        at y: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let columns: [(title: String, alignment: NSTextAlignment, x: CGFloat, width: CGFloat)] = [
            ("Déduction", .left, margin, width * 0.34),
            ("Montant / Taux", .right, margin + width * 0.34, width * 0.24),
            ("Périodicité", .center, margin + width * 0.58, width * 0.20),
            ("Total", .right, margin + width * 0.78, width * 0.22),
        ]
        var y = drawTableHeader([:], at: y, width: width, columns: columns)

        let font = helvetica(10.5)
        var highlighted = true

        // Aucune déduction : une ligne grisée, comme côté Flutter.
        let rows: [[String]] = deductions.isEmpty
            ? [["Aucune déduction", "0.00    ", "-", "0.00"]]
            : deductions.map { deduction in
                let amount = deduction.isPercent
                    ? -gross * deduction.value / 100
                    : -deduction.value * Double(deduction.isMonthly ? monthCount : 1)

                return [
                    deduction.label,
                    "\(deduction.value.twoDecimals)\(deduction.isPercent ? " %" : "    ")",
                    deduction.isPercent ? "-" : (deduction.isMonthly ? "Mensuel" : "Annuel"),
                    amount.twoDecimals,
                ]
            }

        for row in rows {
            let rowHeight = font.lineHeight + 4

            if highlighted {
                rowGrey.setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: width, height: rowHeight)).fill()
            }
            highlighted.toggle()

            for (index, column) in columns.enumerated() {
                _ = draw(
                    row[index],
                    in: CGRect(x: column.x, y: y + 2, width: column.width, height: font.lineHeight),
                    font: font,
                    alignment: column.alignment
                )
            }

            y += rowHeight
        }

        return y
    }

    private static func drawTableHeader(
        _ unused: [String: CGFloat],
        at y: CGFloat,
        width: CGFloat,
        columns: [(title: String, alignment: NSTextAlignment, x: CGFloat, width: CGFloat)]
    ) -> CGFloat {
        let font = helveticaBold(10.5)

        for column in columns {
            _ = draw(
                column.title,
                in: CGRect(x: column.x, y: y, width: column.width, height: font.lineHeight),
                font: font,
                alignment: column.alignment,
                color: blue
            )
        }

        // Filet sous les en-têtes, puis un interligne de 2 points.
        let lineY = y + font.lineHeight + 6
        UIColor.black.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: lineY))
        path.addLine(to: CGPoint(x: margin + width, y: lineY))
        path.lineWidth = 1
        path.stroke()

        return lineY + 2
    }

    /// Les totaux occupent une bande de 70 points, texte centré verticalement et
    /// aligné à droite — c'est le `SizedBox(height: 70)` dans une `Row`.
    private static func drawTotal(_ text: String, at y: CGFloat, width: CGFloat) -> CGFloat {
        let font = helveticaBold(12)
        let band: CGFloat = 70

        _ = draw(
            text,
            in: CGRect(
                x: margin,
                y: y + (band - font.lineHeight) / 2,
                width: width,
                height: font.lineHeight
            ),
            font: font,
            alignment: .right,
            color: blue
        )

        return y + band
    }

    private static func drawLogo(width: CGFloat) {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("logo")

        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return }

        let height: CGFloat = 100
        let scaled = height / image.size.height
        let size = CGSize(width: image.size.width * scaled, height: height)
        image.draw(in: CGRect(
            x: margin + width - size.width,
            y: margin,
            width: size.width,
            height: size.height
        ))
    }

    // MARK: Dessin

    private static func helvetica(_ size: CGFloat) -> UIFont {
        UIFont(name: "Helvetica", size: size) ?? .systemFont(ofSize: size)
    }

    private static func helveticaBold(_ size: CGFloat) -> UIFont {
        UIFont(name: "Helvetica-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    }

    @discardableResult
    private static func draw(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        width: CGFloat = 400
    ) -> CGFloat {
        let rect = CGRect(x: point.x, y: point.y, width: width, height: .greatestFiniteMagnitude)

        return draw(text, in: rect, font: font, alignment: .left)
    }

    @discardableResult
    private static func draw(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        alignment: NSTextAlignment,
        color: UIColor = .black
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment

        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)

        return attributed.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        ).height
    }
}

extension InvoiceFont {
    func uiFont(size: CGFloat) -> UIFont {
        UIFont(name: postScriptName, size: size) ?? .systemFont(ofSize: size)
    }
}
