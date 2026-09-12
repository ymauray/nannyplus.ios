import SwiftUI

/// Réplique de `SnackBarUtil` (`lib/utils/snack_bar_util.dart`) : bandeau vert
/// en cas de succès, rouge en cas d'échec.
struct SnackbarMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isFailure: Bool
}

struct SnackbarView: View {
    let message: SnackbarMessage

    var body: some View {
        Text(message.text)
            .font(Poppins.regular(14))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.defaultPadding)
            .background(message.isFailure ? Color.red : Color.green)
    }
}

/// Affiche un bandeau et le retire au bout de quelques secondes, comme le fait
/// `ScaffoldMessenger`.
@MainActor
@Observable
final class SnackbarPresenter {
    private(set) var message: SnackbarMessage?

    func success(_ text: String) { show(text, isFailure: false) }

    func failure(_ text: String) { show(text, isFailure: true) }

    private func show(_ text: String, isFailure: Bool) {
        let message = SnackbarMessage(text: text, isFailure: isFailure)
        self.message = message

        Task {
            try? await Task.sleep(for: .seconds(4))

            if self.message == message { self.message = nil }
        }
    }
}

extension View {
    func snackbar(_ presenter: SnackbarPresenter) -> some View {
        overlay(alignment: .bottom) {
            if let message = presenter.message {
                SnackbarView(message: message)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeOut(duration: 0.2), value: presenter.message)
    }
}
