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
    }
}
