import Testing
@testable import NannyPlus

/// Les règles de saisie du planning des congés.
struct VacationPeriodEditTests {
    private func period(_ start: String, _ end: String? = nil) -> VacationPeriod {
        VacationPeriod(start: start, end: end)
    }

    @Test("Reculer le début laisse la fin en place")
    func movingStartBackwards() {
        let moved = VacationPeriodEdit.movingStart(
            of: period("2026-04-13", "2026-04-20"),
            to: "2026-04-10"
        )

        #expect(moved.start == "2026-04-10")
        #expect(moved.end == "2026-04-20")
    }

    @Test("Pousser le début au-delà de la fin emmène la fin avec lui")
    func movingStartPastTheEnd() {
        let moved = VacationPeriodEdit.movingStart(
            of: period("2026-01-01", "2026-01-02"),
            to: "2026-01-05"
        )

        #expect(moved.start == "2026-01-05")
        #expect(moved.end == "2026-01-05")
    }

    @Test("Poser une fin avant le début tire le début avec elle")
    func settingAnEndBeforeTheStart() {
        let changed = VacationPeriodEdit.settingEnd(
            of: period("2026-05-20", "2026-05-25"),
            to: "2026-05-10"
        )

        #expect(changed.start == "2026-05-10")
        #expect(changed.end == "2026-05-10")
    }

    @Test("Refermer une période la ramène à une journée isolée")
    func closingAPeriod() {
        let changed = VacationPeriodEdit.settingEnd(of: period("2026-05-20", "2026-05-25"), to: nil)

        #expect(changed.start == "2026-05-20")
        #expect(changed.end == nil)
    }

    @Test("Le tri classe par début, puis la journée isolée avant la période")
    func sorting() {
        let sorted = VacationPeriodEdit.sorted([
            period("2026-05-01", "2026-05-03"),
            period("2026-01-01"),
            period("2026-05-01"),
            period("2026-05-01", "2026-05-02"),
        ])

        #expect(sorted.map(\.start) == ["2026-01-01", "2026-05-01", "2026-05-01", "2026-05-01"])
        #expect(sorted.map(\.end) == [nil, nil, "2026-05-02", "2026-05-03"])
    }

    @Test("Sans congé, « + » vise le 1er janvier de l'année affichée")
    func lastDayOfAnEmptyYear() {
        #expect(VacationPeriodEdit.lastDay(in: [], year: 2026) == "2026-01-01")
    }

    @Test("« + » retient la date la plus tardive, fins comprises")
    func lastDayIncludesEnds() {
        // La dernière période déborde sur 2027 : le congé créé y atterrit, et
        // disparaît donc de la liste de 2026. Défaut conservé.
        let periods = [period("2026-09-21"), period("2026-12-21", "2027-01-01")]

        #expect(VacationPeriodEdit.lastDay(in: periods, year: 2026) == "2027-01-01")
    }
}
