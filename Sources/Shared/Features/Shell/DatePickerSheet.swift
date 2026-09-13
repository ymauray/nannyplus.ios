import SwiftUI

/// Équivalent du `showDatePicker` de Material : un calendrier, et la date
/// retenue seulement si on valide.
///
/// La fourchette commence toujours au 1er janvier de l'an dernier ; sa fin
/// varie selon l'écran, d'où [yearsAhead].
struct DatePickerSheet: View {
    let date: Date
    let yearsAhead: Int
    let onSelect: (Date) -> Void

    @State private var selection: Date
    @Environment(\.dismiss) private var dismiss

    init(date: Date, yearsAhead: Int, onSelect: @escaping (Date) -> Void) {
        self.date = date
        self.yearsAhead = yearsAhead
        self.onSelect = onSelect
        _selection = State(initialValue: date)
    }

    private var range: ClosedRange<Date> {
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: Date())
        let first = calendar.date(from: DateComponents(year: thisYear - 1, month: 1, day: 1))
        let last = calendar.date(from: DateComponents(year: thisYear + yearsAhead, month: 1, day: 1))

        return (first ?? Date()) ... (last ?? Date())
    }

    var body: some View {
        NavigationStack {
            DatePicker("", selection: $selection, in: range, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.primary)
                .padding(Theme.defaultPadding)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Theme.background)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK") {
                            onSelect(selection)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.height(520), .large])
        .presentationBackground(Theme.background)
    }
}
