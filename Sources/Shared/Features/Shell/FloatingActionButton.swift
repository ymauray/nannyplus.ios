import SwiftUI

/// Réplique du `FloatingActionButton` de Material tel que le thème le
/// configure : disque de 56 points en couleur secondaire, signe « plus » blanc.
struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Theme.onSecondary)
                .frame(width: 56, height: 56)
                .background(Theme.secondary, in: .circle)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}
