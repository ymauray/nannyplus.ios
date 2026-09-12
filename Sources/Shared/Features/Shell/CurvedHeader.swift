import SwiftUI

/// Réplique de `UISliverCurvedPersistenHeader`.
///
/// Flutter décrit le bandeau par un `BorderRadius.vertical(bottom:
/// Radius.elliptical(width / 2, height / 2))`. Les deux coins inférieurs
/// partagent alors la même ellipse — de demi-largeur `width / 2` et de
/// demi-hauteur `height / 2` — et se rejoignent exactement au milieu : le bas du
/// bandeau est la moitié inférieure de cette ellipse.
struct CurvedBottomShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Approximation d'un quart d'ellipse par une cubique de Bézier.
        let kappa: CGFloat = 0.552_284_749_8
        let radiusY = rect.height / 2
        let radiusX = rect.width / 2
        let shoulder = rect.maxY - radiusY

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: shoulder))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: shoulder + radiusY * kappa),
            control2: CGPoint(x: rect.midX + radiusX * kappa, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: shoulder),
            control1: CGPoint(x: rect.midX - radiusX * kappa, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: shoulder + radiusY * kappa)
        )
        path.closeSubpath()

        return path
    }
}

struct CurvedHeader<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(Poppins.regular(18))
            .foregroundStyle(Theme.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.headerHeight)
            .background(Theme.primary, in: CurvedBottomShape())
            .compositingGroup()
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .padding(.bottom, Theme.headerSpacing)
            .background(Theme.background)
    }
}
