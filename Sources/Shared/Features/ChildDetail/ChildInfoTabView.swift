import QuickLook
import SwiftUI

/// Réplique de `lib/src/tab_view/child_info_tab_view.dart`.
///
/// Une carte par information du dossier : un libellé en petit, la valeur en
/// gras dessous, et parfois une commande à droite. Seules la réserve d'heures
/// et le planning en portent une ; tout le reste se modifie par le crayon de la
/// barre de titre.
///
/// **N'est pas porté** : le planning de l'enfant qu'ouvre le crayon de la
/// première carte — `ChildScheduleView` est un écran à part entière.
struct ChildInfoTabView: View {
    let child: Child

    @State private var hourCredits: Int
    @State private var hasSchedule: Bool?
    @State private var documents: [Document] = []
    @State private var preview: URL?
    @State private var snackbar = SnackbarPresenter()

    init(child: Child) {
        self.child = child
        _hourCredits = State(initialValue: child.hourCredits)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let photo = child.pic, let image = UIImage(data: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(.circle)
                        .padding(.vertical, Theme.smallPadding)
                }

                schedule
                credits

                card("Date de naissance", FrenchDate.long(child.birthdate))
                // Une chaîne vide n'est pas nulle : un dossier dont le champ a
                // été vidé affiche une carte sans valeur. Défaut conservé.
                card("Notes / Allergies", child.allergies ?? "Pas d'allergie connue")
                card("Nom des parents", child.parentsName ?? "")
                card("Adresse", child.address ?? "")
                card("Numéro de téléphone", child.phoneNumber ?? "")

                if let label = child.labelForPhoneNumber2, !label.isEmpty,
                   let number = child.phoneNumber2, !number.isEmpty {
                    card(label, number)
                }

                if let label = child.labelForPhoneNumber3, !label.isEmpty,
                   let number = child.phoneNumber3, !number.isEmpty {
                    card(label, number)
                }

                if let text = child.freeText, !text.isEmpty {
                    card("Texte libre", text)
                }

                ForEach(documents) { document in
                    self.document(document)
                }
            }
        }
        .scrollIndicators(.hidden)
        .snackbar(snackbar)
        .task { await load() }
        .quickLook(item: $preview)
    }

    // MARK: Cartes particulières

    private var schedule: some View {
        card("Planning", scheduleLabel) {
            Button {
                // `ChildScheduleView` n'est pas encore porté.
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
    }

    private var scheduleLabel: String {
        guard let hasSchedule else { return "Loading" }

        return hasSchedule ? "Un planning est défini" : "Aucun planning défini"
    }

    private var credits: some View {
        card("Réserve d'heures", String(hourCredits)) {
            HStack(spacing: 0) {
                creditButton("minus", by: -1)
                creditButton("plus", by: 1)
            }
        }
    }

    private func creditButton(_ systemImage: String, by delta: Int) -> some View {
        Button {
            Task { await changeCredits(by: delta) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 24))
                .foregroundStyle(Theme.almostBlack)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func document(_ document: Document) -> some View {
        card("Document", document.label) {
            // Vert si le document est retrouvable — en base ou sur le disque —
            // rouge sinon.
            Image(systemName: document.iconName)
                .font(.system(size: 22))
                .foregroundStyle(
                    document.isStoredInDatabase || document.fileExists ? .green : .red
                )
                .frame(width: 48, height: 48)
        }
        .contentShape(.rect)
        .onTapGesture { open(document) }
    }

    // MARK: Carte générique

    private func card(
        _ label: String,
        _ value: String,
        @ViewBuilder trailing: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Poppins.regular(12))
                .foregroundStyle(Theme.black54)

            HStack(spacing: 0) {
                Text(value)
                    .font(Poppins.bold(16))
                    .foregroundStyle(Theme.almostBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)

                trailing()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: Theme.defaultRadius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2.5, y: 2)
        .padding(.horizontal, Theme.defaultPadding)
        .padding(.vertical, Theme.smallPadding)
    }

    // MARK: Actions

    /// Un document rangé en base est écrit dans un fichier temporaire avant
    /// d'être montré ; un document qui n'est plus sur le disque ne l'est pas.
    private func open(_ document: Document) {
        if document.isStoredInDatabase, let bytes = document.bytes {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(document.label)

            do {
                try bytes.write(to: url)
                preview = url
            } catch {
                snackbar.failure("Fichier introuvable")
            }
        } else if document.fileExists {
            preview = URL(fileURLWithPath: document.path)
        } else {
            snackbar.failure("Fichier introuvable")
        }
    }

    private func changeCredits(by delta: Int) async {
        do {
            hourCredits = try await ChildrenRepository()
                .changeHourCredits(of: child, by: delta)
        } catch {
            snackbar.failure(String(describing: error))
        }
    }

    private func load() async {
        guard let id = child.id else { return }

        do {
            hasSchedule = try await !ScheduleRepository()
                .periods(childId: id)
                .isEmpty
            documents = try await DocumentsRepository().documents(childId: id)
        } catch {
            snackbar.failure("Erreur lors du chargement du dossier")
        }
    }
}

// MARK: - Aperçu d'un document

/// L'équivalent d'`OpenFile` : le système montre le document avec le visualiseur
/// qu'il juge bon.
private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator

        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}

extension View {
    func quickLook(item: Binding<URL?>) -> some View {
        sheet(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let url = item.wrappedValue {
                QuickLookPreview(url: url).ignoresSafeArea()
            }
        }
    }
}
