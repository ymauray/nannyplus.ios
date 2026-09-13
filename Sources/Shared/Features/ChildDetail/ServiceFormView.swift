import SwiftUI

/// Réplique de `lib/src/service_form/service_form.dart`.
///
/// Deux onglets pour une même journée : la grille tarifaire, où un « + » ajoute
/// le tarif au jour actif, et les prestations déjà ajoutées à ce jour. Le
/// calendrier de la barre de titre change de jour.
///
/// Le cubit calcule aussi une liste `services` de prestations récentes que la
/// vue ne lit jamais — code mort, non porté.
struct ServiceFormView: View {
    let child: Child
    /// Jour d'ouverture. `nil` pour une création : le titre change, et le jour
    /// actif devient aujourd'hui.
    let initialDate: String?
    let initialTab: Int
    let onClose: () -> Void

    @State private var date: Date
    @State private var selectedTab: Int
    @State private var prices: [Price] = []
    @State private var added: [Service] = []
    @State private var timeInput: TimeInput?
    @State private var serviceToDelete: Service?
    @State private var isPickingDate = false
    @State private var snackbar = SnackbarPresenter()

    private let repository = ServicesRepository()

    init(child: Child, initialDate: String? = nil, initialTab: Int, onClose: @escaping () -> Void) {
        self.child = child
        self.initialDate = initialDate
        self.initialTab = initialTab
        self.onClose = onClose
        _date = State(initialValue: initialDate.map(Self.date(from:)) ?? Date())
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppBar(
                title: initialDate == nil ? "Ajouter une prestation" : "Modifier une prestation",
                leadingSystemImage: "xmark"
            ) {
                onClose()
            }
            .overlay(alignment: .trailing) {
                Button { isPickingDate = true } label: {
                    // `Icons.edit_calendar` n'a pas d'équivalent : aucun symbole
                    // SF ne combine un calendrier et un crayon.
                    Image(systemName: "calendar")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .padding(.trailing, Theme.defaultPadding)
            }
            .zIndex(1)

            CurvedHeader {
                Text(Self.longDate(date))
            }

            TabBar(
                selection: $selectedTab,
                titles: ["Prestations", "Ajoutées (\(added.count))"]
            )

            ScrollView {
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        ForEach(prices) { price in
                            priceCard(price)
                        }
                    } else {
                        ForEach(added) { service in
                            serviceCard(service)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .snackbar(snackbar)
        .task { await load() }
        .overlay {
            if let timeInput {
                TimeInputDialog(
                    initialHours: timeInput.service?.hours,
                    initialMinutes: timeInput.service?.minutes
                ) { hours, minutes in
                    let input = timeInput
                    self.timeInput = nil
                    Task { await apply(input, hours: hours, minutes: minutes) }
                } onDismiss: {
                    self.timeInput = nil
                }
            }
        }
        .sheet(isPresented: $isPickingDate) {
            // De l'an dernier à l'an prochain, plus court que sur le planning
            // des congés.
            DatePickerSheet(date: date, yearsAhead: 1) { selected in
                date = selected
                Task { await load() }
            }
        }
        .alert(
            "Supprimer",
            isPresented: .constant(serviceToDelete != nil),
            presenting: serviceToDelete
        ) { service in
            Button("Non", role: .cancel) { serviceToDelete = nil }
            Button("Oui", role: .destructive) {
                let service = service
                serviceToDelete = nil
                Task { await delete(service) }
            }
        } message: { _ in
            Text("Êtes-vous sûr de vouloir supprimer cette entrée ?")
        }
    }

    // MARK: Cartes

    private func priceCard(_ price: Price) -> some View {
        card(title: price.label, detail: price.detail) {
            Button { add(price) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
    }

    private func serviceCard(_ service: Service) -> some View {
        card(title: service.priceLabel ?? "", detail: service.formDetail) {
            HStack(spacing: 0) {
                // Seule une prestation horaire se modifie : un tarif fixe n'a
                // rien à saisir.
                if service.isHourly {
                    Button { timeInput = TimeInput(service: service) } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                }

                Button { serviceToDelete = service } label: {
                    Image(systemName: "trash.square")
                        .font(.system(size: 24))
                        .foregroundStyle(.red)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
        }
    }

    /// `UICard` : titre en gras, détail en dessous, 12 points de marge partout,
    /// et l'action à droite.
    private func card(
        title: String,
        detail: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Poppins.bold(14))
                    .foregroundStyle(Theme.almostBlack)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                Text(detail)
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.almostBlack)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }

    // MARK: Actions

    /// Un tarif fixe s'ajoute sans rien demander ; un tarif horaire ouvre la
    /// saisie de la durée.
    private func add(_ price: Price) {
        if price.isFixedPrice {
            Task { await apply(TimeInput(price: price), hours: 0, minutes: 0) }
        } else {
            timeInput = TimeInput(price: price)
        }
    }

    private func apply(_ input: TimeInput?, hours: Int, minutes: Int) async {
        guard let input, let childId = child.id else { return }

        // Une durée nulle vaut annulation — sauf pour un tarif fixe, qui n'a
        // pas de durée.
        if hours == 0, minutes == 0, !(input.price?.isFixedPrice ?? false) {
            snackbar.failure("Saisie annulée")

            return
        }

        do {
            if let price = input.price, let priceId = price.id {
                try await repository.create(Service(
                    childId: childId,
                    date: Self.shortDate(date),
                    priceId: priceId,
                    priceLabel: price.label,
                    priceAmount: price.amount,
                    isFixedPrice: price.isFixedPrice ? 1 : 0,
                    hours: hours,
                    minutes: minutes,
                    total: price.isFixedPrice
                        ? price.amount
                        : price.amount * (Double(hours) + Double(minutes) / 60)
                ))
                snackbar.success("Ajouté avec succès")
                // L'ajout ramène sur l'onglet des tarifs, comme côté Flutter.
                selectedTab = 0
            } else if var service = input.service {
                service.hours = hours
                service.minutes = minutes
                service.total = (service.priceAmount ?? 0)
                    * (Double(hours) + Double(minutes) / 60)
                try await repository.update(service)
                snackbar.success("Modifié avec succès")
            }

            await load()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func delete(_ service: Service) async {
        do {
            try await repository.delete(service)
            snackbar.success("Supprimé avec succès")
            selectedTab = 1
            await load()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func load() async {
        guard let childId = child.id else { return }

        do {
            prices = try await PricesRepository().priceList()
            added = try await repository.services(childId: childId, date: Self.shortDate(date))
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    // MARK: Libellés

    struct TimeInput: Identifiable {
        let id = UUID()
        var price: Price?
        var service: Service?
    }

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")

        return formatter
    }()

    static func date(from value: String) -> Date {
        shortFormatter.date(from: value) ?? Date()
    }

    static func shortDate(_ date: Date) -> String {
        shortFormatter.string(from: date)
    }

    static func longDate(_ date: Date) -> String {
        longFormatter.string(from: date)
    }
}
