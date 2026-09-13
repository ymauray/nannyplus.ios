import SwiftUI

/// Équivalent d'une `Row` de Flutter dont les enfants sont des `Expanded(flex:)`.
///
/// SwiftUI n'a pas de notion de flex : `layoutPriority` change l'ordre
/// d'attribution de l'espace, pas les proportions. Ce `Layout` distribue la
/// largeur restante au prorata des poids, les vues de poids nul gardant leur
/// largeur naturelle — ce que sont les `SizedBox` intercalés côté Flutter.
struct FlexWeight: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    /// Poids de la vue dans une [FlexRow]. Zéro lui laisse sa largeur naturelle.
    func flex(_ weight: CGFloat) -> some View {
        layoutValue(key: FlexWeight.self, value: weight)
    }
}

struct FlexRow: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let widths = widths(in: proposal.width ?? 0, subviews: subviews)
        let height = zip(subviews, widths)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
            .max() ?? 0

        return CGSize(width: proposal.width ?? widths.reduce(0, +), height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX

        for (subview, width) in zip(subviews, widths(in: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width
        }
    }

    private func widths(in available: CGFloat, subviews: Subviews) -> [CGFloat] {
        let weights = subviews.map { $0[FlexWeight.self] }
        let naturalWidths = subviews.map { $0.sizeThatFits(.unspecified).width }

        var fixed: CGFloat = 0
        var totalWeight: CGFloat = 0

        for (index, weight) in weights.enumerated() {
            if weight == 0 {
                fixed += naturalWidths[index]
            } else {
                totalWeight += weight
            }
        }

        let remaining = max(0, available - fixed)
        let share = totalWeight > 0 ? remaining / totalWeight : 0

        return weights.enumerated().map { index, weight in
            weight == 0 ? naturalWidths[index] : weight * share
        }
    }
}

/// Le `Divider` de Material : un trait de 1 point en noir à 12 %, centré dans
/// une boîte dont la hauteur est donnée séparément.
struct MaterialDivider: View {
    var height: CGFloat = 2

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.12))
            .frame(height: 1)
            .frame(height: height)
    }
}
