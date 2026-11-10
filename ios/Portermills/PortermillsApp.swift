import SwiftUI

@main
struct PortermillsApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var login = LoginViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.isAuthenticated {
                    ContentView()
                } else {
                    LoginView(viewModel: login)
                }
            }
            .environmentObject(authStore)
            // Magic-link sign-in: portermills://auth?token=…
            .onOpenURL { url in
                guard url.scheme == "portermills", url.host == "auth",
                      let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "token" })?.value,
                      !token.isEmpty
                else { return }
                login.verify(token: token, authStore: authStore)
            }
        }
    }
}
