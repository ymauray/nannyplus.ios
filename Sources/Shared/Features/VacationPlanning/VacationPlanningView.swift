import SwiftUI

/// Réplique de `lib/views/vacation_planning/vacation_planning_view.dart` et de
/// `vacation_period_card.dart`.
///
/// Une carte par période de congé de l'année, dans l'ordre où la base les rend.
/// L'interrupteur bascule entre une journée isolée et une période, les crayons
/// ouvrent un sélecteur de date, la croix supprime sans confirmation.
///
/// **La saisie est déroutante et reste à revoir** : le bouton « + » ne demande
/// rien, il crée une journée à la dernière date connue, à corriger ensuite au
/// crayon. Reproduit tel quel pour l'instant.
struct VacationPlanningView: View {
    let onClose: () -> Void

    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var periods: [VacationPeriod] = []
    @State private var dateEdit: DateEdit?
    @State private var snackbar = SnackbarPresenter()

    private let repository = VacationPeriodRepository()

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Planning des congés", leadingSystemImage: "chevron.left") {
                Task {
                    await sort()
                    onClose()
                }
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

            CurvedHeader {
                HStack(spacing: 0) {
                    arrow("chevron.left") { Task { await changeYear(to: year - 1) } }

                    Button {
                        // Le retour à l'année en cours ne trie pas, là où les
                        // flèches trient. Incohérence conservée.
                        year = Calendar.current.component(.year, from: Date())
                        Task { await load() }
                    } label: {
                        Text(String(year))
                            .font(Poppins.bold(16))
                            .foregroundStyle(Theme.onPrimary)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()

                    arrow("chevron.right") { Task { await changeYear(to: year + 1) } }
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(periods) { period in
                        card(period)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .snackbar(snackbar)
        .background(Theme.background)
        .task { await load() }
        .sheet(item: $dateEdit) { edit in
            DatePickerSheet(edit: edit) { selected in
                Task { await apply(edit, date: selected) }
            }
        }
    }

    // MARK: Carte

    /// `UICard` : marges de 16 sur les côtés et 8 en haut et en bas, rayon 12,
    /// élévation 4, et 12 points de marge intérieure.
    private func card(_ period: VacationPeriod) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                dateLabel(
                    prefix: period.end == nil ? nil : "Du",
                    date: period.start,
                    edit: DateEdit(period: period, bound: .start)
                )

                Spacer(minLength: 0)

                Divider().frame(height: 24)

                Toggle("", isOn: Binding(
                    get: { period.end != nil },
                    set: { isRange in
                        Task { await setEnd(of: period, to: isRange ? period.start : nil) }
                    }
                ))
                .labelsHidden()
                .tint(Theme.secondary)
                .padding(.horizontal, Theme.smallPadding)

                Button { Task { await delete(period) } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.almostBlack)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }

            if let end = period.end {
                dateLabel(
                    prefix: "Au",
                    date: end,
                    edit: DateEdit(period: period, bound: .end)
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }

    private func dateLabel(prefix: String?, date: String, edit: DateEdit) -> some View {
        HStack(spacing: 0) {
            Text(prefix.map { "\($0) : \(Self.longDate(date))" } ?? Self.longDate(date))
                .font(Poppins.bold(16))
                .foregroundStyle(Theme.almostBlack)

            Button { dateEdit = edit } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.almostBlack)
                    // Taille d'un `IconButton` de Material.
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
    }

    private func arrow(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(Theme.onPrimary)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    // MARK: Actions

    /// « + » crée une journée isolée à la **dernière date connue** — le
    /// 1er janvier de l'année tant que la liste est vide, sinon la plus tardive
    /// des dates affichées.
    ///
    /// *Écart* : côté Flutter cette date se construit au fil du défilement,
    /// la liste étant paresseuse ; ajouter sans avoir déroulé jusqu'en bas
    /// retient donc une date plus ancienne. On prend ici toutes les périodes de
    /// l'année, c'est-à-dire ce que Flutter fait une fois la liste parcourue.
    private func add() async {
        let lastDay = VacationPeriodEdit.lastDay(in: periods, year: year)

        await perform { try await repository.create(start: lastDay) }
    }

    private func delete(_ period: VacationPeriod) async {
        await perform { try await repository.delete(period) }
    }

    /// Basculer l'interrupteur ouvre la période sur son propre jour de début,
    /// ou la referme sur une journée isolée.
    private func setEnd(of period: VacationPeriod, to end: String?) async {
        await perform {
            try await repository.update(VacationPeriodEdit.settingEnd(of: period, to: end))
        }
    }

    private func apply(_ edit: DateEdit, date: Date) async {
        let value = Self.shortDate(date)

        switch edit.bound {
        case .start:
            await perform {
                try await repository.update(
                    VacationPeriodEdit.movingStart(of: edit.period, to: value)
                )
            }
        case .end:
            await setEnd(of: edit.period, to: value)
        }
    }

    private func changeYear(to newYear: Int) async {
        await sort()
        year = newYear
        await load()
    }

    private func sort() async {
        do {
            try await repository.sort(periods)
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func load() async {
        do {
            periods = try await repository.loadForYear(year)
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        do {
            try await action()
            periods = try await repository.loadForYear(year)
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    // MARK: Dates

    struct DateEdit: Identifiable {
        enum Bound { case start, end }

        let id = UUID()
        let period: VacationPeriod
        let bound: Bound

        var value: String { bound == .start ? period.start : (period.end ?? period.start) }
    }

    private static let french = Locale(identifier: "fr_FR")

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = french
        formatter.dateFormat = "E d MMM yyyy"

        return formatter
    }()

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()

    static func longDate(_ value: String) -> String {
        guard let date = shortFormatter.date(from: value) else { return value }

        return longFormatter.string(from: date)
    }

    static func date(from value: String) -> Date {
        shortFormatter.date(from: value) ?? Date()
    }

    static func shortDate(_ date: Date) -> String {
        shortFormatter.string(from: date)
    }
}

/// Équivalent du `showDatePicker` de Material : un calendrier, et la date
/// retenue seulement si on valide.
private struct DatePickerSheet: View {
    let edit: VacationPlanningView.DateEdit
    let onSelect: (Date) -> Void

    @State private var date: Date
    @Environment(\.dismiss) private var dismiss

    init(edit: VacationPlanningView.DateEdit, onSelect: @escaping (Date) -> Void) {
        self.edit = edit
        self.onSelect = onSelect
        _date = State(initialValue: VacationPlanningView.date(from: edit.value))
    }

    /// De l'an dernier à dix ans d'ici, comme `firstDate` et `lastDate`.
    private var range: ClosedRange<Date> {
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: Date())
        let first = calendar.date(from: DateComponents(year: thisYear - 1, month: 1, day: 1))
        let last = calendar.date(from: DateComponents(year: thisYear + 10, month: 1, day: 1))

        return (first ?? Date()) ... (last ?? Date())
    }

    var body: some View {
        NavigationStack {
            DatePicker("", selection: $date, in: range, displayedComponents: .date)
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
                            onSelect(date)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.height(520), .large])
        .presentationBackground(Theme.background)
    }
}
