import SwiftUI

/// Réplique de `lib/src/privacy_settings_view/privacy_settings_view.dart`.
///
/// Écran statique, ouvert depuis le tiroir.
///
/// **Seul écran où le texte s’écarte volontairement de la version Flutter.**
/// La section « Google Analytics » a été retirée — la version native n’embarque
/// aucune télémétrie — et le reste a été récrit : fautes d’accord, contradiction
/// entre l’introduction et le corps du texte, anglicismes et guillemets droits.
/// Le texte de référence est dans `PRIVACY_POLICY.md`, à la racine du dépôt ;
/// les deux doivent rester synchronisés.
struct PrivacySettingsView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Politique de confidentialité", leadingSystemImage: "xmark") {
                onClose()
            }
            .zIndex(1)

            // Le bandeau est présent mais vide : `UISliverCurvedPersistenHeader`
            // reçoit un `Text('')`. Il ne sert ici que de bas de bandeau arrondi.
            CurvedHeader { Text("") }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("Dernière mise à jour : 12 septembre 2026")

                    paragraph(
                        "Cette politique de confidentialité décrit comment l’application Nanny+ (« nous », « notre », « nos », « l’application ») traite les informations que vous (« l’utilisateur ») y saisissez."
                    )

                    section("Collecte et utilisation des informations")

                    paragraph(
                        "Les données de l’application sont enregistrées uniquement sur votre appareil. Aucune donnée ne transite par Internet. Nanny+ respecte votre vie privée et celle des enfants que vous gardez. Nous ne collectons, ne stockons ni n’utilisons aucune donnée vous concernant. Si cela devait changer, nous vous en informerions au préalable."
                    )

                    section("Modifications")

                    paragraph(
                        "Cette politique de confidentialité peut être modifiée ponctuellement, afin de rester conforme à la loi et de tenir compte de tout changement dans le fonctionnement de l’application. Nous vous invitons à la consulter de temps à autre pour rester informé de ces mises à jour."
                    )

                    section("Contact")

                    paragraph(
                        "Si vous avez des questions, n’hésitez pas à nous contacter :"
                    )

                    paragraph("• Par courriel : contact@nannyplus.ch")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.defaultPadding)
            }
        }
        .background(Theme.background)
    }

    /// `_Header` demande `fontWeight: FontWeight.bold`, que Flutter n'applique
    /// pas : `google_fonts` résout une famille par graisse, et forcer w700 sur
    /// la famille Regular retombe sur celle-ci. Les titres s'affichent donc
    /// comme les paragraphes dans la version Flutter.
    ///
    /// On les met ici réellement en gras — écart assumé avec le rendu Flutter,
    /// mais conforme à ce que son code demandait.
    private func section(_ title: String) -> some View {
        Text(title)
            .font(Poppins.bold(14))
            .foregroundStyle(Theme.black87)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Poppins.regular(14))
            .foregroundStyle(Theme.black87)
            .fixedSize(horizontal: false, vertical: true)
    }
}
