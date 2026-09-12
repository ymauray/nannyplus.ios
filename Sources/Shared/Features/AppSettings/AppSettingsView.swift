import SwiftUI

/// Réplique de `lib/src/app_settings/app_settings_form.dart`, **remise en
/// forme**. L'écran d'origine aligne quatre champs nus séparés de filets, sans
/// cartes, avec les interrupteurs violets par défaut de Material qui
/// n'appartiennent à aucune palette de l'app. On reprend ici la mise en carte
/// employée partout ailleurs et la couleur primaire.
struct AppSettingsView: View {
    let onClose: () -> Void

    @State private var sortByLastName = AppPreferences.shared.sortListByLastName
    @State private var showFirstNameFirst = AppPreferences.shared.showFirstNameBeforeLastName
    @State private var daysBeforeOverdue = String(AppPreferences.shared.daysBeforeUnpaidInvoiceNotification)
    @State private var notificationMessage = AppPreferences.shared.notificationMessage

    var body: some View {
        VStack(spacing: 0) {
            AppBar(
                title: "Paramètres de l'application",
                leadingSystemImage: "chevron.left"
            ) {
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
                    card {
                        Toggle(isOn: $sortByLastName) {
                            Text("Trier la liste des enfants par nom de famille")
                                .font(Poppins.regular(14))
                                .foregroundStyle(Theme.almostBlack)
                        }
                        .tint(Theme.primary)
                    }

                    card {
                        Toggle(isOn: $showFirstNameFirst) {
                            Text("Afficher le prénom avant le nom de famille")
                                .font(Poppins.regular(14))
                                .foregroundStyle(Theme.almostBlack)
                        }
                        .tint(Theme.primary)
                    }

                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            // Le libellé d'origine parle de notification. Les
                            // notifications ayant été retirées, ce réglage n'a
                            // plus qu'un effet : à partir de combien de jours le
                            // nom d'un enfant passe en rouge dans la liste.
                            Text("Jours avant de signaler une facture impayée")
                                .font(Poppins.regular(13))
                                .foregroundStyle(Theme.black54)

                            TextField("", text: $daysBeforeOverdue)
                                .keyboardType(.numberPad)
                                .font(Poppins.regular(16))
                                .foregroundStyle(Theme.almostBlack)

                            Rectangle()
                                .fill(Theme.black54)
                                .frame(height: 1)
                                .padding(.top, 4)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            // Rien à voir avec les notifications locales
                            // retirées : ce texte sert de gabarit au SMS de
                            // relance envoyé aux parents depuis le menu d'une
                            // facture. `{{date}}` et `{{total}}` y sont
                            // remplacés au moment de l'envoi.
                            Text("Message de notification")
                                .font(Poppins.regular(13))
                                .foregroundStyle(Theme.black54)

                            TextField("", text: $notificationMessage, axis: .vertical)
                                .font(Poppins.regular(16))
                                .foregroundStyle(Theme.almostBlack)

                            Rectangle()
                                .fill(Theme.black54)
                                .frame(height: 1)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.top, Theme.smallPadding)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
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

    private func save() {
        let preferences = AppPreferences.shared
        preferences.sortListByLastName = sortByLastName
        preferences.showFirstNameBeforeLastName = showFirstNameFirst

        if let days = Int(daysBeforeOverdue), days >= 0 {
            preferences.daysBeforeUnpaidInvoiceNotification = days
        }

        preferences.notificationMessage = notificationMessage

        onClose()
    }
}
