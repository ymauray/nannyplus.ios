import SwiftUI

/// Réplique de la `SliverAppBar` du thème : fond en couleur primaire, titre
/// centré en gras, bouton à gauche, aucune ombre.
///
/// Le titre est bien en gras : il vient de `appBarTheme.titleTextStyle`, que
/// `GoogleFonts.poppins` a résolu en gras à la construction du thème. C'est le
/// cas favorable — ailleurs dans l'app, un `fontWeight: bold` posé après coup
/// reste sans effet.
struct AppBar: View {
    let title: String
    let leadingSystemImage: String
    let onLeading: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(Poppins.bold(18))
                .foregroundStyle(Theme.onPrimary)

            HStack {
                Button(action: onLeading) {
                    Image(systemName: leadingSystemImage)
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
