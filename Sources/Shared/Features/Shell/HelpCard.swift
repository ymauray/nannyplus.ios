import SwiftUI

/// Réplique de `lib/widgets/help_card.dart` : un encart jaune que
/// l'utilisatrice peut écarter, et qui ne revient plus.
///
/// **La clé de préférence diffère de la version Flutter.** Celle-ci utilise
/// `help_<hashCode du texte d'aide>`, or le `hashCode` des chaînes de Dart n'est
/// pas reproductible en Swift. On emploie un identifiant explicite, stable et
/// lisible. Conséquence : un encart déjà écarté dans l'app Flutter réapparaîtra
/// une fois dans la version native. Le préfixe `flutter.help_` est conservé, si
/// bien que « Réinitialiser les messages d'aide » du tiroir les efface aussi.
struct HelpCard: View {
    let identifier: String
    let text: String

    @State private var isVisible = true

    var body: some View {
        if isVisible, AppPreferences.shared.isHelpVisible(identifier) {
            HStack(alignment: .top, spacing: 0) {
                Text(text)
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    AppPreferences.shared.hideHelp(identifier)
                    withAnimation { isVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.almostBlack)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            .padding(Theme.smallPadding)
            .background(Theme.helpBackground)
            .overlay {
                Rectangle().strokeBorder(Theme.helpBorder, lineWidth: 2)
            }
            .padding(Theme.smallPadding)
        }
    }
}
