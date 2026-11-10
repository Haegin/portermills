import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published private(set) var busy = false
    /// The address a link was sent to, once one has been requested.
    @Published private(set) var sentTo: String?
    @Published var error: String?

    private let api = APIClient.shared

    var canSend: Bool { email.contains("@") && !busy }

    func requestLink() {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        error = nil
        Task {
            do {
                try await api.send("POST", "/auth/magic-link", body: MagicLinkRequest(email: address))
                sentTo = address
            } catch {
                self.error = error.userMessage
            }
            busy = false
        }
    }

    /// Completes sign-in with the token from a magic link.
    func verify(token: String, authStore: AuthStore) {
        busy = true
        error = nil
        Task {
            do {
                let response = try await api.send(
                    "POST", "/auth/verify", body: VerifyTokenRequest(token: token), as: AuthResponse.self)
                authStore.signIn(token: response.token, user: response.user)
                sentTo = nil
                email = ""
            } catch APIError.http(401) {
                self.error = "That sign-in link has expired or was already used. Request a new one."
            } catch {
                self.error = error.userMessage
            }
            busy = false
        }
    }

    func startOver() {
        sentTo = nil
        error = nil
    }
}
