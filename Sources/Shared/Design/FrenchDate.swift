import Foundation

/// Les deux formats de date de l'app : celui de la base, `yyyy-MM-dd`, et celui
/// que lit l'utilisatrice, « 24 août 2026 » — le `DateFormat.yMMMMd` de Flutter.
enum FrenchDate {
    /// « 24 août 2026 », à partir d'une date de la base.
    static func long(_ value: String?) -> String {
        guard let value, let date = short.date(from: value) else { return value ?? "" }

        return long(date)
    }

    static func long(_ date: Date) -> String {
        longFormatter.string(from: date)
    }

    static func date(from value: String) -> Date? {
        short.date(from: value)
    }

    /// `yyyy-MM-dd`, le format que porte la base.
    static func short(_ date: Date) -> String {
        short.string(from: date)
    }

    private static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")

        return formatter
    }()
}
