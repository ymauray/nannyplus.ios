import SwiftUI

/// Réplique du `TabBar` de Material tel que le thème le configure : libellé
/// sélectionné en gras, trait de 2 points en couleur secondaire, fond de page.
struct TabBar: View {
    @Binding var selection: Int
    let titles: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button {
                    selection = index
                } label: {
                    VStack(spacing: 0) {
                        Text(title)
                            .font(index == selection ? Poppins.bold(14) : Poppins.regular(14))
                            .foregroundStyle(
                                index == selection
                                    ? Theme.almostBlack
                                    : Theme.almostBlack.opacity(0.7)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Rectangle()
                            .fill(index == selection ? Theme.secondary : .clear)
                            .frame(height: 2)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
        }
        // Le `maxExtent` du sliver vaut `tabBar.preferredSize.height`, soit 48,
        // **marge du bas comprise** : la barre elle-même est donc comprimée à
        // 36 points, et non posée sur 48 puis complétée par 12.
        .frame(height: 48 - Theme.headerSpacing)
        .padding(.horizontal, Theme.smallPadding)
        .padding(.bottom, Theme.headerSpacing)
        .background(Theme.background)
    }
}
