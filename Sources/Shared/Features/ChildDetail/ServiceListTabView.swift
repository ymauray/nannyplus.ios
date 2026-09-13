import SwiftUI

/// Réplique de `lib/src/tab_view/service_list_tab_view.dart`.
///
/// Une carte par journée, la plus récente en haut : la date, une corbeille qui
/// supprime la journée entière, le détail de chaque prestation, puis le total
/// du jour. Le bouton flottant ouvre la saisie sur aujourd'hui, toucher une
/// carte l'ouvre sur sa journée et sur l'onglet des prestations déjà ajoutées.
struct ServiceListTabView: View {
    let child: Child
    /// Le total du bandeau se recalcule après une suppression.
    let onChange: () -> Void

    @State private var days: [ServiceDay] = []
    @State private var dayToDelete: ServiceDay?
    @State private var form: FormRequest?
    @State private var snackbar = SnackbarPresenter()

    private let repository = ServicesRepository()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(days) { day in
                        card(day)
                    }
                }
            }
            .scrollIndicators(.hidden)

            FloatingActionButton {
                form = FormRequest(date: nil, tab: 0)
            }
            .padding(Theme.defaultPadding)
        }
        .snackbar(snackbar)
        .task { await load() }
        .fullScreenCover(item: $form) { request in
            ServiceFormView(
                child: child,
                initialDate: request.date,
                initialTab: request.tab
            ) {
                form = nil
                Task {
                    await load()
                    onChange()
                }
            }
        }
        .alert(
            "Supprimer",
            isPresented: .constant(dayToDelete != nil),
            presenting: dayToDelete
        ) { day in
            Button("Non", role: .cancel) { dayToDelete = nil }
            Button("Oui", role: .destructive) {
                let day = day
                dayToDelete = nil
                Task { await delete(day) }
            }
        } message: { _ in
            Text("Êtes-vous sûr de vouloir supprimer cette entière journée ?")
        }
    }

    // MARK: Carte d'une journée

    /// `UICard` : marges de 16 sur les côtés et 8 en haut et en bas, rayon 12,
    /// élévation 4.
    private func card(_ day: ServiceDay) -> some View {
        VStack(spacing: 0) {
            header(day)

            MaterialDivider()

            ForEach(day.services) { service in
                detail(service)
            }

            // Un filet court, sur le dernier sixième de la largeur, au-dessus
            // du total — la `Row` qui le porte n'a pas de marge latérale.
            FlexRow {
                Color.clear.frame(height: 0).flex(5)

                MaterialDivider()
                    .padding(.top, Theme.smallPadding)
                    .flex(1)
            }

            Text(day.total.twoDecimals)
                .font(Poppins.bold(16))
                .foregroundStyle(Theme.almostBlack)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .padding(.vertical, Theme.smallPadding)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
        .contentShape(.rect)
        .onTapGesture {
            form = FormRequest(date: day.date, tab: 1)
        }
    }

    private func header(_ day: ServiceDay) -> some View {
        HStack(spacing: 0) {
            Text(Self.longDate(day.date))
                .font(Poppins.bold(16))
                .foregroundStyle(Theme.almostBlack)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { dayToDelete = day } label: {
                Image(systemName: "trash.square")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
                    // `IconButton` en densité compacte.
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
        .padding(.leading, 12)
    }

    /// Les colonnes ne suivent pas les mêmes proportions selon le tarif : 2/2/1
    /// pour un tarif horaire, 5/1 pour un tarif fixe, la colonne du détail
    /// disparaissant avec lui. Seul le bord droit reste donc aligné.
    private func detail(_ service: Service) -> some View {
        FlexRow {
            Text(service.priceLabel ?? "")
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)
                .frame(maxWidth: .infinity, alignment: .leading)
                .flex(service.isHourly ? 2 : 5)

            Color.clear.frame(width: Theme.smallPadding, height: 0).flex(0)

            if service.isHourly {
                Text(service.priceDetail)
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .flex(2)

                Color.clear.frame(width: Theme.smallPadding, height: 0).flex(0)
            }

            Text(service.total.twoDecimals)
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .flex(1)
        }
        .padding(.horizontal, 12)
        .padding(.top, Theme.smallPadding)
    }

    struct FormRequest: Identifiable {
        let id = UUID()
        let date: String?
        let tab: Int
    }

    // MARK: Données

    private func load() async {
        guard let id = child.id else { return }

        do {
            days = try await repository.serviceDays(childId: id)
        } catch {
            snackbar.failure("Erreur lors du chargement des prestations")
        }
    }

    private func delete(_ day: ServiceDay) async {
        guard let id = child.id else { return }

        do {
            try await repository.deleteDay(childId: id, date: day.date)
            days = try await repository.serviceDays(childId: id)
            snackbar.success("Supprimé avec succès")
            onChange()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    // MARK: Dates

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()

    /// `DateFormat.yMMMMd` en français : « 10 septembre 2026 ».
    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")

        return formatter
    }()

    static func longDate(_ value: String) -> String {
        guard let date = shortFormatter.date(from: value) else { return value }

        return longFormatter.string(from: date)
    }
}
