import SwiftUI
import PDFKit
import UIKit

/// Équivalent de l'écran `StatementView` de Flutter, qui s'appuie sur le
/// `PdfPreview` du paquet `printing` et sa barre bleue « imprimer / partager ».
///
/// **Écart assumé** : on utilise ici l'aperçu de PDFKit et la feuille de partage
/// du système, qui propose déjà Imprimer, Enregistrer dans Fichiers, Mail et
/// Messages. Pas de barre à dessiner, et l'utilisatrice retrouve les gestes
/// qu'elle connaît partout ailleurs sur iOS.
struct StatementPreviewView: View {
    let title: String
    let subtitle: String
    let fileName: String
    let document: Data
    let onClose: () -> Void

    @State private var fileToShare: URL?

    var body: some View {
        VStack(spacing: 0) {
            AppBar(title: title, leadingSystemImage: "chevron.left") {
                onClose()
            }
            .overlay(alignment: .trailing) {
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.onPrimary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .padding(.trailing, Theme.defaultPadding)
            }
            .zIndex(1)

            CurvedHeader { Text(subtitle) }

            HelpCard(
                identifier: "pdf_statements",
                text: "Rappel : ces relevés n'ont aucune valeur officielles. Vérifier la réglementation en vigueur pour savoir si vous pouvez les utiliser en tant que fiche de salaire ou justificatifs pour les impôts."
            )

            PDFPreview(document: document)
        }
        .background(Theme.background)
        .sheet(item: $fileToShare) { url in
            ShareSheet(url: url)
        }
    }

    /// Le fichier est écrit dans le dossier temporaire sous son nom définitif :
    /// c'est ce nom que reprendront « Enregistrer dans Fichiers » et l'envoi par
    /// courriel.
    private func share() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try document.write(to: url)
            fileToShare = url
        } catch {
            // Sans fichier, pas de partage possible : on s'abstient.
        }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let document: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = UIColor(Theme.background)
        view.document = PDFDocument(data: document)

        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: document)
    }
}

/// La feuille de partage du système, partagée avec l'écran de sauvegarde.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
