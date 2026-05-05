import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var email = ""
    @State private var isLoading = false
    @State private var linkSent = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Portermills")
                .font(.largeTitle.bold())

            if linkSent {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Check your email")
                        .font(.headline)
                    Text("Tap the link in the email to sign in.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 16) {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Button {
                        Task { await requestLink() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Send magic link")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || isLoading)
                }
            }

            Spacer()
        }
        .padding(32)
    }

    private func requestLink() async {
        isLoading = true
        errorMessage = nil
        do {
            let _: EmptyResponse = try await APIClient.shared.post("/auth/magic-link",
                body: MagicLinkRequest(email: email))
            linkSent = true
        } catch {
            errorMessage = "Something went wrong. Try again."
        }
        isLoading = false
    }
}

private struct EmptyResponse: Decodable {}
