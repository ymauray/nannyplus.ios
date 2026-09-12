import SwiftUI
import PhotosUI

/// Réplique de `lib/src/invoice_settings/invoice_settings_form.dart`, **remise
/// en forme** comme les paramètres de l'application : l'écran d'origine aligne
/// ses champs sans cartes. Le contenu, lui, est identique.
struct InvoiceSettingsView: View {
    let onClose: () -> Void

    @State private var line1 = AppPreferences.shared.line1
    @State private var line2 = AppPreferences.shared.line2
    @State private var line1Font = AppPreferences.shared.line1Font
    @State private var line2Font = AppPreferences.shared.line2Font
    @State private var conditions = AppPreferences.shared.conditions
    @State private var bankDetails = AppPreferences.shared.bankDetails
    @State private var name = AppPreferences.shared.name
    @State private var address = AppPreferences.shared.address

    @State private var logo: Data?
    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Paramètres de la facture", leadingSystemImage: "chevron.left") {
                onClose()
            }
            .overlay(alignment: .trailing) {
                Button(action: save) {
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
                    card { identity }

                    card { field("Ligne 1") { TextField("", text: $line1) } }
                    card { fontField("Police pour la ligne 1", selection: $line1Font) }
                    card { field("Ligne 2") { TextField("", text: $line2) } }
                    card { fontField("Police pour la ligne 2", selection: $line2Font) }

                    card {
                        field("Conditions de paiement") {
                            TextField("", text: $conditions, axis: .vertical)
                        }
                    }
                    card {
                        field("Détails bancaires") {
                            TextField("", text: $bankDetails, axis: .vertical)
                                .lineLimit(3...5)
                        }
                    }
                    card { field("Nom") { TextField("", text: $name) } }
                    card {
                        field("Adresse") {
                            TextField("", text: $address, axis: .vertical)
                                .lineLimit(3...5)
                        }
                    }
                }
                .padding(.vertical, Theme.smallPadding)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .task { loadLogo() }
        .onChange(of: pickedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    logo = data
                }
            }
        }
    }

    // MARK: Éléments

    private var identity: some View {
        VStack(alignment: .leading, spacing: Theme.defaultPadding) {
            Text("Identité")
                .font(Poppins.bold(14))
                .foregroundStyle(Theme.almostBlack)

            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Text("Choisir un logo")
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)

            // Aperçu de 120 points de haut, ou un carré gris si aucun logo
            // n'est enregistré — exactement ce que fait `LogoPicker`.
            if let logo, let image = UIImage(data: logo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
            } else {
                Rectangle()
                    .fill(Theme.materialGrey)
                    .frame(width: 120, height: 120)
            }
        }
    }

    /// Chaque police du menu est affichée dans sa propre fonte, comme côté
    /// Flutter.
    private func fontField(_ label: String, selection: Binding<InvoiceFont>) -> some View {
        field(label) {
            Menu {
                ForEach(InvoiceFont.all) { item in
                    Button { selection.wrappedValue = item } label: {
                        Text(item.family).font(item.font(size: 16))
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    Text(selection.wrappedValue.family)
                        .font(selection.wrappedValue.font(size: 18))
                        .foregroundStyle(Theme.almostBlack)

                    Spacer(minLength: Theme.smallPadding)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.black54)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Theme.defaultPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
            .padding(.horizontal, Theme.defaultPadding)
            .padding(.bottom, Theme.smallPadding)
    }

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

    /// Le logo est un fichier nommé `logo`, sans extension, dans `Documents` —
    /// le même emplacement que côté Flutter, si bien qu'un logo déjà choisi est
    /// repris tel quel.
    private static var logoURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("logo")
    }

    private func loadLogo() {
        logo = try? Data(contentsOf: Self.logoURL)
    }

    private func save() {
        if let logo {
            try? logo.write(to: Self.logoURL)
        }

        let preferences = AppPreferences.shared
        preferences.line1 = line1
        preferences.line2 = line2
        preferences.line1Font = line1Font
        preferences.line2Font = line2Font
        preferences.conditions = conditions
        preferences.bankDetails = bankDetails
        preferences.name = name
        preferences.address = address

        onClose()
    }
}
