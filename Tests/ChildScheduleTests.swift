import Testing
import SwiftUI
@testable import NannyPlus

/// L'ordre du planning d'un enfant, ses libellés et sa couleur.
struct ChildScheduleTests {
    private func period(_ day: String, _ from: (Int, Int), _ to: (Int, Int)) -> Period {
        Period(
            childId: 1,
            day: day,
            hourFrom: from.0,
            minuteFrom: from.1,
            hourTo: to.0,
            minuteTo: to.1
        )
    }

    @Test("Les heures s'écrivent sur deux chiffres")
    func timesArePadded() {
        let slot = period("monday", (8, 0), (17, 30))

        #expect(slot.fromLabel == "08:00")
        #expect(slot.toLabel == "17:30")
    }

    @Test("Le tri classe par jour, puis par début, puis par fin")
    func sortingFollowsTheWeek() {
        let sorted = [
            period("tuesday", (8, 0), (12, 0)),
            period("monday", (15, 30), (17, 30)),
            period("monday", (12, 0), (13, 15)),
            period("monday", (12, 0), (13, 0)),
        ].sorted(by: Period.isBefore)

        #expect(sorted.map(\.day) == ["monday", "monday", "monday", "tuesday"])
        #expect(sorted.map(\.fromLabel) == ["12:00", "12:00", "15:30", "08:00"])
        #expect(sorted[0].toLabel == "13:00")
    }

    @Test("Un créneau sans jour passe en dernier")
    func daylessGoesLast() {
        let sorted = [period("", (7, 0), (18, 0)), period("friday", (8, 0), (9, 0))]
            .sorted(by: Period.isBefore)

        #expect(sorted.map(\.day) == ["friday", ""])
    }

    @Test("Le premier choix du menu laisse le créneau sans jour")
    func dayLabels() {
        #expect(ScheduleDay.label(of: "") == "------")
        #expect(ScheduleDay.label(of: "wednesday") == "Mercredi")
        // Samedi et dimanche ne sont pas proposés, bien que la base les accepte.
        #expect(ScheduleDay.label(of: "saturday") == "------")
    }

    @Test("Une couleur fait l'aller-retour avec l'entier de Flutter")
    func colourRoundTrip() {
        // L'orange de Maé, `0xFFFFAB40`.
        let orange: Int64 = 0xFFFF_AB40

        #expect(Color(flutter: orange).flutterValue == orange)
    }
}
