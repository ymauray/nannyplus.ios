import Foundation

/// Relevé d'un mois. `amount` est le brut, `netAmount` le montant après
/// application des déductions mensuelles.
struct MonthlyStatement: Identifiable, Hashable, Sendable {
    let year: Int
    let month: Int
    let amount: Double
    var netAmount: Double

    var id: String { "\(year)-\(month)" }

    /// « Janvier », « Février »… avec une majuscule initiale, comme le
    /// `DateFormat('MMMM').capitalize()` de Flutter.
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.dateFormat = "MMMM"

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            return ""
        }

        return formatter.string(from: date).capitalizedFirstLetter
    }
}

/// Une ligne du relevé mensuel : les prestations regroupées par tarif.
struct StatementLine: Identifiable, Hashable, Sendable {
    let priceLabel: String
    let priceAmount: Double
    let isFixedPrice: Int
    let hours: Int
    let minutes: Int
    let count: Int
    let total: Double

    var id: String { priceLabel }

    /// Un tarif horaire affiche « heures.minutes », un tarif fixe le nombre de
    /// prestations. Les minutes ne sont pas complétées par un zéro côté Flutter
    /// — « 12.5 » veut dire douze heures et cinq minutes. Défaut conservé.
    var quantity: String {
        isFixedPrice == 0 ? "\(hours).\(minutes)" : String(count)
    }
}

struct YearlyStatement: Identifiable, Hashable, Sendable {
    let year: Int
    var monthlyStatements: [MonthlyStatement]

    var id: Int { year }

    /// Le total de l'année est la somme des **nets** mensuels, pas le brut
    /// diminué d'une déduction annuelle.
    var netTotal: Double {
        monthlyStatements.reduce(0) { $0 + $1.netAmount }
    }
}

extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }

        return first.uppercased() + dropFirst()
    }
}
