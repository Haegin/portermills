import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @FocusState private var emailFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Portermills")
                .font(.largeTitle.bold())

            if let sentTo = viewModel.sentTo {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Check your email")
                        .font(.headline)
                    Text("If \(sentTo) belongs to a family member, a sign-in link is on its way. Open it on this phone.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if viewModel.busy { ProgressView() }
                    if let error = viewModel.error {
                        Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
                    }
                    Button("Use a different email") { viewModel.startOver() }
                }
            } else {
                VStack(spacing: 16) {
                    Text("Sign in with your email and we'll send you a link.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit { if viewModel.canSend { viewModel.requestLink() } }
                        .focused($emailFocused)
                        .padding(12)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("login.email")

                    if let error = viewModel.error {
                        Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
                    }

                    Button {
                        viewModel.requestLink()
                    } label: {
                        Group {
                            if viewModel.busy { ProgressView() } else { Text("Send sign-in link") }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSend)
                    .accessibilityIdentifier("login.send")
                }
            }

            Spacer()
        }
        .padding(32)
    }
}
