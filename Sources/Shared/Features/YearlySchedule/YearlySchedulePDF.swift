import UIKit

/// Réplique de `lib/views/yearly_schedule/yearly_schedule_pdf_view.dart`.
///
/// Une page A4 paysage : douze colonnes de mois, chacune avec son en-tête, une
/// ligne d'initiales, puis un rang par jour. Le rang porte le quantième, la
/// lettre du jour, et une case par enfant coupée en deux — matin en haut,
/// après-midi en bas.
///
/// **Un créneau est classé sur sa seule heure de début** (`isMorning`) : une
/// garde de 8:00 à 17:45 ne marque que le matin. Défaut conservé.
enum YearlySchedulePDF {
    /// A4 paysage, marge de 16 points sur les quatre côtés.
    private static let pageSize = CGSize(width: 841.889_76, height: 595.275_59)
    private static let margin: CGFloat = 16
    private static let rowHeight: CGFloat = 15
    /// Le quantième dans un carré, la lettre du jour dans les trois quarts.
    private static let dayNumberWidth: CGFloat = rowHeight
    private static let weekdayWidth: CGFloat = rowHeight * 0.75

    private static let titleFont = PdfText.helvetica(24)
    private static let monthFont = PdfText.helveticaBold(9)
    private static let dayFont = PdfText.helvetica(9)
    private static let nGramFont = PdfText.helvetica(5)
    /// `Padding(all: 8)` autour du nom de mois.
    private static let monthPadding: CGFloat = 8

    /// `PdfColors.grey`, `grey300` et `grey500` du paquet `pdf`. Le gris des
    /// congés et celui de l'en-tête sont le même ton.
    private static let grey: Int64 = 0xFF9E_9E9E
    private static let grey300: Int64 = 0xFFE0_E0E0
    private static let white: Int64 = 0xFFFF_FFFF

    private static let monthNames = [
        "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
        "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre",
    ]

    /// Clés de `periods.day` et initiale française affichée, du lundi au
    /// dimanche.
    private static let weekdays: [(key: String, letter: String)] = [
        ("monday", "L"), ("tuesday", "M"), ("wednesday", "M"), ("thursday", "J"),
        ("friday", "V"), ("saturday", "S"), ("sunday", "D"),
    ]

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt

        return calendar
    }()

    static func document(
        year: Int,
        schedule: Schedule,
        vacationPeriods: [VacationPeriod]
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize)
        )

        return renderer.pdfData { context in
            context.beginPage()

            let ctx = context.cgContext
            ctx.setLineWidth(1)
            ctx.setLineJoin(.miter)
            ctx.setStrokeColor(UIColor.black.cgColor)

            let width = pageSize.width - 2 * margin
            let columnWidth = width / 12

            // Titre, puis un espace de la hauteur d'un rang.
            var y = margin
            PdfText.draw(
                String(year),
                font: titleFont,
                centeredIn: margin,
                width: width,
                baseline: y + titleFont.ascent,
                in: ctx
            )
            y += titleFont.lineHeight + rowHeight

            for month in 1 ... 12 {
                column(
                    year: year,
                    month: month,
                    x: margin + CGFloat(month - 1) * columnWidth,
                    width: columnWidth,
                    top: y,
                    schedule: schedule,
                    vacationPeriods: vacationPeriods,
                    in: ctx
                )
            }
        }
    }

    // MARK: Colonne d'un mois

    private static func column(
        year: Int,
        month: Int,
        x: CGFloat,
        width: CGFloat,
        top: CGFloat,
        schedule: Schedule,
        vacationPeriods: [VacationPeriod],
        in ctx: CGContext
    ) {
        var y = top

        y = monthHeader(monthNames[month - 1], x: x, width: width, top: y, in: ctx)
        y = nGramsRow(schedule, x: x, width: width, top: y, in: ctx)

        for day in 1 ... daysIn(year: year, month: month) {
            dayRow(
                year: year,
                month: month,
                day: day,
                x: x,
                width: width,
                top: y,
                schedule: schedule,
                vacationPeriods: vacationPeriods,
                in: ctx
            )
            y += rowHeight
        }
    }

    /// Le nom du mois, en gras sur fond gris, entouré de 8 points de marge.
    private static func monthHeader(
        _ name: String,
        x: CGFloat,
        width: CGFloat,
        top: CGFloat,
        in ctx: CGContext
    ) -> CGFloat {
        let height = monthFont.lineHeight + 2 * monthPadding
        let cell = CGRect(x: x, y: top, width: width, height: height)

        ctx.fill(cell, flutterColor: grey)
        ctx.stroke(cell)
        PdfText.draw(
            name,
            font: monthFont,
            centeredIn: x + monthPadding,
            width: width - 2 * monthPadding,
            baseline: top + monthPadding + monthFont.ascent,
            in: ctx
        )

        return top + height
    }

    /// Les initiales des enfants, au-dessus de leurs colonnes. Les deux
    /// premières cases sont vides — celle du quantième est grise, celle de la
    /// lettre n'a pas de fond du tout, contrairement aux rangs de jours.
    private static func nGramsRow(
        _ schedule: Schedule,
        x: CGFloat,
        width: CGFloat,
        top: CGFloat,
        in ctx: CGContext
    ) -> CGFloat {
        let numberCell = CGRect(x: x, y: top, width: dayNumberWidth, height: rowHeight)
        ctx.fill(numberCell, flutterColor: grey300)
        ctx.stroke(numberCell)

        ctx.stroke(CGRect(
            x: x + dayNumberWidth,
            y: top,
            width: weekdayWidth,
            height: rowHeight
        ))

        let children = childrenCell(x: x, width: width, top: top)
        ctx.stroke(children)

        columns(of: schedule, in: children) { childId, cell in
            let nGram = schedule.childrenNames[childId] ?? ""
            let lines = PdfText.wrap(nGram, font: nGramFont, width: cell.width)
            let block = CGFloat(lines.count) * nGramFont.lineHeight
            var baseline = top + (rowHeight - block) / 2 + nGramFont.ascent

            for line in lines {
                // Une chaîne coupée remplit la largeur : le centrage n'a plus
                // de prise et les lignes s'alignent à gauche.
                if lines.count == 1 {
                    PdfText.draw(
                        line,
                        font: nGramFont,
                        centeredIn: cell.minX,
                        width: cell.width,
                        baseline: baseline,
                        in: ctx
                    )
                } else {
                    PdfText.draw(line, font: nGramFont, at: cell.minX, baseline: baseline, in: ctx)
                }

                baseline += nGramFont.lineHeight
            }
        }

        return top + rowHeight
    }

    private static func dayRow(
        year: Int,
        month: Int,
        day: Int,
        x: CGFloat,
        width: CGFloat,
        top: CGFloat,
        schedule: Schedule,
        vacationPeriods: [VacationPeriod],
        in ctx: CGContext
    ) {
        let weekday = weekdayIndex(year: year, month: month, day: day)
        let isWeekend = weekday >= 5
        let background = isWeekend ? grey300 : white
        let date = String(format: "%04d-%02d-%02d", year, month, day)
        let onVacation = vacationPeriods.contains { $0.contains(date) }

        let numberCell = CGRect(x: x, y: top, width: dayNumberWidth, height: rowHeight)
        ctx.fill(numberCell, flutterColor: grey300)
        ctx.stroke(numberCell)
        PdfText.draw(
            String(day),
            font: dayFont,
            centeredIn: numberCell.minX,
            width: numberCell.width,
            baseline: centeredBaseline(top: top, font: dayFont),
            in: ctx
        )

        let weekdayCell = CGRect(
            x: x + dayNumberWidth,
            y: top,
            width: weekdayWidth,
            height: rowHeight
        )
        ctx.fill(weekdayCell, flutterColor: background)
        ctx.stroke(weekdayCell)
        PdfText.draw(
            weekdays[weekday].letter,
            font: dayFont,
            centeredIn: weekdayCell.minX,
            width: weekdayCell.width,
            baseline: centeredBaseline(top: top, font: dayFont),
            in: ctx
        )

        let children = childrenCell(x: x, width: width, top: top)
        ctx.fill(children, flutterColor: background)
        ctx.stroke(children)

        // Les congés l'emportent sur tout, le week-end reste vide.
        if onVacation {
            ctx.fill(children, flutterColor: grey)

            return
        }
        guard !isWeekend else { return }

        let periods = schedule.periodsByDay(weekdays[weekday].key)

        columns(of: schedule, in: children) { childId, cell in
            let color = schedule.color(for: childId)

            for (index, morning) in [true, false].enumerated() {
                let occupied = periods.contains {
                    $0.childId == childId && $0.isMorning == morning
                }
                let half = CGRect(
                    x: cell.minX,
                    y: cell.minY + CGFloat(index) * cell.height / 2,
                    width: cell.width,
                    height: cell.height / 2
                )

                ctx.fill(half, flutterColor: occupied ? color : white)
            }
        }
    }

    // MARK: Découpages

    /// La case qui reste une fois le quantième et la lettre du jour posés.
    private static func childrenCell(x: CGFloat, width: CGFloat, top: CGFloat) -> CGRect {
        CGRect(
            x: x + dayNumberWidth + weekdayWidth,
            y: top,
            width: width - dayNumberWidth - weekdayWidth,
            height: rowHeight
        )
    }

    private static func columns(
        of schedule: Schedule,
        in cell: CGRect,
        content: (Int64, CGRect) -> Void
    ) {
        guard !schedule.childIds.isEmpty else { return }

        let columnWidth = cell.width / CGFloat(schedule.childIds.count)

        for (index, childId) in schedule.childIds.enumerated() {
            content(childId, CGRect(
                x: cell.minX + CGFloat(index) * columnWidth,
                y: cell.minY,
                width: columnWidth,
                height: cell.height
            ))
        }
    }

    private static func centeredBaseline(top: CGFloat, font: PdfText.Font) -> CGFloat {
        top + (rowHeight - font.lineHeight) / 2 + font.ascent
    }

    private static func daysIn(year: Int, month: Int) -> Int {
        guard
            let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let range = calendar.range(of: .day, in: .month, for: date)
        else { return 31 }

        return range.count
    }

    /// 0 pour lundi, 6 pour dimanche — l'ordre de `weekdays`, et celui des
    /// `DateTime.weekday` de Dart diminués de un.
    private static func weekdayIndex(year: Int, month: Int, day: Int) -> Int {
        guard
            let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return 0 }

        return (calendar.component(.weekday, from: date) + 5) % 7
    }
}
