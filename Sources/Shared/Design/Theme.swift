import SwiftUI

/// Réplique de `lib/src/constants.dart` et `lib/src/app_theme.dart`.
enum Theme {
    // MARK: Couleurs (constants.dart)

    static let almostBlack = Color(hex: 0x0A0A0A)
    static let almostWhite = Color(hex: 0xFFFFFF, opacity: 0xF2 / 255)
    static let primary = Color(hex: 0x03A5AA)
    static let onPrimary = almostWhite
    static let secondary = Color(hex: 0xF0BC00)
    static let onSecondary = almostWhite
    static let background = Color(hex: 0xF3F9FE)
    static let danger = Color(hex: 0xB71C1C)
    static let card = almostWhite

    /// `Colors.grey` de Material, utilisé pour les deux dernières lignes de la
    /// tuile et pour le titre des dossiers archivés.
    static let materialGrey = Color(hex: 0x9E9E9E)

    /// `Colors.black54`, couleur par défaut du sous-titre d'un `ListTile`.
    static let black54 = Color(white: 0, opacity: 0.54)

    /// `Colors.black87`, couleur de texte par défaut de Material en thème clair.
    static let black87 = Color(white: 0, opacity: 0.87)

    /// `canvasColor` du thème, fond du tiroir : `Colors.grey[50]`.
    static let drawerBackground = Color(hex: 0xFAFAFA)

    /// `Colors.yellow.shade600` et `shade800` : fond et bordure des encarts
    /// d'aide.
    static let helpBackground = Color(hex: 0xFDD835)
    static let helpBorder = Color(hex: 0xF9A825)

    /// `Colors.black54`, couleur du voile derrière le tiroir.
    static let scrim = Color(white: 0, opacity: 0.54)

    // MARK: Rayons et espacements

    static let defaultRadius: CGFloat = 12
    static let defaultPadding: CGFloat = 16
    static let smallPadding: CGFloat = 8

    /// `kMinInteractiveDimension`, hauteur du bandeau incurvé.
    static let headerHeight: CGFloat = 48
    static let headerSpacing: CGFloat = 12
}

// MARK: - Poppins

/// Le thème Flutter est bâti sur `GoogleFonts.poppins()` : c'est Poppins, et
/// non SF Pro, qui donne son allure à l'app. Les fichiers sont repris tels quels
/// de `assets/google_fonts/`.
enum Poppins {
    // `size:` et non `fixedSize:` : Flutter suit le réglage de taille de texte du
    // système, ces polices doivent en faire autant.
    static func regular(_ size: CGFloat) -> Font { .custom("Poppins-Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("Poppins-Medium", size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom("Poppins-Bold", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Poppins-Italic", size: size) }
    static func boldItalic(_ size: CGFloat) -> Font { .custom("Poppins-BoldItalic", size: size) }

    /// Les polices sont enregistrées à l'exécution plutôt que déclarées dans
    /// l'Info.plist, l'Info.plist étant généré par Xcode et ne pouvant recevoir
    /// le tableau `UIAppFonts` via un simple réglage de build.
    static func register() {
        let names = [
            "Poppins-Regular",
            "Poppins-Medium",
            "Poppins-Italic",
            "Poppins-Bold",
            "Poppins-BoldItalic",
        ]

        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Police absente du bundle : \(name).ttf")

                continue
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: -

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
