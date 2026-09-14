import SwiftUI

/// Réplique de `lib/forms/invoice_form/invoice_form.dart`.
///
/// Deux cartes : celle du haut nomme l'enfant du dossier et laisse choisir le
/// mois à facturer, celle du bas coche les autres enfants à joindre à la même
/// facture — une fratrie tient ainsi sur un seul document.
///
/// **Le sélecteur propose les mois de tous les enfants**, pas seulement ceux du
/// dossier ouvert : on peut donc retenir un mois où l'enfant n'a rien, et
/// produire une facture à zéro. Défaut conservé.
struct InvoiceFormView: View {
    let child: Child
    let onClose: () -> Void

    @State private var months: [String] = []
    @State private var selectedMonth: String?
    @State private var others: [Child] = []
    @State private var selected: Set<Int64> = []
    @State private var snackbar = SnackbarPresenter()

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Créer une facture", leadingSystemImage: "xmark") {
                onClose()
            }
            .overlay(alignment: .trailing) {
                Button { Task { await save() } } label: {
                    // `Icons.save` est une disquette ; aucun symbole SF n'en
                    // porte une.
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 22))
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
                    if selectedMonth == nil {
                        card { label("Rien à facturer") }
                    } else {
                        card { invoiceFor }
                        card { combinedWith }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .snackbar(snackbar)
        .task { await load() }
    }

    // MARK: Cartes

    @ViewBuilder
    private var invoiceFor: some View {
        caption("Facture pour")

        HStack(spacing: 0) {
            Text(child.displayName)
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Le `DropdownButton` de Material compose en `titleMedium`, et
            // porte un filet sous sa valeur.
            Menu {
                ForEach(months, id: \.self) { month in
                    Button(InvoiceMonth.name(month)) { selectedMonth = month }
                }
            } label: {
                HStack(spacing: Theme.smallPadding) {
                    Text(InvoiceMonth.name(selectedMonth ?? ""))
                        .font(Poppins.bold(16))
                        .foregroundStyle(Theme.almostBlack)

                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.almostBlack)
                }
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.black54)
                        .frame(height: 1)
                }
                // Un `DropdownButton` de Material n'est jamais plus court que
                // la hauteur tactile minimale, ce qui donne sa hauteur au rang.
                .frame(minHeight: 48)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .fixedSize()
        }
        .padding(12)
    }

    @ViewBuilder
    private var combinedWith: some View {
        if others.isEmpty {
            label("Pas d'autre enfant à ajouter à la facture")
        } else {
            caption("Combiné avec")

            ForEach(others) { other in
                HStack(spacing: 0) {
                    Text(other.displayName)
                        .font(Poppins.regular(14))
                        .foregroundStyle(Theme.almostBlack)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button { toggle(other) } label: {
                        Image(systemName: isSelected(other) ? "checkmark.square" : "square")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }

    /// `bodySmall` de Material 2014, soit la légende : 12 points en noir à 54 %.
    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Poppins.regular(12))
            .foregroundStyle(Theme.black54)
            .padding(.horizontal, 12)
            .padding(.top, 12)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Poppins.regular(14))
            .foregroundStyle(Theme.almostBlack)
            .padding(12)
    }

    // MARK: Actions

    private func isSelected(_ other: Child) -> Bool {
        other.id.map(selected.contains) ?? false
    }

    private func toggle(_ other: Child) {
        guard let id = other.id else { return }

        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    /// Le bouton ferme l'écran dans tous les cas, même sans rien créer.
    private func save() async {
        guard let month = selectedMonth else {
            onClose()

            return
        }

        do {
            _ = try await InvoicesRepository().createInvoice(
                for: child,
                with: others.filter(isSelected),
                month: month
            )
        } catch {
            snackbar.failure(String(describing: error))
        }

        onClose()
    }

    private func load() async {
        do {
            months = try await ServicesRepository().invoiceableMonths()
            // Le mois le plus ancien est retenu d'office.
            selectedMonth = months.first
            others = try await ChildrenRepository()
                .childList(showArchived: false)
                .filter { $0.id != child.id }
        } catch {
            snackbar.failure(String(describing: error))
        }
    }
}

/// Le mois à facturer, tel que l'affiche le sélecteur.
enum InvoiceMonth {
    /// « septembre 2026 », en minuscules comme le rend `DateFormat('MMMM yyyy')`.
    static func name(_ month: String) -> String {
        guard let date = parser.date(from: month) else { return month }

        return formatter.string(from: date)
    }

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"

        return formatter
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"

        return formatter
    }()
}
