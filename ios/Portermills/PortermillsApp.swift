import SwiftUI

@main
struct PortermillsApp: App {
    @StateObject private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authStore)
            .task {
                await APIClient.shared.configure(authStore: authStore)
            }
        }
    }
}
