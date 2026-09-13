import SwiftUI

/// Réplique de `lib/src/statement_list_view/statement_list_view.dart`.
///
/// Une carte par année, contenant le total annuel puis un rang par mois. Les
/// montants affichés sont **nets**, déductions mensuelles appliquées.
struct StatementListView: View {
    let onClose: () -> Void

    @State private var statements: [YearlyStatement] = []
    @State private var snackbar = SnackbarPresenter()
    @State private var preview: PreviewRequest?

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: "Relevés", leadingSystemImage: "chevron.left") {
                onClose()
            }
            .zIndex(1)

            CurvedHeader { Text("") }

            HelpCard(
                identifier: "statements",
                text: "Ces relevés mensuels et annuels n'ont aucune valeur officielles. Vérifier la réglementation en vigueur pour savoir si vous pouvez les utiliser en tant que fiche de salaire ou justificatifs pour les impôts."
            )

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(statements) { statement in
                        card(statement)
                    }
                }
                .padding(.vertical, Theme.smallPadding)
            }
            .scrollIndicators(.hidden)
        }
        .snackbar(snackbar)
        .background(Theme.background)
        .task { await load() }
        .fullScreenCover(item: $preview) { request in
            PdfPreviewView(
                title: request.title,
                subtitle: request.subtitle,
                fileName: request.fileName,
                document: request.document,
                help: (
                    identifier: "pdf_statements",
                    text: "Rappel : ces relevés n'ont aucune valeur officielles. Vérifier la réglementation en vigueur pour savoir si vous pouvez les utiliser en tant que fiche de salaire ou justificatifs pour les impôts."
                )
            ) {
                preview = nil
            }
        }
    }

    struct PreviewRequest: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let fileName: String
        let document: Data
    }

    private func openYearly(_ statement: YearlyStatement) async {
        do {
            let deductions = try await DeductionsRepository().readAll()
            let document = StatementPDF.yearly(
                year: statement.year,
                months: statement.monthlyStatements.sorted { $0.month < $1.month },
                deductions: deductions
            )
            preview = PreviewRequest(
                title: "Décompte annuel",
                subtitle: String(statement.year),
                fileName: "décompte_annuel_\(statement.year).pdf",
                document: document
            )
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func openMonthly(_ monthly: MonthlyStatement) async {
        do {
            let deductions = try await DeductionsRepository().readAll()
            let lines = try await ServicesRepository().statementLines(
                year: monthly.year,
                month: monthly.month
            )
            let document = StatementPDF.monthly(
                year: monthly.year,
                month: monthly.month,
                monthName: monthly.monthName,
                lines: lines,
                deductions: deductions
            )
            preview = PreviewRequest(
                title: "Relevé mensuel",
                subtitle: "\(monthly.monthName) \(monthly.year)",
                fileName: "relevé_mensuel_\(monthly.year)_\(String(format: "%02d", monthly.month)).pdf",
                document: document
            )
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func card(_ statement: YearlyStatement) -> some View {
        VStack(spacing: 0) {
            row(
                label: String(statement.year),
                font: Poppins.bold(16),
                amount: statement.netTotal
            ) {
                Task { await openYearly(statement) }
            }

            Divider()

            ForEach(statement.monthlyStatements) { monthly in
                row(
                    label: monthly.monthName,
                    font: Poppins.medium(14),
                    amount: monthly.netAmount
                ) {
                    Task { await openMonthly(monthly) }
                }
                // `EdgeInsets.only(top: 8)` côté Flutter.
                .padding(.top, Theme.smallPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.bottom, Theme.smallPadding)
    }

    private func row(
        label: String,
        font: Font,
        amount: Double,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(font)
                .foregroundStyle(Theme.almostBlack)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(amount.twoDecimals)
                .font(Poppins.regular(14))
                .foregroundStyle(Theme.almostBlack)
                .padding(.trailing, Theme.smallPadding)

            Button(action: action) {
                // `Icons.picture_as_pdf` de Material n'a pas d'équivalent : aucun
                // symbole SF ne porte la mention « PDF ». `doc.text` est le plus
                // proche, une page avec un coin plié.
                Image(systemName: "doc.text")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.almostBlack)
                    // Taille d'un `IconButton` de Material, ce qui donne son
                    // aération à la liste : chaque rang fait 48 points de haut.
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
        .padding(.leading, 12)
        .padding(.trailing, Theme.smallPadding)
    }

    private func load() async {
        do {
            let deductions = try await DeductionsRepository().readAll()
            statements = try await ServicesRepository().statements(deductions: deductions)
        } catch {
            snackbar.failure(String(describing: error))
        }
    }
}
