import SwiftUI

/// Réplique de `lib/views/options/options_view.dart`.
///
/// Un simple menu : huit tuiles menant chacune à un écran. **Aucune destination
/// n'est portée** — les tuiles sont en place, elles n'ouvrent rien.
struct OptionsView: View {
    /// Appelé à la fermeture des réglages : le tri et l'affichage des noms de
    /// la liste des enfants en dépendent, et la liste doit être rechargée.
    let onAppSettingsClosed: () -> Void

    @State private var isShowingPriceList = false
    @State private var isShowingDeductions = false
    @State private var isShowingAppSettings = false
    @State private var isShowingInvoiceSettings = false
    @State private var isShowingStatements = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // « Prestations » côté Flutter, renommé « Tarifs » pour ne plus
                // porter le même nom que l'onglet du dossier enfant.
                tile("creditcard", "Tarifs") { isShowingPriceList = true }

                // « Deductions » côté Flutter, faute de traduction dans
                // `fr.po`. Accentué ici, comme le titre de l'écran.
                tile("minus.circle", "Déductions") { isShowingDeductions = true }

                tile("apps.iphone", "Paramètres de l'application") {
                    isShowingAppSettings = true
                }
                tile("gearshape.fill", "Paramètres de la facture") {
                    isShowingInvoiceSettings = true
                }
                tile("doc.text.fill", "Relevés") { isShowingStatements = true }
                tile("calendar.day.timeline.left", "Planning hebdomadaire")
                tile("calendar", "Planning annuel")
                tile("calendar", "Planning des congés")
            }
            .padding(.vertical, Theme.smallPadding)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .fullScreenCover(isPresented: $isShowingPriceList) {
            PriceListView { isShowingPriceList = false }
        }
        .fullScreenCover(isPresented: $isShowingDeductions) {
            DeductionListView { isShowingDeductions = false }
        }
        .fullScreenCover(isPresented: $isShowingStatements) {
            StatementListView { isShowingStatements = false }
        }
        .fullScreenCover(isPresented: $isShowingInvoiceSettings) {
            InvoiceSettingsView { isShowingInvoiceSettings = false }
        }
        .fullScreenCover(isPresented: $isShowingAppSettings) {
            AppSettingsView {
                isShowingAppSettings = false
                onAppSettingsClosed()
            }
        }
    }

    /// `OptionTile` dans un `UICard` : marges de 16 sur les côtés et 8 en haut
    /// et en bas, tuile de 56 points, icône puis libellé à 88 points du bord.
    private func tile(
        _ systemImage: String,
        _ label: String,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.black54)
                    .frame(width: 24)
                    .padding(.trailing, 32)

                Text(label)
                    .font(Poppins.bold(16))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.black54)
            }
            .padding(.horizontal, Theme.defaultPadding)
            .frame(height: 56)
            .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }
}
