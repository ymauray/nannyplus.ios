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
    @State private var isShowingPrivacySettings = false
    @State private var isShowingBackupRestore = false
    /// Équivalent du `ScaffoldMessenger` de Flutter, qui vit au-dessus de la
    /// navigation : un message déclenché avant un changement d'écran reste
    /// visible après.
    @State private var snackbar = SnackbarPresenter()
    @State private var path: [Child] = []

    var body: some View {
        // Le dossier d'un enfant est empilé par-dessus tout l'écran, barre
        // d'onglets comprise, comme le `Navigator.push` de Flutter. La barre de
        // navigation du système est masquée : l'app dessine la sienne.
        NavigationStack(path: $path) {
            root
                .hidingSystemNavigationBar()
                .navigationDestination(for: Child.self) { child in
                    ChildDetailView(child: child) { path.removeLast() }
                        .hidingSystemNavigationBar()
                }
        }
    }

    private var root: some View {
        ZStack(alignment: .leading) {
            main

            if isDrawerOpen {
                Theme.scrim
                    .ignoresSafeArea()
                    .onTapGesture { isDrawerOpen = false }
                    .transition(.opacity)

                MainDrawer(
                    onDismiss: { isDrawerOpen = false },
                    onBackupRestore: { isShowingBackupRestore = true },
                    onPrivacySettings: { isShowingPrivacySettings = true },
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
        // `fullscreenDialog: true` côté Flutter : la page couvre l'écran et
        // arrive par le bas.
        .fullScreenCover(isPresented: $isShowingPrivacySettings) {
            PrivacySettingsView { isShowingPrivacySettings = false }
        }
        .fullScreenCover(isPresented: $isShowingBackupRestore) {
            backupRestore
        }
    }

    private var main: some View {
        VStack(spacing: 0) {
            AppBar(title: "Nanny+", leadingSystemImage: "line.3.horizontal") {
                isDrawerOpen = true
            }
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
                ChildListView(model: model, snackbar: snackbar) { path.append($0) }
            } else {
                OptionsView()
            }

            BottomNavigationBar(selection: $selection)
        }
        .snackbar(snackbar)
        .background(Theme.background)
    }

    /// Après une restauration, Flutter vide la pile de navigation et repart sur
    /// `MainTabView`. On ferme la modale et on recharge : même résultat visible.
    private var backupRestore: some View {
        BackupRestoreView(
            onClose: { isShowingBackupRestore = false },
            onRestored: {
                isShowingBackupRestore = false
                Task { await model.load() }
                // Le message est confié au parent : affiché dans la modale, il
                // disparaîtrait avec elle et l'utilisatrice ne verrait rien.
                snackbar.success("Base de données restaurée avec succès")
            }
        )
    }

    private var headerText: String {
        guard selection == 0 else { return "Options" }

        let label = showPendingInvoice ? "Total à encaisser" : "Total à facturer"

        guard let totals = model.totals else { return "\(label) : ..." }

        let value = showPendingInvoice ? totals.pendingInvoice : totals.pendingTotal

        return "\(label) : \(value.twoDecimals)"
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


extension View {
    /// L'app dessine sa propre barre de titre ; celle du système est masquée.
    func hidingSystemNavigationBar() -> some View {
        navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
    }
}
