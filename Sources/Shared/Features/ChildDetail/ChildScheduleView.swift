import SwiftUI
import UIKit

/// Réplique de `lib/views/child_schedule/child_schedule_view.dart`.
///
/// La couleur de l'enfant dans les plannings, puis un créneau par carte : le
/// jour, l'heure de début, l'heure de fin, et de quoi dupliquer ou supprimer.
/// Le « + » de la barre de titre ajoute un créneau sans jour, de 7:00 à 18:00.
struct ChildScheduleView: View {
    let child: Child
    /// Appelé à la fermeture : les créneaux sont alors renumérotés, et la fiche
    /// doit se recharger.
    let onClose: () -> Void

    @State private var periods: [Period] = []
    @State private var color: Int64 = 0xFF9C_27B0
    @State private var isPickingColor = false
    @State private var timeEdit: TimeEdit?
    @State private var snackbar = SnackbarPresenter()

    private let repository = ScheduleRepository()

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: child.displayName, leadingSystemImage: "chevron.left") {
                Task { await close() }
            }
            .overlay(alignment: .trailing) {
                Button { Task { await add() } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .padding(.trailing, Theme.defaultPadding)
            }
            .zIndex(1)

            CurvedHeader { Text("Planning") }

            ScrollView {
                VStack(spacing: 0) {
                    colorCard

                    ForEach(periods) { period in
                        card(period)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .snackbar(snackbar)
        .task { await load() }
        .overlay {
            if let timeEdit {
                TimeInputDialog(
                    initialHours: timeEdit.hours,
                    initialMinutes: timeEdit.minutes,
                    // Une heure de la journée, pas une durée.
                    hours: Array(7 ... 19)
                ) { hours, minutes in
                    let edit = timeEdit
                    self.timeEdit = nil
                    Task { await apply(edit, hours: hours, minutes: minutes) }
                } onDismiss: {
                    self.timeEdit = nil
                }
            }
        }
        .sheet(isPresented: $isPickingColor) {
            ColorPickerSheet(color: Color(flutter: color)) { picked in
                Task { await updateColor(picked) }
            }
        }
    }

    // MARK: Cartes

    private var colorCard: some View {
        HStack(spacing: 0) {
            Text("Couleur")
                .font(Poppins.bold(16))
                .foregroundStyle(Theme.almostBlack)

            Text(" :")
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)

            Spacer().frame(width: 12)

            // `ColorIndicator` mesure 40 points de haut par défaut.
            Color(flutter: color)
                .frame(height: 40)
                .clipShape(.rect(cornerRadius: 4))
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture { isPickingColor = true }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }

    private func card(_ period: Period) -> some View {
        HStack(spacing: 0) {
            dayPicker(period)

            Text(" : ")
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)
                .fixedSize()

            Spacer(minLength: 0)

            time(period.fromLabel) { timeEdit = TimeEdit(period: period, isStart: true) }
            time(period.toLabel) { timeEdit = TimeEdit(period: period, isStart: false) }

            Divider().frame(height: 24).padding(.horizontal, 6)

            action("doc.on.doc") { Task { await duplicate(period) } }
            action("xmark") { Task { await delete(period) } }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }

    /// Le jour, dans un `DropdownButton` de Material : `titleMedium`, un filet
    /// dessous, et un premier choix vide qui laisse le créneau sans jour.
    private func dayPicker(_ period: Period) -> some View {
        Menu {
            ForEach(ScheduleDay.all, id: \.key) { day in
                Button(day.label) { Task { await updateDay(period, to: day.key) } }
            }
        } label: {
            HStack(spacing: Theme.smallPadding) {
                Text(ScheduleDay.label(of: period.day))
                    .font(Poppins.bold(16))
                    .foregroundStyle(Theme.almostBlack)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.almostBlack)
            }
            .frame(minWidth: 110, alignment: .leading)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.black54)
                    .frame(height: 1)
            }
            .frame(minHeight: 48)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .fixedSize()
    }

    private func time(_ label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)
                .fixedSize()

            Button(action: action) {
                Image(systemName: "clock")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.almostBlack)
                    // `IconButton` en densité compacte.
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
    }

    private func action(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24))
                .foregroundStyle(Theme.almostBlack)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    // MARK: Actions

    struct TimeEdit: Identifiable {
        let id = UUID()
        let period: Period
        let isStart: Bool

        var hours: Int { isStart ? period.hourFrom : period.hourTo }
        var minutes: Int { isStart ? period.minuteFrom : period.minuteTo }
    }

    private func apply(_ edit: TimeEdit?, hours: Int, minutes: Int) async {
        guard let edit else { return }

        var updated = edit.period

        if edit.isStart {
            updated.hourFrom = hours
            updated.minuteFrom = minutes
        } else {
            updated.hourTo = hours
            updated.minuteTo = minutes
        }

        await perform { try await repository.update(updated) }
    }

    private func updateDay(_ period: Period, to day: String) async {
        var updated = period
        updated.day = day

        await perform { try await repository.update(updated) }
    }

    private func add() async {
        guard let id = child.id else { return }

        await perform { try await repository.addPeriod(childId: id) }
    }

    private func duplicate(_ period: Period) async {
        await perform { try await repository.duplicate(period) }
    }

    private func delete(_ period: Period) async {
        await perform { try await repository.delete(period) }
    }

    private func updateColor(_ picked: Color) async {
        guard let id = child.id else { return }

        do {
            let value = picked.flutterValue
            try await repository.updateColor(childId: id, to: value)
            color = value
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    /// Le tri a lieu à la fermeture, comme côté Flutter.
    private func close() async {
        guard let id = child.id else { return onClose() }

        do {
            try await repository.sortPeriods(childId: id)
        } catch {
            snackbar.failure(String(describing: error))
        }

        onClose()
    }

    private func load() async {
        guard let id = child.id else { return }

        do {
            periods = try await repository.periods(childId: id)
            color = try await repository.color(childId: id)
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        guard let id = child.id else { return }

        do {
            try await action()
            periods = try await repository.periods(childId: id)
        } catch {
            snackbar.failure(String(describing: error))
        }
    }
}

// MARK: - Jours

/// Les jours qu'un créneau peut porter, le premier laissant le créneau sans
/// jour.
enum ScheduleDay {
    static let all: [(key: String, label: String)] = [
        ("", "------"),
        ("monday", "Lundi"),
        ("tuesday", "Mardi"),
        ("wednesday", "Mercredi"),
        ("thursday", "Jeudi"),
        ("friday", "Vendredi"),
    ]

    static func label(of day: String) -> String {
        all.first { $0.key == day }?.label ?? "------"
    }
}

// MARK: - Couleur

extension Color {
    /// Une `Color` de Flutter, soit un ARGB sur 32 bits.
    init(flutter value: Int64) {
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: Double((value >> 24) & 0xFF) / 255
        )
    }

    var flutterValue: Int64 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return Int64(round(alpha * 255)) << 24
            | Int64(round(red * 255)) << 16
            | Int64(round(green * 255)) << 8
            | Int64(round(blue * 255))
    }
}

/// Le choix de couleur du système, à la place de la palette Material du paquet
/// `flex_color_picker`.
private struct ColorPickerSheet: View {
    let color: Color
    let onSelect: (Color) -> Void

    @State private var selection: Color
    @Environment(\.dismiss) private var dismiss

    init(color: Color, onSelect: @escaping (Color) -> Void) {
        self.color = color
        self.onSelect = onSelect
        _selection = State(initialValue: color)
    }

    var body: some View {
        NavigationStack {
            ColorPicker("Couleur", selection: $selection, supportsOpacity: false)
                .font(Poppins.regular(16))
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
        .presentationDetents([.height(160)])
        .presentationBackground(Theme.background)
    }
}
