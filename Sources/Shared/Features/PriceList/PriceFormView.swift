import SwiftUI

/// Réplique de `lib/forms/price_form.dart`.
struct PriceFormView: View {
    enum Subject: Identifiable {
        case creation
        case modification(Price)

        var id: Int64 {
            switch self {
            case .creation: return -1
            case let .modification(price): return price.id ?? -1
            }
        }

        var price: Price? {
            guard case let .modification(price) = self else { return nil }

            return price
        }
    }

    let subject: Subject
    let onClose: () -> Void

    @State private var label = ""
    @State private var amount = ""
    @State private var isFixedPrice = false

    var body: some View {
        VStack(spacing: 0) {
            // Le titre annonce toujours une création, y compris quand on
            // modifie un tarif existant : le Dart passe `Create new price` dans
            // les deux cas. Défaut conservé.
            AppBar(title: "Créer un nouveau tarif", leadingSystemImage: "xmark") {
                onClose()
            }
            .overlay(alignment: .trailing) {
                Button {
                    Task { await save() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .padding(.trailing, Theme.defaultPadding)
            }
            .zIndex(1)

            CurvedHeader { Text("") }

            ScrollView {
                VStack(spacing: 0) {
                    card {
                        field("Libellé") {
                            // `textCapitalization: TextCapitalization.sentences`
                            TextField("", text: $label)
                                .textInputAutocapitalization(.sentences)
                        }
                    }

                    card {
                        field("Prix") {
                            TextField("", text: $amount)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }

                    card {
                        field("Type de tarif") {
                            Picker("", selection: $isFixedPrice) {
                                Text("Tarif fixe").tag(true)
                                Text("Tarif horaire").tag(false)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(Theme.almostBlack)
                            .padding(.leading, -12)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .onAppear(perform: fill)
    }

    // MARK: Éléments

    /// `Card` avec la surcharge de `CardScrollView` : rayon 1, marges 8 et 5,
    /// marge intérieure de 16.
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Theme.defaultPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: .rect(cornerRadius: 1))
            .compositingGroup()
            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
            .padding(.horizontal, Theme.smallPadding)
            .padding(.vertical, 5)
    }

    /// `InputDecoration` avec `floatingLabelBehavior: always` : étiquette au
    /// dessus, valeur en dessous, trait de soulignement.
    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Poppins.regular(13))
                .foregroundStyle(Theme.black54)

            content()
                .font(Poppins.regular(16))
                .foregroundStyle(Theme.almostBlack)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Theme.black54)
                .frame(height: 1)
                .padding(.top, 4)
        }
    }

    // MARK: Données

    private func fill() {
        guard let price = subject.price else { return }

        label = price.label
        amount = price.amount.twoDecimals
        isFixedPrice = price.isFixedPrice
    }

    private func save() async {
        // `double.parse` côté Flutter lève si le champ est vide ou mal formé ;
        // ici on s'abstient plutôt que de planter.
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return }

        let repository = PricesRepository()

        do {
            if let existing = subject.price {
                var updated = existing
                updated.label = label
                updated.amount = value
                updated.fixedPrice = isFixedPrice ? 1 : 0
                try await repository.update(updated)
            } else {
                try await repository.create(
                    Price(
                        id: nil,
                        label: label,
                        amount: value,
                        fixedPrice: isFixedPrice ? 1 : 0,
                        sortOrder: -1,
                        deleted: 0
                    )
                )
            }

            onClose()
        } catch {
            onClose()
        }
    }
}
