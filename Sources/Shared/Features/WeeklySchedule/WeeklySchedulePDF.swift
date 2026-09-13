import CoreText
import UIKit

/// Réplique de `lib/views/weekly_schedule_pdf.dart`.
///
/// Une page A4 paysage : cinq jours en colonnes, une sous-colonne par enfant,
/// douze rangs d'une heure découpés en quarts d'heure. Un quart est peint de la
/// couleur de l'enfant dès qu'un créneau le couvre.
///
/// Le document est entièrement en **Helvetica 12**, police par défaut du paquet
/// `pdf` de Flutter. Les hauteurs de texte reprennent ses métriques AFM plutôt
/// que celles d'UIKit : `pdf` pose la ligne de base à partir de l'ascendante
/// déclarée dans la police, soit 0,931 cadratin, et non à partir de la hauteur
/// de ligne qu'emploie UIKit.
enum WeeklySchedulePDF {
    /// A4 paysage, marge de 16 points sur les quatre côtés.
    private static let pageSize = CGSize(width: 841.889_76, height: 595.275_59)
    private static let margin: CGFloat = 16
    private static let rowHeight: CGFloat = 38
    private static let hourColumnWidth: CGFloat = 64
    private static let fontSize: CGFloat = 12

    private static let ascent: CGFloat = 0.931 * fontSize
    private static let descent: CGFloat = 0.225 * fontSize
    /// Hauteur du bloc de texte tel que le compose `pdf` : ascendante plus
    /// descendante, soit 13,872 points à cette taille.
    private static let textHeight: CGFloat = ascent + descent

    private static let days: [(key: String, label: String)] = [
        ("monday", "Lundi"),
        ("tuesday", "Mardi"),
        ("wednesday", "Mercredi"),
        ("thursday", "Jeudi"),
        ("friday", "Vendredi"),
    ]

    /// Douze rangs, de 07:00 à 18:00.
    private static let firstHour = 7
    private static let hourCount = 12

    static func document(for schedule: Schedule) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize)
        )

        return renderer.pdfData { context in
            context.beginPage()

            let ctx = context.cgContext
            ctx.setLineWidth(1)
            ctx.setLineCap(.square)
            ctx.setStrokeColor(UIColor.black.cgColor)

            let width = pageSize.width - 2 * margin
            let dayWidth = (width - hourColumnWidth) / CGFloat(days.count)

            // Titre, puis un `SizedBox` de la hauteur d'un rang.
            var y = margin
            draw("Planning hebdomadaire", centeredIn: margin, width: width, baseline: y + ascent, in: ctx)
            y += textHeight + rowHeight

            // En-tête des jours puis des initiales, deux demi-rangs.
            let headerHeight = rowHeight / 2
            let headerBaseline = y + (headerHeight - textHeight) / 2 + ascent
            band(top: y, height: headerHeight, dayWidth: dayWidth, in: ctx) { index, x in
                draw(days[index].label, centeredIn: x, width: dayWidth, baseline: headerBaseline, in: ctx)
            }
            y += headerHeight

            let initialsBaseline = y + (headerHeight - textHeight) / 2 + ascent
            band(top: y, height: headerHeight, dayWidth: dayWidth, in: ctx) { _, x in
                columns(of: schedule, from: x, dayWidth: dayWidth) { childId, cellX, cellWidth in
                    draw(
                        schedule.childrenNames[childId] ?? "",
                        centeredIn: cellX,
                        width: cellWidth,
                        baseline: initialsBaseline,
                        in: ctx
                    )
                }
            }
            y += headerHeight

            // Les douze rangs horaires, séparés par un filet.
            for index in 0 ..< hourCount {
                let top = y + CGFloat(index) * rowHeight
                let hour = firstHour + index

                draw(
                    String(format: "%02d:00", hour),
                    centeredIn: margin,
                    width: hourColumnWidth,
                    baseline: top + (rowHeight - textHeight) / 2 + ascent,
                    in: ctx
                )

                band(top: top, height: rowHeight, dayWidth: dayWidth, in: ctx) { dayIndex, x in
                    hourCells(
                        of: schedule,
                        day: days[dayIndex].key,
                        hour: hour,
                        top: top,
                        x: x,
                        dayWidth: dayWidth,
                        in: ctx
                    )
                }

                if index < hourCount - 1 {
                    let separator = top + rowHeight
                    line(
                        from: CGPoint(x: margin, y: separator),
                        to: CGPoint(x: margin + width, y: separator),
                        in: ctx
                    )
                }
            }
        }
    }

    // MARK: Rangs

    /// Une bande allant d'un filet vertical à l'autre, les cinq jours entre les
    /// deux.
    ///
    /// L'ordre de dessin est celui de la `Row` de Flutter — filet, jour, filet,
    /// jour… — et il compte : les cellules d'un jour recouvrent la moitié du
    /// filet qui les précède, si bien que tous les traits verticaux paraissent
    /// deux fois plus fins que le dernier, seul à n'être suivi de rien. Défaut
    /// conservé.
    private static func band(
        top: CGFloat,
        height: CGFloat,
        dayWidth: CGFloat,
        in ctx: CGContext,
        content: (Int, CGFloat) -> Void
    ) {
        var x = margin + hourColumnWidth
        line(from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: top + height), in: ctx)

        for index in days.indices {
            content(index, x)
            x += dayWidth

            if index < days.count - 1 {
                line(from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: top + height), in: ctx)
            }
        }

        line(from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: top + height), in: ctx)
    }

    /// Les sous-colonnes d'un jour, une par enfant et toutes de même largeur.
    private static func columns(
        of schedule: Schedule,
        from x: CGFloat,
        dayWidth: CGFloat,
        content: (Int64, CGFloat, CGFloat) -> Void
    ) {
        guard !schedule.childIds.isEmpty else { return }

        let cellWidth = dayWidth / CGFloat(schedule.childIds.count)

        for (index, childId) in schedule.childIds.enumerated() {
            content(childId, x + CGFloat(index) * cellWidth, cellWidth)
        }
    }

    /// Les quatre quarts d'heure d'un rang, pour un jour donné. Chaque case est
    /// peinte, en blanc faute de créneau — c'est ainsi que le paquet `pdf`
    /// compose, et c'est ce qui recouvre les filets.
    private static func hourCells(
        of schedule: Schedule,
        day: String,
        hour: Int,
        top: CGFloat,
        x: CGFloat,
        dayWidth: CGFloat,
        in ctx: CGContext
    ) {
        let periods = schedule.periodsByDay(day)
        let quarterHeight = rowHeight / 4

        for quarter in 0 ..< 4 {
            let minute = quarter * 15

            columns(of: schedule, from: x, dayWidth: dayWidth) { childId, cellX, cellWidth in
                let covered = periods.contains {
                    $0.childId == childId && $0.covers(hour: hour, minute: minute)
                }

                ctx.setFillColor(
                    covered
                        ? color(schedule.color(for: childId)).cgColor
                        : UIColor.white.cgColor
                )
                ctx.fill(CGRect(
                    x: cellX,
                    y: top + CGFloat(quarter) * quarterHeight,
                    width: cellWidth,
                    height: quarterHeight
                ))
            }
        }
    }

    // MARK: Dessin

    /// Une `Color` de Flutter, soit un ARGB sur 32 bits.
    private static func color(_ value: Int64) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: CGFloat((value >> 24) & 0xFF) / 255
        )
    }

    private static func line(from start: CGPoint, to end: CGPoint, in ctx: CGContext) {
        ctx.beginPath()
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
    }

    /// Texte centré dans une colonne, posé sur une ligne de base explicite.
    ///
    /// On passe par Core Text plutôt que par `NSAttributedString.draw` : seule
    /// la ligne de base permet de retrouver au point près la composition du
    /// paquet `pdf`, dont la hauteur de ligne n'est pas celle d'UIKit.
    private static func draw(
        _ string: String,
        centeredIn x: CGFloat,
        width: CGFloat,
        baseline: CGFloat,
        in ctx: CGContext
    ) {
        guard !string.isEmpty else { return }

        let font = UIFont(name: "Helvetica", size: fontSize) ?? .systemFont(ofSize: fontSize)
        let attributed = NSAttributedString(
            string: string,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.black,
                // Le paquet `pdf` avance d'une chasse à l'autre sans crénage ;
                // Core Text, lui, en applique d'office. Sans ce zéro, « Vendredi »
                // et « AC » se resserrent d'un tiers de point.
                .kern: 0,
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

        ctx.saveGState()
        // Le contexte d'un PDF UIKit a l'axe des ordonnées vers le bas ; sans
        // cette symétrie, Core Text écrirait à l'envers.
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: x + (width - textWidth) / 2, y: baseline)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
