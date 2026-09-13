import SwiftUI

/// Réplique de `WeeklySchedulePdf`, la destination « Planning hebdomadaire » du
/// menu Options.
///
/// L'écran n'est qu'un aperçu : tout est dans le document. Comme côté Flutter,
/// la page est composée avec ce qui est chargé — donc vide le temps de lire la
/// base, puis complète.
struct WeeklyScheduleView: View {
    let onClose: () -> Void

    @State private var schedule = Schedule.empty
    @State private var snackbar = SnackbarPresenter()

    var body: some View {
        PdfPreviewView(
            title: "Planning hebdomadaire",
            subtitle: "",
            fileName: "planning_hebdomadaire.pdf",
            document: WeeklySchedulePDF.document(for: schedule),
            onClose: onClose
        )
        .snackbar(snackbar)
        .task {
            do {
                schedule = try await ScheduleRepository().weeklySchedule()
            } catch {
                snackbar.failure(String(describing: error))
            }
        }
    }
}
