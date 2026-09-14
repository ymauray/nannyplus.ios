import SwiftUI

/// Réplique de `lib/src/tab_view/tab_view.dart` — le dossier d'un enfant.
///
/// Les onglets Prestations et Factures sont portés. Information reste une
/// maquette, à reprendre depuis `ChildInfoTabView`.
struct ChildDetailView: View {
    let child: Child
    let onBack: () -> Void

    @State private var selectedTab = 0
    @State private var pendingTotal: Double?

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: child.displayName, leadingSystemImage: "chevron.left") {
                onBack()
            }
            .overlay(alignment: .trailing) {
                Button {
                    // `ChildForm` n'est pas encore porté.
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .padding(.trailing, Theme.defaultPadding)
            }
            .zIndex(1)

            CurvedHeader {
                Text(headerText)
            }

            TabBar(selection: $selectedTab, titles: ["Prestations", "Factures", "Information"])

            content
        }
        .background(Theme.background)
        .task { await loadPendingTotal() }
    }

    private var headerText: String {
        guard let pendingTotal else { return "Chargement..." }

        return "Total à facturer : \(pendingTotal.twoDecimals)"
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case 0:
            ServiceListTabView(child: child) {
                Task { await loadPendingTotal() }
            }
        case 1:
            InvoiceListTabView(child: child) {
                Task { await loadPendingTotal() }
            }
        default: InformationTabMockup(child: child)
        }
    }

    /// Somme des prestations non facturées de l'enfant, hors tarifs techniques
    /// (`priceId < 0`) que la version Flutter écarte aussi.
    private func loadPendingTotal() async {
        guard let id = child.id else { return }

        pendingTotal = (try? await ServicesRepository().pendingTotal(childId: id)) ?? 0
    }
}
