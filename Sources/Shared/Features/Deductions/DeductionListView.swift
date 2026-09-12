import SwiftUI

/// Réplique de `lib/src/deductions/deductions_view.dart`.
///
/// L'écran s'intitule « Déductions ». Côté Flutter il affiche « Deductions »,
/// sans accent : `fr.po` ne traduit pas ce message et renvoie l'original
/// anglais. Corrigé, comme le renommage de « Prestations » en « Tarifs ».
struct DeductionListView: View {
    let onClose: () -> Void

    @State private var deductions: [Deduction] = []
    @State private var deductionToDelete: Deduction?
    @State private var editing: DeductionFormView.Subject?
    @State private var isEditing = false
    @State private var snackbar = SnackbarPresenter()

    private let repository = DeductionsRepository()

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Déductions", leadingSystemImage: "chevron.left") {
                onClose()
            }
            .overlay(alignment: .trailing) {
                Button {
                    withAnimation { isEditing.toggle() }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .padding(.trailing, Theme.defaultPadding)
            }
            .zIndex(1)

            CurvedHeader { Text("") }

            HelpCard(
                identifier: "deductions",
                text: "Les déductions sont automatiquement appliquées aux relevés mensuels et/ou annuels. Elles sont calculées à partir du total brut, pour donner le total net."
            )

            ZStack(alignment: .bottomTrailing) {
                list

                if !isEditing {
                    FloatingActionButton { editing = .creation }
                        .padding(Theme.defaultPadding)
                }
            }
        }
        .snackbar(snackbar)
        .background(Theme.background)
        .task { await load() }
        .alert(
            "Supprimer",
            isPresented: .constant(deductionToDelete != nil),
            presenting: deductionToDelete
        ) { deduction in
            Button("Oui") {
                deductionToDelete = nil
                Task { await delete(deduction) }
            }
            Button("Non", role: .cancel) { deductionToDelete = nil }
        } message: { _ in
            Text("Êtes-vous sûr de vouloir supprimer cette déduction ?")
        }
        .fullScreenCover(item: $editing) { subject in
            DeductionFormView(subject: subject) { editing = nil }
                .onDisappear { Task { await load() } }
        }
    }

    private var list: some View {
        List {
            ForEach(deductions) { deduction in
                card(deduction)
                    .listRowInsets(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove { indices, destination in
                deductions.move(fromOffsets: indices, toOffset: destination)
                Task { try? await repository.reorder(deductions) }
            }

            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func card(_ deduction: Deduction) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                // Comme pour les tarifs, le `fontWeight: bold` du Dart ne
                // s'applique pas : titre et sous-titre sont en `bodyMedium`.
                Text(deduction.label)
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.almostBlack)

                Text(deduction.detail)
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.almostBlack)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { editing = .modification(deduction) }

            Button {
                deductionToDelete = deduction
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
                    .padding(.leading, Theme.defaultPadding)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
        .padding(Theme.defaultPadding)
        .background(.white, in: .rect(cornerRadius: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
    }

    // MARK: Données

    private func load() async {
        do {
            deductions = try await repository.readAll()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func delete(_ deduction: Deduction) async {
        do {
            try await repository.delete(deduction)
            await load()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }
}
