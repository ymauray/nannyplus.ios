import CoreText
import UIKit

/// La composition de texte du paquet `pdf` de Flutter, reproduite à l'identique.
///
/// Trois règles la distinguent de ce que fait UIKit, et chacune décale le rendu
/// si on l'oublie :
///
/// - **Les hauteurs viennent des métriques AFM de la police**, pas de sa table
///   de mise en page. Une ligne mesure ascendante plus descendante, et la ligne
///   de base tombe à l'ascendante sous le haut du bloc.
/// - **Aucun crénage.** Core Text en applique d'office ; le paquet `pdf`
///   enchaîne les chasses.
/// - **Un mot trop long est coupé lettre par lettre**, sans césure.
enum PdfText {
    struct Font {
        let uiFont: UIFont
        let ascent: CGFloat
        let descent: CGFloat

        var lineHeight: CGFloat { ascent + descent }
    }

    /// Helvetica, la police par défaut du paquet `pdf`.
    static func helvetica(_ size: CGFloat) -> Font {
        Font(
            uiFont: UIFont(name: "Helvetica", size: size) ?? .systemFont(ofSize: size),
            ascent: 0.931 * size,
            descent: 0.225 * size
        )
    }

    static func helveticaBold(_ size: CGFloat) -> Font {
        Font(
            uiFont: UIFont(name: "Helvetica-Bold", size: size) ?? .boldSystemFont(ofSize: size),
            ascent: 0.962 * size,
            descent: 0.228 * size
        )
    }

    /// Une police quelconque du bundle — celles que proposent les réglages de
    /// facture. Ses métriques viennent de la police elle-même, comme le fait
    /// `Font.ttf` du paquet `pdf`, et non d'une table AFM.
    static func font(_ postScriptName: String, size: CGFloat) -> Font {
        guard let uiFont = UIFont(name: postScriptName, size: size) else {
            return helvetica(size)
        }

        let ctFont = uiFont as CTFont

        return Font(
            uiFont: uiFont,
            ascent: CTFontGetAscent(ctFont),
            descent: CTFontGetDescent(ctFont)
        )
    }

    static func helveticaOblique(_ size: CGFloat) -> Font {
        Font(
            uiFont: UIFont(name: "Helvetica-Oblique", size: size) ?? .italicSystemFont(ofSize: size),
            ascent: 0.931 * size,
            descent: 0.225 * size
        )
    }

    static func width(of string: String, font: Font) -> CGFloat {
        guard !string.isEmpty else { return 0 }

        return CGFloat(CTLineGetTypographicBounds(line(string, font), nil, nil, nil))
    }

    /// Découpe une chaîne sans espace, lettre par lettre, pour tenir dans une
    /// largeur donnée. Les initiales des enfants sont le seul cas où cela
    /// arrive : « WG » déborde d'une colonne de 8,25 points et passe sur deux
    /// lignes.
    static func wrap(_ string: String, font: Font, width available: CGFloat) -> [String] {
        guard width(of: string, font: font) > available else { return [string] }

        var lines: [String] = []
        var current = ""

        for character in string {
            let candidate = current + String(character)

            if !current.isEmpty, width(of: candidate, font: font) > available {
                lines.append(current)
                current = String(character)
            } else {
                current = candidate
            }
        }

        if !current.isEmpty { lines.append(current) }

        return lines
    }

    static func draw(
        _ string: String,
        font: Font,
        color: UIColor = .black,
        at x: CGFloat,
        baseline: CGFloat,
        in ctx: CGContext
    ) {
        guard !string.isEmpty else { return }

        ctx.saveGState()
        // Le contexte d'un PDF UIKit a l'axe des ordonnées vers le bas ; sans
        // cette symétrie, Core Text écrirait à l'envers.
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line(string, font, color), ctx)
        ctx.restoreGState()
    }

    static func draw(
        _ string: String,
        font: Font,
        centeredIn x: CGFloat,
        width available: CGFloat,
        baseline: CGFloat,
        in ctx: CGContext
    ) {
        draw(
            string,
            font: font,
            at: x + (available - width(of: string, font: font)) / 2,
            baseline: baseline,
            in: ctx
        )
    }

    private static func line(
        _ string: String,
        _ font: Font,
        _ color: UIColor = .black
    ) -> CTLine {
        let attributed = NSAttributedString(
            string: string,
            attributes: [
                .font: font.uiFont,
                .foregroundColor: color,
                .kern: 0,
            ]
        )

        return CTLineCreateWithAttributedString(attributed)
    }
}

extension CGContext {
    /// Une `Color` de Flutter, soit un ARGB sur 32 bits.
    func fill(_ rect: CGRect, flutterColor value: Int64) {
        setFillColor(UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: CGFloat((value >> 24) & 0xFF) / 255
        ).cgColor)
        fill(rect)
    }
}
