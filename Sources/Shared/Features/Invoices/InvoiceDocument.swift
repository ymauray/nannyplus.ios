import UIKit

/// La coque commune à la facture et au relevé annuel d'un enfant : même page,
/// même en-tête, même logo, mêmes intitulés bleus, même tableau.
///
/// Les deux documents sont bâtis sur les mêmes widgets côté Flutter
/// (`invoice_view.dart` et `child_statement_view.dart`), au point que leurs
/// fonctions se recopient l'une l'autre ; on ne les écrit qu'une fois.
enum InvoiceDocument {
    /// A4 portrait, marge de 50 points sur les quatre côtés.
    static let pageSize = CGSize(width: 595.275_59, height: 841.889_76)
    static let margin: CGFloat = 50
    static var contentWidth: CGFloat { pageSize.width - 2 * margin }

    /// `PdfColors.blue` du paquet `pdf`.
    static let blue = UIColor(red: 0x21 / 255, green: 0x96 / 255, blue: 0xF3 / 255, alpha: 1)
    static let grey = UIColor(white: 0x9E / 255, alpha: 1)

    // MARK: Blocs

    /// Les deux lignes des réglages de facture, dans la police choisie, puis un
    /// espace de 45 points.
    static func header(at y: CGFloat, in ctx: CGContext) -> CGFloat {
        let preferences = AppPreferences.shared
        let line1 = PdfText.font(preferences.line1Font.postScriptName, size: 30)
        let line2 = PdfText.font(preferences.line2Font.postScriptName, size: 13)
        var y = y

        PdfText.draw(preferences.line1, font: line1, at: margin, baseline: y + line1.ascent, in: ctx)
        y += line1.lineHeight
        PdfText.draw(preferences.line2, font: line2, at: margin, baseline: y + line2.ascent, in: ctx)

        return y + line2.lineHeight + 45
    }

    /// Le cartouche encadré : texte de 17 points centré, 8 points de marge
    /// au-dessus et en dessous.
    static func titleBox(_ title: String, at y: CGFloat, in ctx: CGContext) -> CGFloat {
        let font = PdfText.helvetica(17)
        let height = font.lineHeight + 16
        let box = CGRect(x: margin, y: y, width: contentWidth, height: height)

        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(box)
        PdfText.draw(
            title,
            font: font,
            centeredIn: margin,
            width: contentWidth,
            baseline: y + 8 + font.ascent,
            in: ctx
        )

        return y + height
    }

    /// Un intitulé de colonne ou de bloc : gras, bleu, 14 points, suivi de 6
    /// points de blanc.
    static func blueTitle(
        _ text: String,
        at y: CGFloat,
        x: CGFloat,
        width: CGFloat = 0,
        alignment: NSTextAlignment = .left,
        in ctx: CGContext
    ) -> CGFloat {
        let font = PdfText.helveticaBold(14)
        draw(text, font: font, color: blue, x: x, width: width, alignment: alignment, top: y, in: ctx)

        return y + font.lineHeight + 6
    }

    /// Le logo, ancré en haut à droite de la zone de contenu, sur 100 points de
    /// haut.
    static func drawLogo(in ctx: CGContext) {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("logo")

        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return }

        let height: CGFloat = 100
        let width = image.size.width * height / image.size.height
        image.draw(in: CGRect(
            x: margin + contentWidth - width,
            y: margin,
            width: width,
            height: height
        ))

        _ = ctx
    }

    // MARK: Tableau

    /// Une cellule : une ou plusieurs lignes de texte, alignées ensemble.
    struct Cell {
        var lines: [String]
        var font: PdfText.Font
        var color: UIColor = .black
        var alignment: NSTextAlignment = .left
        /// Marge au-dessus et en dessous, ou seulement en dessous pour les
        /// intitulés bleus.
        var verticalPadding: CGFloat = 0
        var bottomPadding: CGFloat = 0

        init(
            _ text: String,
            font: PdfText.Font,
            color: UIColor = .black,
            alignment: NSTextAlignment = .left,
            verticalPadding: CGFloat = 0,
            bottomPadding: CGFloat = 0
        ) {
            self.init(
                [text],
                font: font,
                color: color,
                alignment: alignment,
                verticalPadding: verticalPadding,
                bottomPadding: bottomPadding
            )
        }

        init(
            _ lines: [String],
            font: PdfText.Font,
            color: UIColor = .black,
            alignment: NSTextAlignment = .left,
            verticalPadding: CGFloat = 0,
            bottomPadding: CGFloat = 0
        ) {
            self.lines = lines
            self.font = font
            self.color = color
            self.alignment = alignment
            self.verticalPadding = verticalPadding
            self.bottomPadding = bottomPadding
        }

        var width: CGFloat {
            lines.map { PdfText.width(of: $0, font: font) }.max() ?? 0
        }

        var height: CGFloat {
            CGFloat(lines.count) * font.lineHeight + 2 * verticalPadding + bottomPadding
        }
    }

    struct Row {
        var cells: [Cell]
        /// Filet sous la ligne, absent quand la couleur est nulle.
        var borderColor: UIColor?
    }

    /// Réplique de la mise en page d'un `pw.Table` dont toutes les colonnes sont
    /// en `IntrinsicColumnWidth` sans flex : la largeur intrinsèque de chaque
    /// colonne — la plus large de ses cellules — est **mise à l'échelle pour
    /// remplir la largeur disponible**, les proportions étant conservées.
    static func table(_ rows: [Row], at y: CGFloat, in ctx: CGContext) -> CGFloat {
        let columnCount = rows.map(\.cells.count).max() ?? 0

        guard columnCount > 0 else { return y }

        var intrinsic = [CGFloat](repeating: 0, count: columnCount)

        for row in rows {
            for (index, cell) in row.cells.enumerated() {
                intrinsic[index] = max(intrinsic[index], cell.width)
            }
        }

        let total = intrinsic.reduce(0, +)
        let widths = total > 0
            ? intrinsic.map { $0 / total * contentWidth }
            : [CGFloat](repeating: contentWidth / CGFloat(columnCount), count: columnCount)

        var y = y

        for row in rows {
            let height = row.cells.map(\.height).max() ?? 0
            var x = margin

            for (index, cell) in row.cells.enumerated() {
                var baseline = y + cell.verticalPadding + cell.font.ascent

                for line in cell.lines {
                    draw(
                        line,
                        font: cell.font,
                        color: cell.color,
                        x: x,
                        width: widths[index],
                        alignment: cell.alignment,
                        baseline: baseline,
                        in: ctx
                    )
                    baseline += cell.font.lineHeight
                }

                x += widths[index]
            }

            y += height

            if let borderColor = row.borderColor {
                ctx.setStrokeColor(borderColor.cgColor)
                ctx.setLineWidth(1)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: margin, y: y))
                ctx.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                ctx.strokePath()
            }
        }

        return y
    }

    // MARK: Dessin

    static func draw(
        _ text: String,
        font: PdfText.Font,
        color: UIColor = .black,
        x: CGFloat,
        width: CGFloat,
        alignment: NSTextAlignment,
        top: CGFloat,
        in ctx: CGContext
    ) {
        draw(
            text,
            font: font,
            color: color,
            x: x,
            width: width,
            alignment: alignment,
            baseline: top + font.ascent,
            in: ctx
        )
    }

    static func draw(
        _ text: String,
        font: PdfText.Font,
        color: UIColor = .black,
        x: CGFloat,
        width: CGFloat,
        alignment: NSTextAlignment,
        baseline: CGFloat,
        in ctx: CGContext
    ) {
        guard !text.isEmpty else { return }

        let textWidth = PdfText.width(of: text, font: font)
        let origin: CGFloat

        switch alignment {
        case .center: origin = x + (width - textWidth) / 2
        case .right: origin = x + width - textWidth
        default: origin = x
        }

        PdfText.draw(text, font: font, color: color, at: origin, baseline: baseline, in: ctx)
    }

    /// Un bloc de lignes ancré en bas de page, à gauche ou à droite.
    static func footerBlock(
        title: String,
        body: String,
        alignment: NSTextAlignment,
        in ctx: CGContext
    ) {
        guard !body.isEmpty else { return }

        let titleFont = PdfText.helveticaBold(14)
        let bodyFont = PdfText.helvetica(12)
        let lines = body.components(separatedBy: "\n")
        let height = titleFont.lineHeight + 6 + CGFloat(lines.count) * bodyFont.lineHeight
        var y = pageSize.height - margin - height

        draw(
            title,
            font: titleFont,
            color: blue,
            x: margin,
            width: contentWidth,
            alignment: alignment,
            top: y,
            in: ctx
        )
        y += titleFont.lineHeight + 6

        for line in lines {
            draw(
                line,
                font: bodyFont,
                x: margin,
                width: contentWidth,
                alignment: alignment,
                top: y,
                in: ctx
            )
            y += bodyFont.lineHeight
        }
    }
}
