import Testing
import Foundation
import CoreGraphics
@testable import NannyPlus

/// Les règles propres au planning annuel : congés, demi-journées, et la coupure
/// des initiales trop larges.
struct YearlyScheduleTests {
    @Test func aSingleDayVacationMatchesOnlyThatDay() {
        let day = VacationPeriod(start: "2026-05-01", end: nil)

        #expect(day.contains("2026-05-01"))
        #expect(!day.contains("2026-05-02"))
        #expect(!day.contains("2026-04-30"))
    }

    @Test func aVacationRangeIncludesBothEnds() {
        let range = VacationPeriod(start: "2026-07-20", end: "2026-08-07")

        #expect(range.contains("2026-07-20"))
        #expect(range.contains("2026-07-31"))
        #expect(range.contains("2026-08-07"))
        #expect(!range.contains("2026-08-08"))
        #expect(!range.contains("2026-07-19"))
    }

    @Test func aPeriodBelongsToTheHalfDayItStartsIn() {
        let long = Period(childId: 1, day: "monday", hourFrom: 8, minuteFrom: 0, hourTo: 17, minuteTo: 45)
        let noon = Period(childId: 1, day: "monday", hourFrom: 12, minuteFrom: 0, hourTo: 16, minuteTo: 30)

        // Une garde de 8:00 à 17:45 ne marque que le matin : le classement ne
        // regarde que l'heure de début. Défaut conservé.
        #expect(long.isMorning)
        #expect(!noon.isMorning)
    }

    /// Les initiales qui débordent de leur colonne passent sur deux lignes,
    /// lettre par lettre — c'est le cas de « WG » à cinq enfants.
    @Test func tooWideInitialsAreBrokenApart() {
        let font = PdfText.helvetica(5)
        let columnWidth: CGFloat = 41.240_81 / 5

        #expect(PdfText.wrap("MB", font: font, width: columnWidth) == ["MB"])
        #expect(PdfText.wrap("WG", font: font, width: columnWidth) == ["W", "G"])
    }

    @Test func documentIsASingleLandscapeA4Page() throws {
        let data = YearlySchedulePDF.document(year: 2026, schedule: .empty, vacationPeriods: [])
        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))

        #expect(document.numberOfPages == 1)

        let box = try #require(document.page(at: 1)).getBoxRect(.mediaBox)
        #expect(abs(box.width - 841.889_76) < 0.01)
        #expect(abs(box.height - 595.275_59) < 0.01)
    }
}
