import SwiftUI

@main
struct NannyPlusApp: App {
    init() {
        Poppins.register()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        #if os(macOS)
        // La cible macOS ne sert qu'au confort de développement : la fenêtre
        // adopte les dimensions en points d'un iPhone 16 pour que le rendu soit
        // directement comparable à celui de l'app sur téléphone.
        .defaultSize(width: 393, height: 852)
        #endif
    }
}
