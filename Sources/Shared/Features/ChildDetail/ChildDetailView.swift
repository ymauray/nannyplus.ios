import SwiftUI

/// Réplique de `lib/src/tab_view/tab_view.dart` — le dossier d'un enfant.
///
/// **La coque est portée, les trois contenus sont des maquettes.** Ils seront
/// repris écran par écran : `ServiceListTabView`, `InvoiceListTabView` et
/// `ChildInfoTabView` côté Flutter.
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
        case 0: ServicesTabMockup()
        case 1: InvoicesTabMockup()
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

/// Réplique du `TabBar` de Material tel que le thème le configure : libellé
/// sélectionné en gras, trait de 2 points en couleur secondaire, fond de page.
private struct TabBar: View {
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
        .frame(height: 48)
        .padding(.horizontal, Theme.smallPadding)
        .padding(.bottom, Theme.headerSpacing)
        .background(Theme.background)
    }
}
