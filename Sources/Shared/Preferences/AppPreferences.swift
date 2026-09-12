import Foundation

/// Réplique de `lib/utils/prefs_util.dart`.
///
/// Les clés sont identiques à celles de `shared_preferences` côté Flutter, mais
/// **pas** leur emplacement : le plugin Flutter préfixe chaque clé par `flutter.`
/// dans les `UserDefaults`. `Self.key(_:)` applique ce préfixe pour que l'app
/// native relise les réglages déjà enregistrés par la version Flutter.
final class AppPreferences: @unchecked Sendable {
    static let shared = AppPreferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static func key(_ name: String) -> String { "flutter.\(name)" }

    private func bool(_ name: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: Self.key(name)) as? Bool ?? fallback
    }

    private func set(_ value: Bool, for name: String) {
        defaults.set(value, forKey: Self.key(name))
    }

    var sortListByLastName: Bool {
        get { bool("sortListByLastName", default: true) }
        set { set(newValue, for: "sortListByLastName") }
    }

    var showFirstNameBeforeLastName: Bool {
        get { bool("showFirstNameBeforeLastName", default: true) }
        set { set(newValue, for: "showFirstNameBeforeLastName") }
    }

    var daysBeforeUnpaidInvoiceNotification: Int {
        get {
            defaults.object(forKey: Self.key("daysBeforeUnpaidInvoiceNotification")) as? Int ?? 10
        }
        set {
            defaults.set(newValue, forKey: Self.key("daysBeforeUnpaidInvoiceNotification"))
        }
    }

    // MARK: Personnalisation de la facture

    private func string(_ name: String) -> String {
        defaults.string(forKey: Self.key(name)) ?? ""
    }

    private func set(_ value: String, for name: String) {
        defaults.set(value, forKey: Self.key(name))
    }

    var line1: String {
        get { string("line1") }
        set { set(newValue, for: "line1") }
    }

    var line2: String {
        get { string("line2") }
        set { set(newValue, for: "line2") }
    }

    var conditions: String {
        get { string("conditions") }
        set { set(newValue, for: "conditions") }
    }

    var bankDetails: String {
        get { string("bankDetails") }
        set { set(newValue, for: "bankDetails") }
    }

    var name: String {
        get { string("name") }
        set { set(newValue, for: "name") }
    }

    var address: String {
        get { string("address") }
        set { set(newValue, for: "address") }
    }

    /// La police est stockée en deux clés, famille et chemin d'asset, comme
    /// côté Flutter. On conserve les deux pour que les réglages déjà
    /// enregistrés restent lisibles.
    var line1Font: InvoiceFont {
        get { InvoiceFont.named(string("line1FontFamily")) }
        set {
            set(newValue.family, for: "line1FontFamily")
            set(newValue.asset, for: "line1FontAsset")
        }
    }

    var line2Font: InvoiceFont {
        get { InvoiceFont.named(string("line2FontFamily")) }
        set {
            set(newValue.family, for: "line2FontFamily")
            set(newValue.asset, for: "line2FontAsset")
        }
    }

    /// Un encart d'aide reste visible tant qu'aucune clé ne le masque.
    func isHelpVisible(_ identifier: String) -> Bool {
        defaults.object(forKey: Self.key("help_\(identifier)")) == nil
    }

    func hideHelp(_ identifier: String) {
        defaults.set(false, forKey: Self.key("help_\(identifier)"))
    }

    /// Réplique du troisième élément du tiroir : supprime toutes les clés
    /// `help_*`, ce qui fait réapparaître les cartes d'aide.
    func resetHelpMessages() {
        removeKeys(withPrefix: Self.key("help_"))
    }

    /// `prefs.clear()` côté Flutter. Ne touche qu'aux clés écrites par
    /// `shared_preferences`, reconnaissables à leur préfixe.
    func clear() {
        removeKeys(withPrefix: "flutter.")
    }

    private func removeKeys(withPrefix prefix: String) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Gabarit du SMS de relance envoyé aux parents depuis le menu d'une
    /// facture. `{{date}}` et `{{total}}` y sont remplacés au moment de l'envoi.
    var notificationMessage: String {
        get {
            defaults.string(forKey: Self.key("notificationMessage"))
                ?? "Sauf erreur de notre part, nous n'avons pas reçu votre paiement pour la facture du {{date}} pour un montant de {{total}}. Merci de bien vouloir effectuer le paiement au plus vite."
        }
        set {
            defaults.set(newValue, forKey: Self.key("notificationMessage"))
        }
    }

    var showOnboarding: Bool {
        get { bool("showOnboarding", default: true) }
        set { set(newValue, for: "showOnboarding") }
    }
}
