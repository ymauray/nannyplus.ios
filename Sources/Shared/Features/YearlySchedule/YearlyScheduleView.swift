import SwiftUI

/// Réplique de `YearlySchedulePdfView`, la destination « Planning annuel » du
/// menu Options.
///
/// Le bandeau incurvé porte le sélecteur d'année : une flèche de chaque côté,
/// et l'année elle-même qui ramène à l'année en cours quand on la touche.
struct YearlyScheduleView: View {
    let onClose: () -> Void

    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var schedule = Schedule.empty
    @State private var vacationPeriods: [VacationPeriod] = []
    @State private var snackbar = SnackbarPresenter()

    var body: some View {
        PdfPreviewView(
            title: "Planning annuel",
            fileName: "planning_annuel_\(year).pdf",
            document: YearlySchedulePDF.document(
                year: year,
                schedule: schedule,
                vacationPeriods: vacationPeriods
            ),
            onClose: onClose
        ) {
            HStack(spacing: 0) {
                arrow("chevron.left") { year -= 1 }

                Button {
                    year = Calendar.current.component(.year, from: Date())
                } label: {
                    Text(String(year))
                        .font(Poppins.bold(16))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()

                arrow("chevron.right") { year += 1 }
            }
        }
        .snackbar(snackbar)
        .task { await load() }
        .task(id: year) { await loadVacationPeriods() }
    }

    /// Taille d'un `IconButton` de Material.
    private func arrow(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(Theme.onPrimary)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func load() async {
        do {
            schedule = try await ScheduleRepository().weeklySchedule()
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func loadVacationPeriods() async {
        do {
            // Le fournisseur Flutter retrie par date de début ce que la requête
            // a rendu trié par `sortOrder`.
            vacationPeriods = try await VacationPeriodRepository()
                .loadForYear(year)
                .sorted { $0.start < $1.start }
        } catch {
            snackbar.failure(String(describing: error))
        }
    }
}
