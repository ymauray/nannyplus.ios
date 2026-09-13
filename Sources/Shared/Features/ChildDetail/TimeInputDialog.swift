import SwiftUI

/// Réplique de `lib/widgets/time_input_dialog.dart`.
///
/// Deux menus déroulants — les heures de 0 à 12, les minutes par quarts — et un
/// bouton « Enregistrer ». La boîte est blanche, à angles droits, posée sur un
/// voile : c'est un `Dialog` de Material, pas une feuille venue du bas.
///
/// **Aucun champ n'est obligatoire** : valider sans rien choisir renvoie 0h00,
/// que l'appelant traite comme une saisie annulée. Défaut conservé.
struct TimeInputDialog: View {
    let initialHours: Int?
    let initialMinutes: Int?
    let onSave: (Int, Int) -> Void
    let onDismiss: () -> Void

    @State private var hours: Int?
    @State private var minutes: Int?

    init(
        initialHours: Int? = nil,
        initialMinutes: Int? = nil,
        onSave: @escaping (Int, Int) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialHours = initialHours
        self.initialMinutes = initialMinutes
        self.onSave = onSave
        self.onDismiss = onDismiss
        _hours = State(initialValue: initialHours)
        _minutes = State(initialValue: initialMinutes)
    }

    var body: some View {
        ZStack {
            Theme.scrim
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: Theme.smallPadding) {
                HStack(spacing: Theme.smallPadding) {
                    dropdown("Heures", selection: $hours, values: Array(0 ... 12)) {
                        String($0)
                    }

                    dropdown("Minutes", selection: $minutes, values: [0, 15, 30, 45]) {
                        String(format: "%02d", $0)
                    }
                }

                Button {
                    onSave(hours ?? 0, minutes ?? 0)
                } label: {
                    Text("Enregistrer")
                        .font(Poppins.regular(14))
                        .foregroundStyle(Theme.onPrimary)
                        .padding(.horizontal, Theme.defaultPadding)
                        .padding(.vertical, 10)
                        .background(Theme.primary, in: .rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .padding(Theme.smallPadding)
            .background(.white)
            .shadow(color: .black.opacity(0.5), radius: 10, y: 10)
            // `insetPadding` d'un `Dialog` de Material.
            .padding(.horizontal, 40)
        }
    }

    /// Un `FormBuilderDropdown` : libellé flottant toujours visible, valeur
    /// centrée, chevron à droite, filet en dessous.
    private func dropdown(
        _ label: String,
        selection: Binding<Int?>,
        values: [Int],
        format: @escaping (Int) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Poppins.regular(12))
                .foregroundStyle(Theme.black54)

            Menu {
                ForEach(values, id: \.self) { value in
                    Button(format(value)) { selection.wrappedValue = value }
                }
            } label: {
                HStack(spacing: 0) {
                    Text(selection.wrappedValue.map(format) ?? "")
                        .font(Poppins.regular(16))
                        .foregroundStyle(Theme.almostBlack)
                        .frame(maxWidth: .infinity)

                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.black54)
                }
                .frame(height: 40)
                .contentShape(.rect)
            }

            Rectangle()
                .fill(Theme.black54)
                .frame(height: 1)
        }
    }
}
