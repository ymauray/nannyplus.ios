import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Réplique de `lib/views/child_list_view.dart`.
struct ChildListView: View {
    let model: ChildListViewModel
    let snackbar: SnackbarPresenter

    @State private var confirmation: Confirmation?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.children) { child in
                        ChildListTile(
                            child: child,
                            model: model,
                            onArchiveToggle: { archiveToggle(child) },
                            onDelete: { delete(child) }
                        )
                    }

                    // `extraWidget` : dernier élément de la liste, sous les tuiles.
                    Button {
                        Task { await model.toggleShowArchived() }
                    } label: {
                        Text(
                            model.showArchived
                                ? "Masquer les dossiers archivés"
                                : "Afficher les dossiers archivés"
                        )
                        .font(Poppins.regular(14))
                        .foregroundStyle(Theme.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, Theme.smallPadding)
                }
                // Dégage la place du bouton flottant, comme `UIListView`.
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)

            FloatingActionButton {
                // `ChildForm` n'est pas encore porté.
            }
            .padding(Theme.defaultPadding)
        }
        .background(Theme.background)
        // Le titre suit l'action. Côté Flutter il vaut toujours « Supprimer »,
        // même pour un archivage — défaut corrigé sur décision de Yannick.
        .alert(
            confirmation?.title ?? "",
            isPresented: .constant(confirmation != nil),
            presenting: confirmation
        ) { item in
            Button("Oui") {
                confirmation = nil
                Task { await item.perform() }
            }
            Button("Non", role: .cancel) { confirmation = nil }
        } message: { item in
            Text(item.message)
        }
    }

    // MARK: Actions

    private func archiveToggle(_ child: Child) {
        switch ChildFolderAction.archive(child: child, info: model.info(for: child)) {
        case let .refused(message):
            snackbar.failure(message)

        case let .confirm(title, message):
            confirmation = Confirmation(title: title, message: message) {
                let wasArchived = child.isArchived
                await model.setArchived(!wasArchived, for: child)
                snackbar.success(wasArchived ? "Désarchivé avec succès" : "Archivé avec succès")
            }
        }
    }

    private func delete(_ child: Child) {
        switch ChildFolderAction.delete(child: child, info: model.info(for: child)) {
        case let .refused(message):
            snackbar.failure(message)

        case let .confirm(title, message):
            confirmation = Confirmation(title: title, message: message) {
                await model.delete(child)
                snackbar.success("Supprimé avec succès")
            }
        }
    }

    // MARK: Types

    struct Confirmation: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let perform: () async -> Void
    }
}

/// Réplique de `_ChildListTile`.
private struct ChildListTile: View {
    let child: Child
    let model: ChildListViewModel
    let onArchiveToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            phoneButton

            VStack(alignment: .leading, spacing: 1) {
                Text(child.displayName)
                    .font(child.isArchived ? Poppins.boldItalic(16) : Poppins.bold(16))
                    .foregroundStyle(titleColor)

                Text(child.hasAllergies ? (child.allergies ?? "") : "Pas d'allergie connue")
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.black54)

                Text("Dernière saisie : \(lastEntry)")
                    .font(Poppins.regular(12))
                    .foregroundStyle(Theme.materialGrey)

                Text("Total à encaisser : \(pendingInvoice)")
                    .font(Poppins.regular(12))
                    .foregroundStyle(Theme.materialGrey)
            }

            Spacer(minLength: Theme.smallPadding)

            Text(pendingTotal)
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)
                .padding(.trailing, Theme.smallPadding)

            contextMenu
        }
        .padding(.vertical, Theme.smallPadding)
        .padding(.trailing, Theme.defaultPadding)
        .background(
            Theme.card,
            in: .rect(cornerRadius: Theme.defaultRadius)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(Theme.smallPadding)
        .contentShape(.rect)
    }

    // MARK: Éléments

    private var phoneButton: some View {
        Button {
            guard child.hasPhoneNumber, let number = child.phoneNumber else { return }

            OpenURL.call(number)
        } label: {
            Image(systemName: "phone.fill")
                .font(.system(size: 22))
                .foregroundStyle(child.hasPhoneNumber ? Theme.secondary : Theme.black54)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .padding(.horizontal, Theme.smallPadding)
    }

    private var contextMenu: some View {
        Menu {
            Button("Dupliquer le dossier", systemImage: "doc.on.doc") {
                // `ChildForm(childToClone:)` n'est pas encore porté.
            }

            Button(
                child.isArchived ? "Désarchiver le dossier" : "Archiver le dossier",
                systemImage: "eye.slash"
            ) {
                onArchiveToggle()
            }

            Button("Supprimer", systemImage: "trash", role: .destructive) {
                onDelete()
            }
            .disabled(child.isArchived)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20))
                .foregroundStyle(Theme.black54)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .fixedSize()
    }

    // MARK: Valeurs affichées

    private var titleColor: Color {
        if child.isArchived { return Theme.materialGrey }

        return model.hasOverdueInvoice(child) ? .red : Theme.almostBlack
    }

    /// Jour de la semaine si la dernière saisie date de moins de sept jours,
    /// date complète sinon — et « ... » si l'enfant n'a aucune prestation.
    private var lastEntry: String {
        guard let date = model.info(for: child)?.lastEntry else { return "..." }

        if date < Date().addingTimeInterval(-7 * 86_400) {
            return DateFormatter.shortDate.string(from: date)
        }

        return DateFormatter.weekday.string(from: date)
    }

    private var pendingTotal: String {
        (model.info(for: child)?.pendingTotal ?? 0).twoDecimals
    }

    private var pendingInvoice: String {
        (model.info(for: child)?.pendingInvoice ?? 0).twoDecimals
    }
}

/// Réplique du `FloatingActionButton` de `UIListView`.
private struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Theme.onSecondary)
                .frame(width: 56, height: 56)
                .background(Theme.secondary, in: .circle)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

// MARK: -

extension DateFormatter {
    /// `DateFormat.yMd` en fr_CH donne `24.08.2026`.
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.setLocalizedDateFormatFromTemplate("yMd")

        return formatter
    }()

    /// `DateFormat(DateFormat.WEEKDAY)` donne `jeudi`.
    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_CH")
        formatter.setLocalizedDateFormatFromTemplate("EEEE")

        return formatter
    }()
}

enum OpenURL {
    static func call(_ phoneNumber: String) {
        guard let url = URL(string: "tel://\(phoneNumber)") else { return }

        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}
