import Testing
@testable import NannyPlus

/// Le détail d'une prestation et le total d'une journée.
struct ServiceTests {
    private func hourly(_ hours: Int, _ minutes: Int, amount: Double = 8) -> Service {
        Service(
            childId: 1,
            date: "2026-09-07",
            priceId: 1,
            priceLabel: "Heures semaine",
            priceAmount: amount,
            isFixedPrice: 0,
            hours: hours,
            minutes: minutes,
            total: amount * (Double(hours) + Double(minutes) / 60)
        )
    }

    @Test("Un tarif horaire affiche la durée et le taux")
    func hourlyDetail() {
        #expect(hourly(4, 30).priceDetail == "4h30 x 8.00")
    }

    @Test("Les minutes sont complétées par un zéro")
    func minutesArePadded() {
        // Le relevé mensuel, lui, écrit « 12.5 » pour douze heures cinq ; ici
        // les minutes sont bien sur deux chiffres.
        #expect(hourly(3, 0).priceDetail == "3h00 x 8.00")
        #expect(hourly(12, 5).priceDetail == "12h05 x 8.00")
    }

    @Test("Un tarif fixe n'affiche aucun détail")
    func fixedPriceHasNoDetail() {
        let meal = Service(
            childId: 1,
            date: "2026-09-07",
            priceId: 3,
            priceLabel: "Petit repas",
            priceAmount: 5,
            isFixedPrice: 1,
            total: 5
        )

        #expect(meal.priceDetail.isEmpty)
        #expect(!meal.isHourly)
    }

    @Test("Le total d'une journée additionne ses prestations")
    func dayTotal() {
        let day = ServiceDay(
            date: "2026-09-07",
            services: [
                hourly(4, 30),
                Service(
                    childId: 1,
                    date: "2026-09-07",
                    priceId: 3,
                    priceLabel: "Petit repas",
                    isFixedPrice: 1,
                    total: 5
                ),
            ]
        )

        #expect(day.total == 41)
    }
}
