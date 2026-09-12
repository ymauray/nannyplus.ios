import SwiftUI

/// Réplique de `lib/src/price_list/price_list_view.dart`.
///
/// **L'écran s'appelle « Tarifs », et non « Prestations » comme côté Flutter.**
/// `fr.po` traduit `Price list` par « Prestations », le même mot que l'onglet du
/// dossier enfant qui liste les heures de garde — deux écrans, un seul nom.
/// Divergence assumée, sur décision de Yannick.
struct PriceListView: View {
    let onClose: () -> Void

    @State private var prices: [Price] = []
    /// Le réordonnancement passe par le mode édition d'iOS : les poignées du
    /// système apparaissent à droite. Côté Flutter, une poignée décorative
    /// permanente à gauche servait de prise ; on préfère ici le geste natif.
    @State private var isEditing = false
    @State private var priceToDelete: Price?
    @State private var editing: PriceFormView.Subject?
    @State private var snackbar = SnackbarPresenter()

    private let repository = PricesRepository()

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Tarifs", leadingSystemImage: "chevron.left") {
                onClose()
            }
            .overlay(alignment: .trailing) {
                Button {
                    withAnimation { isEditing.toggle() }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .padding(.trailing, Theme.defaultPadding)
            }
            .zIndex(1)

            CurvedHeader { Text("") }

            ZStack(alignment: .bottomTrailing) {
                list

                if !isEditing {
                    FloatingActionButton { editing = .creation }
                        .padding(Theme.defaultPadding)
                }
            }
        }
        .snackbar(snackbar)
        .background(Theme.background)
        .task { await load() }
        .alert(
            "Supprimer",
            isPresented: .constant(priceToDelete != nil),
            presenting: priceToDelete
        ) { price in
            Button("Oui") {
                priceToDelete = nil
                Task { await delete(price) }
            }
            Button("Non", role: .cancel) { priceToDelete = nil }
        } message: { _ in
            Text("Êtes-vous sûr de vouloir supprimer ce tarif ?")
        }
        // `fullscreenDialog: true` côté Flutter.
        .fullScreenCover(item: $editing) { subject in
            PriceFormView(subject: subject) { editing = nil }
                .onDisappear { Task { await load() } }
        }
    }

    /// Hors édition, les lignes occupent toute la largeur ; en édition, le
    /// système insère ses poignées à droite et les rétrécit d'autant.
    private var list: some View {
        List {
            ForEach(prices) { price in
                card(price)
                    .listRowInsets(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove { indices, destination in
                prices.move(fromOffsets: indices, toOffset: destination)
                Task { try? await repository.reorder(prices) }
            }

            // Dégage la place du bouton flottant.
            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    /// `Card` avec la surcharge de `CardScrollView` : coins quasi droits
    /// (rayon 1) et marge intérieure de 16.
    private func card(_ price: Price) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                // `fontWeight: FontWeight.bold` est demandé dans le Dart mais ne
                // s'applique pas : mesuré sur la référence, c'est du Poppins
                // Regular 14, soit `bodyMedium`.
                Text(price.label)
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.almostBlack)

                Text(price.detail)
                    .font(Poppins.regular(12))
                    .foregroundStyle(Theme.black54)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { editing = .modification(price) }

            Button {
                priceToDelete = price
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
                    .padding(.leading, Theme.defaultPadding)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
        .padding(Theme.defaultPadding)
        .background(.white, in: .rect(cornerRadius: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
    }

    // MARK: Données

    private func load() async {
        do {
            prices = try await repository.priceList()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func delete(_ price: Price) async {
        guard let id = price.id else { return }

        do {
            try await repository.delete(id: id)
            await load()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }
}
