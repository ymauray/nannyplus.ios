import SwiftUI

/// Réplique de `lib/views/main_tab_view.dart`.
///
/// La barre d'onglets est dessinée à la main plutôt que confiée à `TabView` :
/// sur macOS, `TabView` place ses onglets en haut de la fenêtre, ce qui ne
/// correspond ni au `BottomNavigationBar` de Flutter ni au rendu iOS.
struct MainTabView: View {
    @State private var model = ChildListViewModel()
    @State private var selection = 0

    /// Le bandeau bascule entre total à facturer et total à encaisser au
    /// toucher (`showPendingInvoiceProvider`). L'état n'est pas persisté.
    @State private var showPendingInvoice = false

    @State private var isDrawerOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            main

            if isDrawerOpen {
                Theme.scrim
                    .ignoresSafeArea()
                    .onTapGesture { isDrawerOpen = false }
                    .transition(.opacity)

                MainDrawer(
                    onDismiss: { isDrawerOpen = false },
                    onResetHelpMessages: { AppPreferences.shared.resetHelpMessages() },
                    onResetDatabase: { Task { await model.resetDatabase() } }
                )
                // Largeur d'un `Drawer` Material en Material 2.
                .frame(width: 304)
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeOut(duration: 0.25), value: isDrawerOpen)
        .task { await model.load() }
    }

    private var main: some View {
        VStack(spacing: 0) {
            AppBar(title: "Nanny+") { isDrawerOpen = true }
                // Le bandeau projette son ombre sur tout son pourtour, y compris
                // son bord supérieur, qui jouxte la barre de titre : sans cette
                // priorité de dessin, l'ombre y trace un liseré sombre. Côté
                // Flutter, la `SliverAppBar` est peinte par-dessus le bandeau et
                // masque la même ombre.
                .zIndex(1)

            CurvedHeader {
                Text(headerText)
            }
            .contentShape(.rect)
            .onTapGesture {
                guard selection == 0 else { return }

                showPendingInvoice.toggle()
            }

            if selection == 0 {
                ChildListView(model: model)
            } else {
                Spacer()
            }

            BottomNavigationBar(selection: $selection)
        }
        .background(Theme.background)
    }

    private var headerText: String {
        guard selection == 0 else { return "Options" }

        let label = showPendingInvoice ? "Total à encaisser" : "Total à facturer"

        guard let totals = model.totals else { return "\(label) : ..." }

        let value = showPendingInvoice ? totals.pendingInvoice : totals.pendingTotal

        return "\(label) : \(value.twoDecimals)"
    }
}

/// La `SliverAppBar` de Flutter : titre centré en gras, bouton de tiroir à
/// gauche, aucune ombre.
private struct AppBar: View {
    let title: String
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(Poppins.bold(18))
                .foregroundStyle(Theme.onPrimary)

            HStack {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()

                Spacer()
            }
            .padding(.horizontal, Theme.defaultPadding)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        // Seul le fond déborde sous la barre d'état : la vue garde sa hauteur de
        // 56 points et reste posée sous la zone sûre. Étendre la vue elle-même
        // laisserait un trou de la hauteur de l'encoche sous la barre de titre.
        .background {
            Theme.primary.ignoresSafeArea(edges: .top)
        }
    }
}

/// Réplique du `BottomNavigationBar` de Material : fond blanc, élément
/// sélectionné en couleur primaire, les autres en gris.
private struct BottomNavigationBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            item(index: 0, systemImage: "folder.fill", label: "Dossiers")
            item(index: 1, systemImage: "gearshape.fill", label: "Options")
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        // Même principe en bas : le fond blanc couvre l'indicateur d'accueil,
        // les onglets restent au-dessus.
        .background {
            Color.white.ignoresSafeArea(edges: .bottom)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 4, y: -1)
    }

    private func item(index: Int, systemImage: String, label: String) -> some View {
        Button {
            selection = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))

                Text(label)
                    .font(Poppins.regular(index == selection ? 14 : 12))
            }
            .foregroundStyle(index == selection ? Theme.primary : Theme.black54)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

extension Double {
    /// `toStringAsFixed(2)` de Dart : point décimal, pas de séparateur de
    /// milliers, quelle que soit la locale.
    var twoDecimals: String {
        String(format: "%.2f", self)
    }
}
