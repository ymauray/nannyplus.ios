import Testing
import Foundation
import CoreGraphics
@testable import NannyPlus

/// La règle qui décide de la couleur d'une case, et la coque du document.
struct WeeklyScheduleTests {
    private func period(from: (Int, Int), to: (Int, Int), day: String = "monday") -> Period {
        Period(
            childId: 1,
            day: day,
            hourFrom: from.0,
            minuteFrom: from.1,
            hourTo: to.0,
            minuteTo: to.1
        )
    }

    @Test func coversFromItsStartButNotItsEnd() {
        let slot = period(from: (8, 0), to: (12, 0))

        #expect(slot.covers(hour: 8, minute: 0))
        #expect(slot.covers(hour: 11, minute: 45))
        // La fin est exclue : un créneau qui s'arrête à midi ne peint pas 12:00.
        #expect(!slot.covers(hour: 12, minute: 0))
        #expect(!slot.covers(hour: 7, minute: 45))
    }

    @Test func coversPartialQuarters() {
        // 15:30 → 17:30 : le quart de 15:15 reste vide, celui de 15:30 est pris.
        let slot = period(from: (15, 30), to: (17, 30))

        #expect(!slot.covers(hour: 15, minute: 15))
        #expect(slot.covers(hour: 15, minute: 30))
        #expect(slot.covers(hour: 17, minute: 15))
        #expect(!slot.covers(hour: 17, minute: 30))
    }

    @Test func periodsAreFilteredByDay() {
        let schedule = Schedule(
            periods: [
                period(from: (8, 0), to: (9, 0), day: "monday"),
                period(from: (8, 0), to: (9, 0), day: "friday"),
            ]
        )

        #expect(schedule.periodsByDay("monday").count == 1)
        // Les libellés du PDF sont en anglais et capitalisés, la base en
        // minuscules : la comparaison abaisse la casse, comme côté Flutter.
        #expect(schedule.periodsByDay("Monday").count == 1)
        #expect(schedule.periodsByDay("sunday").isEmpty)
    }

    @Test func missingColourFallsBackToPurple() {
        let schedule = Schedule(scheduleColors: [ScheduleColor(childId: 1, color: 0xFF00_FF00)])

        #expect(schedule.color(for: 1) == 0xFF00_FF00)
        // Côté Flutter, `.first` lèverait une exception ; on retombe sur le
        // violet que `readColor` attribue d'office.
        #expect(schedule.color(for: 2) == 0xFF9C_27B0)
    }

    /// Une page A4 paysage, même document vide.
    @Test func documentIsASingleLandscapeA4Page() throws {
        let data = WeeklySchedulePDF.document(for: .empty)
        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))

        #expect(document.numberOfPages == 1)

        let box = try #require(document.page(at: 1)).getBoxRect(.mediaBox)
        #expect(abs(box.width - 841.889_76) < 0.01)
        #expect(abs(box.height - 595.275_59) < 0.01)
    }
}
