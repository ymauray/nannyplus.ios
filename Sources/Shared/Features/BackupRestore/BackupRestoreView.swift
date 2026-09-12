import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Réplique de `lib/src/backup_restore/backup_restore_view.dart`.
///
/// Le mécanisme est volontairement fruste, et on le garde tel quel :
/// « Sauvegarder » partage le fichier `childcare.db` lui-même, « Restaurer » le
/// remplace par un fichier choisi par l'utilisatrice. Aucun contrôle de format
/// n'est fait sur le fichier restauré.
struct BackupRestoreView: View {
    let onClose: () -> Void
    let onRestored: () -> Void

    @State private var snackbar = SnackbarPresenter()
    @State private var isImporting = false
    /// `fileImporter` n'appelle pas son gestionnaire quand l'utilisatrice
    /// annule, là où `FilePicker` de Flutter renvoie `null` et déclenche donc le
    /// message d'erreur. On repère l'annulation à la fermeture sans résultat.
    @State private var importDidComplete = false
    @State private var fileToShare: URL?

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Sauvegarder / Restaurer", leadingSystemImage: "xmark") {
                onClose()
            }
            .zIndex(1)

            CurvedHeader { Text("") }

            VStack(spacing: 0) {
                row("Sauvegarder") { backup() }
                row("Restaurer") { isImporting = true }

                Spacer()
            }
            .padding(Theme.smallPadding)
        }
        .snackbar(snackbar)
        .background(Theme.background)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data]) { result in
            importDidComplete = true
            restore(result)
        }
        .onChange(of: isImporting) { _, isPresented in
            if isPresented {
                importDidComplete = false

                return
            }

            Task {
                // Laisse au gestionnaire le temps de s'exécuter : il est appelé
                // juste avant que la présentation ne retombe.
                try? await Task.sleep(for: .milliseconds(300))

                if !importDidComplete {
                    snackbar.failure("Erreur lors de la restauration de la base de données")
                }
            }
        }
        #if os(iOS)
        .sheet(item: $fileToShare) { url in
            ShareSheet(url: url)
        }
        #endif
    }

    /// `ListTile` hors tiroir : le titre prend `titleMedium`, que le thème a
    /// résolu en Poppins gras 16 (cf. `ListTileStyle.list` dans Flutter).
    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(Poppins.bold(16))
                    .foregroundStyle(Theme.almostBlack)

                Spacer(minLength: Theme.smallPadding)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.black54)
            }
            .padding(.horizontal, Theme.defaultPadding)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.bottom, Theme.smallPadding)
    }

    // MARK: Actions

    /// Ferme la base puis propose son fichier au partage.
    ///
    /// Le message de succès s'affiche **sans attendre le résultat du partage**,
    /// exactement comme côté Flutter : annuler la feuille de partage affiche
    /// quand même « sauvegardée avec succès ». Défaut conservé.
    private func backup() {
        Task {
            await AppDatabase.shared.close()

            #if os(iOS)
            fileToShare = AppDatabase.databaseURL
            #else
            // Pas de feuille de partage sur macOS : cette cible n'est qu'un
            // outil de développement, un panneau d'enregistrement suffit.
            saveCopyOnMac()
            #endif

            snackbar.success("Base de données sauvegardée avec succès")
        }
    }

    #if os(macOS)
    private func saveCopyOnMac() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "childcare.db"
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: AppDatabase.databaseURL, to: destination)
    }
    #endif

    /// Remplace `childcare.db` par le fichier choisi.
    ///
    /// **Annuler le sélecteur affiche le message d'erreur**, la version Flutter
    /// ne distinguant pas l'annulation de l'échec (`result == null` dans les
    /// deux cas). Défaut conservé.
    private func restore(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else {
            snackbar.failure("Erreur lors de la restauration de la base de données")

            return
        }

        Task {
            do {
                let needsAccess = url.startAccessingSecurityScopedResource()
                defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

                let bytes = try Data(contentsOf: url)
                await AppDatabase.shared.close()
                try bytes.write(to: AppDatabase.databaseURL)

                onRestored()
            } catch {
                snackbar.failure("Erreur lors de la restauration de la base de données")
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#if os(iOS)
/// `Share.shareXFiles` de `share_plus` : la feuille de partage du système.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
