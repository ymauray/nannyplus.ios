import SwiftUI

/// Réplique de `lib/src/deductions/deduction_form.dart`.
struct DeductionFormView: View {
    enum Subject: Identifiable {
        case creation
        case modification(Deduction)

        var id: Int64 {
            switch self {
            case .creation: return -1
            case let .modification(deduction): return deduction.id ?? -1
            }
        }

        var deduction: Deduction? {
            guard case let .modification(deduction) = self else { return nil }

            return deduction
        }
    }

    let subject: Subject
    let onClose: () -> Void

    @State private var label = ""
    @State private var value = ""
    @State private var type = "amount"
    @State private var periodicity = "monthly"

    var body: some View {
        VStack(spacing: 0) {
            // Comme pour les tarifs, le titre annonce une création même quand on
            // modifie une déduction existante. Défaut conservé.
            AppBar(title: "Créer une nouvelle déduction", leadingSystemImage: "xmark") {
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
                            TextField("", text: $label)
                                .textInputAutocapitalization(.sentences)
                        }
                    }

                    card {
                        field("Valeur") {
                            TextField("", text: $value)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }

                    card {
                        field("Type") {
                            Picker("", selection: $type) {
                                Text("Montant").tag("amount")
                                Text("Pourcentage").tag("percent")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(Theme.almostBlack)
                            .padding(.leading, -12)
                        }
                    }

                    card {
                        field("Périodicité") {
                            Picker("", selection: $periodicity) {
                                Text("Mensuel").tag("monthly")
                                Text("Annuel").tag("yearly")
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
        guard let deduction = subject.deduction else { return }

        label = deduction.label
        value = deduction.value.twoDecimals
        type = deduction.type
        periodicity = deduction.periodicity
    }

    /// Le formulaire Flutter refuse d'enregistrer si le libellé est vide ou si
    /// la valeur n'est pas un nombre. On s'abstient de même.
    private func save() async {
        guard !label.isEmpty,
              let parsed = Double(value.replacingOccurrences(of: ",", with: "."))
        else { return }

        let repository = DeductionsRepository()

        do {
            if let existing = subject.deduction {
                var updated = existing
                updated.label = label
                updated.value = parsed
                updated.type = type
                updated.periodicity = periodicity
                try await repository.update(updated)
            } else {
                try await repository.create(
                    Deduction(
                        id: nil,
                        sortOrder: 0,
                        label: label,
                        value: parsed,
                        type: type,
                        periodicity: periodicity
                    )
                )
            }
        } catch {
            // L'échec est silencieux, comme côté Flutter.
        }

        onClose()
    }
}
