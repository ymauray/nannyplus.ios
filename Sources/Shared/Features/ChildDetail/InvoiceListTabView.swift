import SwiftUI
import UIKit

/// Réplique de `lib/src/tab_view/invoice_list_tab_view.dart`.
///
/// Une carte par année, la plus récente en haut : l'année, la moyenne d'une
/// facture sur l'année, un bouton PDF, puis une ligne par facture. Un bouton
/// sous la liste montre ou masque les factures payées.
///
/// **N'est pas portée** : la création d'une facture.
struct InvoiceListTabView: View {
    let child: Child
    /// Supprimer une facture rend ses prestations à facturer : le total du
    /// bandeau et l'onglet des prestations changent avec elle.
    let onChange: () -> Void

    @State private var years: [InvoiceYear] = []
    @State private var averages: [Int: Double] = [:]
    @State private var showPaid = false
    @State private var invoiceToDelete: Invoice?
    @State private var invoiceToMarkPaid: Invoice?
    @State private var preview: PreviewRequest?
    @State private var snackbar = SnackbarPresenter()

    private let repository = InvoicesRepository()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    if years.isEmpty {
                        emptyCard
                    } else {
                        ForEach(years) { year in
                            card(year)
                        }
                    }

                    toggle
                }
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)

            FloatingActionButton {
                // `InvoiceForm` n'est pas encore porté.
            }
            .padding(Theme.defaultPadding)
        }
        .snackbar(snackbar)
        .task { await load() }
        .fullScreenCover(item: $preview) { request in
            PdfPreviewView(
                title: request.title,
                fileName: request.fileName,
                document: request.document,
                onClose: { preview = nil }
            ) {
                Text(request.subtitle)
            }
        }
        .alert(
            "Supprimer",
            isPresented: .constant(invoiceToDelete != nil),
            presenting: invoiceToDelete
        ) { invoice in
            Button("Non", role: .cancel) { invoiceToDelete = nil }
            Button("Oui", role: .destructive) {
                let invoice = invoice
                invoiceToDelete = nil
                Task { await delete(invoice) }
            }
        } message: { _ in
            Text("Êtes-vous sûr de vouloir supprimer cette facture ?")
        }
        .alert(
            "Marquer comme payée",
            isPresented: .constant(invoiceToMarkPaid != nil),
            presenting: invoiceToMarkPaid
        ) { invoice in
            Button("Non", role: .cancel) { invoiceToMarkPaid = nil }
            Button("Oui") {
                let invoice = invoice
                invoiceToMarkPaid = nil
                Task { await markAsPaid(invoice) }
            }
        } message: { _ in
            Text("Êtes-vous sûr de vouloir marquer cette facture comme payée ?")
        }
    }

    // MARK: Contenu

    private var emptyCard: some View {
        Text("Aucune facture ouverte trouvée")
            .font(Poppins.regular(14))
            .foregroundStyle(Theme.almostBlack)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
            .padding(.horizontal, Theme.defaultPadding)
            .padding(.vertical, Theme.smallPadding)
    }

    private var toggle: some View {
        Button {
            showPaid.toggle()
            Task { await load() }
        } label: {
            Text(showPaid ? "Masquer les factures payées" : "Afficher les factures payées")
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.primary)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .padding(.top, Theme.smallPadding)
    }

    private func card(_ year: InvoiceYear) -> some View {
        VStack(spacing: 0) {
            // Seule l'année s'étire ; la moyenne garde sa largeur naturelle,
            // sans quoi elle passe à la ligne.
            FlexRow {
                Text(String(year.year))
                    .font(Poppins.bold(16))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .flex(1)

                Text("Moyenne mensuelle : \((averages[year.year] ?? 0).twoDecimals)")
                    .font(Poppins.regular(14))
                    .foregroundStyle(Theme.almostBlack)
                    .fixedSize()
                    .padding(.trailing, Theme.smallPadding)
                    .flex(0)

                Button {
                    Task { await openStatement(year.year) }
                } label: {
                    // `Icons.picture_as_pdf` n'a pas d'équivalent : aucun
                    // symbole SF ne porte la mention « PDF ».
                    Image(systemName: "doc.text")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.almostBlack)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .flex(0)
            }
            .padding(.leading, 12)

            MaterialDivider()

            ForEach(year.invoices) { invoice in
                row(invoice)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }

    /// Une facture payée s'écrit en italique, une facture en retard en rouge.
    ///
    /// Le style est `bodyLarge`, soit Poppins Medium 14 ; l'italique retombe
    /// sur la graisse normale, seule fonte italique embarquée.
    private func row(_ invoice: Invoice) -> some View {
        let late = invoice.isLate(daysBefore: AppPreferences.shared.daysBeforeUnpaidInvoiceNotification)
        let font = invoice.isPaid ? Poppins.italic(14) : Poppins.medium(14)
        let color = late ? Color.red : Theme.almostBlack

        return HStack(spacing: 0) {
            Text(Self.longDate(invoice.date))
                .font(font)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { Task { await openInvoice(invoice) } }

            Text(invoice.total.twoDecimals)
                .font(font)
                .foregroundStyle(color)
                .padding(.trailing, Theme.smallPadding)
                .contentShape(.rect)
                .onTapGesture { Task { await openInvoice(invoice) } }

            Menu {
                Button {
                    notify(invoice)
                } label: {
                    Label("Notifier", systemImage: "alarm")
                }

                Button {
                    invoiceToMarkPaid = invoice
                } label: {
                    Label("Marquer comme payée", systemImage: "banknote")
                }
                .disabled(invoice.isPaid)

                Button(role: .destructive) {
                    invoiceToDelete = invoice
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
                .disabled(invoice.isPaid)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.almostBlack)
                    // Taille d'un `IconButton` de Material, qui donne au rang
                    // ses 48 points.
                    .frame(width: 48, height: 48)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .fixedSize()
        }
        .padding(.leading, 12)
        .padding(.top, Theme.smallPadding)
    }

    /// Ouvre Messages avec le numéro du dossier et le gabarit de relance.
    ///
    /// Côté Flutter, un dossier sans numéro fait planter l'écran — le cubit
    /// déréférence `child.phoneNumber!`. On signale l'échec à la place.
    private func notify(_ invoice: Invoice) {
        guard
            let url = InvoiceNotification.url(
                phoneNumber: child.phoneNumber ?? "",
                message: InvoiceNotification.message(
                    template: AppPreferences.shared.notificationMessage,
                    invoice: invoice
                )
            )
        else {
            snackbar.failure("Impossible d'ouvrir l'application de SMS")

            return
        }

        UIApplication.shared.open(url) { opened in
            if opened {
                snackbar.success("Notification envoyée")
            } else {
                snackbar.failure("Impossible d'ouvrir l'application de SMS")
            }
        }
    }

    // MARK: Documents

    struct PreviewRequest: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let fileName: String
        let document: Data
    }

    /// Les enfants d'une facture viennent de **toutes** ses prestations,
    /// marqueurs compris : c'est ce qui fait apparaître une fratrie dans le
    /// cartouche du titre.
    private func openInvoice(_ invoice: Invoice) async {
        guard let id = invoice.id else { return }

        do {
            let services = ServicesRepository()
            let rows = try await services.invoiceServices(invoiceId: id)
            var ordered: [Int64] = []
            for service in rows where !ordered.contains(service.childId) {
                ordered.append(service.childId)
            }

            let repository = ChildrenRepository()
            var names: [(id: Int64, firstName: String)] = []
            for childId in ordered {
                names.append((
                    id: childId,
                    firstName: try await repository.read(id: childId)?.firstName ?? ""
                ))
            }

            preview = PreviewRequest(
                title: child.displayName,
                subtitle: "Facture du \(Self.longDate(invoice.date))",
                fileName: "facture_\(invoice.number).pdf",
                document: InvoicePDF.document(for: InvoicePDF.Content(
                    invoice: invoice,
                    services: rows,
                    children: names
                ))
            )
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func openStatement(_ year: Int) async {
        guard let childId = child.id else { return }

        do {
            let services = ServicesRepository()
            let repository = ChildrenRepository()
            var entries: [ChildStatementPDF.Entry] = []

            for invoice in try await self.repository.invoices(childId: childId, year: year) {
                let rows = try await services.services(invoiceId: invoice.id ?? 0)
                let amounts = ChildStatementPDF.amounts(of: invoice, services: rows)
                var line: [(id: Int64, name: String, amount: Double)] = []

                for id in Set(rows.map(\.childId)).sorted() {
                    line.append((
                        id: id,
                        name: try await repository.read(id: id)?.displayName ?? String(id),
                        amount: amounts[id] ?? 0
                    ))
                }

                entries.append(ChildStatementPDF.Entry(invoice: invoice, children: line))
            }

            preview = PreviewRequest(
                title: child.displayName,
                subtitle: "Décompte annuel \(year)",
                fileName: "relevé_\(year).pdf",
                document: ChildStatementPDF.document(year: year, entries: entries)
            )
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    // MARK: Données

    private func load() async {
        guard let id = child.id else { return }

        do {
            years = try await repository.invoiceYears(childId: id, includePaid: showPaid)
            averages = try await repository.monthlyAverages(childId: id)
        } catch {
            snackbar.failure("Erreur lors du chargement des factures")
        }
    }

    private func markAsPaid(_ invoice: Invoice) async {
        do {
            try await repository.markAsPaid(invoice)
            await load()
            snackbar.success("Facture marquée comme payée")
            onChange()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func delete(_ invoice: Invoice) async {
        do {
            try await repository.delete(invoice)
            await load()
            snackbar.success("Supprimé avec succès")
            onChange()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    // MARK: Dates

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("yMMMMd")

        return formatter
    }()

    static func longDate(_ value: String) -> String {
        guard let date = shortFormatter.date(from: value) else { return value }

        return longFormatter.string(from: date)
    }
}
