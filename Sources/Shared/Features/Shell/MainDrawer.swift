import SwiftUI

/// Réplique de `lib/src/child_list/main_drawer.dart`.
///
/// SwiftUI n'a pas d'équivalent du `Drawer` de Material : le panneau, le voile
/// et l'animation d'ouverture sont dessinés à la main dans `MainTabView`.
struct MainDrawer: View {
    let onDismiss: () -> Void
    let onResetHelpMessages: () -> Void
    let onResetDatabase: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            entry(
                title: "Sauvegarder / Restaurer",
                systemImage: "icloud.and.arrow.up.fill"
            ) {
                // `BackupRestoreView` n'est pas encore portée.
                onDismiss()
            }

            Divider()

            entry(
                title: "Politique de confidentialité",
                systemImage: "exclamationmark.shield.fill"
            ) {
                // `PrivacySettingsView` n'est pas encore portée.
                onDismiss()
            }

            Divider()

            entry(
                title: "Réinitialiser les messages d'aide",
                systemImage: "questionmark.circle.fill"
            ) {
                onResetHelpMessages()
                onDismiss()
            }

            Divider()

            // `kDebugMode` côté Flutter.
            #if DEBUG
            entry(
                title: "Réinitialiser la base de données",
                systemImage: "trash.fill"
            ) {
                onResetDatabase()
                onDismiss()
            }

            Divider()
            #endif

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Theme.drawerBackground.ignoresSafeArea()
        }
    }

    /// `DrawerHeader` : 160 points de haut plus un filet, marge basse de 8,
    /// marge intérieure (16, 16, 16, 8).
    private var header: some View {
        VStack(spacing: 0) {
            Image("Banner")
                .resizable()
                .scaledToFit()

            Text("Version \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.black87)

            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
        .frame(height: 160, alignment: .top)
        .overlay(alignment: .bottom) { Divider() }
        .padding(.bottom, 8)
    }

    /// `ListTile` : le thème lui donne un fond blanc et des coins arrondis, y
    /// compris dans le tiroir.
    private func entry(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.black54)
                    .frame(width: 24)
                    .padding(.trailing, 32)

                // `bodyLarge` de la typographie Material 2014 : 14 points en
                // graisse 500. Le `fontWeight: bold` du Dart est sans effet —
                // `google_fonts` résout une famille par graisse, et forcer w700
                // sur une famille qui n'en contient pas retombe sur sa fonte.
                // Mesuré sur la capture : c'est bien du Medium, pas du Bold.
                Text(title)
                    .font(Poppins.medium(14))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.defaultPadding)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
