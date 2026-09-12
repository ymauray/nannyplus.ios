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

    var showOnboarding: Bool {
        get { bool("showOnboarding", default: true) }
        set { set(newValue, for: "showOnboarding") }
    }
}
