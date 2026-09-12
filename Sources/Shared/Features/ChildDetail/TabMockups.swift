import SwiftUI

// Maquettes des trois onglets du dossier enfant. Elles reproduisent ce que
// montrent les captures de référence pour un dossier vide, afin de juger la
// coque, mais aucune n'est portée : ni la saisie de prestations, ni la liste
// des factures, ni l'édition des informations.

/// Maquette de `ServiceListTabView`.
struct ServicesTabMockup: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            FloatingActionButton {}
                .padding(Theme.defaultPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Maquette de `InvoiceListTabView`.
struct InvoicesTabMockup: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                MockupCard {
                    Text("Aucune facture ouverte trouvée")
                        .font(Poppins.regular(14))
                        .foregroundStyle(Theme.almostBlack)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Afficher les factures payées") {}
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.primary)
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .padding(.top, Theme.smallPadding)

                Spacer()
            }
            .padding(Theme.smallPadding)

            FloatingActionButton {}
                .padding(Theme.defaultPadding)
        }
    }
}

/// Maquette de `ChildInfoTabView`. Les valeurs viennent du dossier réel, seule
/// la mise en forme est provisoire — pas d'édition, et le planning n'est pas lu.
struct InformationTabMockup: View {
    let child: Child

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MockupCard {
                    field("Planning", "Aucun planning défini", trailing: "pencil")
                }

                MockupCard {
                    HStack(spacing: 0) {
                        field("Réserve d'heures", "\(child.hourCredits)")

                        Image(systemName: "minus")
                            .font(.system(size: 22))
                            .padding(.trailing, Theme.defaultPadding)

                        Image(systemName: "plus")
                            .font(.system(size: 22))
                    }
                    .foregroundStyle(Theme.almostBlack)
                }

                MockupCard { field("Date de naissance", child.birthdate ?? "") }
                MockupCard { field("Notes / Allergies", child.allergies ?? "Pas d'allergie connue") }
                MockupCard { field("Nom des parents", child.parentsName ?? "") }
                MockupCard { field("Adresse", child.address ?? "") }
                MockupCard { field("Numéro de téléphone", child.phoneNumber ?? "") }
            }
            .padding(Theme.smallPadding)
        }
    }

    private func field(
        _ label: String,
        _ value: String,
        trailing: String? = nil
    ) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.black87)

                if !value.isEmpty {
                    Text(value)
                        .font(Poppins.bold(16))
                        .foregroundStyle(Theme.almostBlack)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.almostBlack)
            }
        }
    }
}

// MARK: - Éléments communs aux maquettes

private struct MockupCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.defaultPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: .rect(cornerRadius: Theme.defaultRadius))
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
            .padding(.bottom, Theme.smallPadding)
    }
}
