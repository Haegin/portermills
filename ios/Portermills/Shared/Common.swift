import Combine
import SwiftUI

/// Toolbar menu showing who is signed in, with sign-out.
struct AccountMenu: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Menu {
            Text("Signed in as \(authStore.user?.name ?? "")")
            Button("Sign Out", role: .destructive) { authStore.signOut() }
                .accessibilityIdentifier("account.signOut")
        } label: {
            Image(systemName: "person.crop.circle")
                .accessibilityLabel("Account")
        }
        .accessibilityIdentifier("account.menu")
    }
}

extension View {
    /// Shows `message` in an alert and clears it when dismissed.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Couldn't do that",
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } }),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(message.wrappedValue ?? "") }
        )
    }
}

/// Base for view models that refetch whenever their channel topic reports a change.
@MainActor
class LiveViewModel: ObservableObject {
    @Published var error: String?
    let api = APIClient.shared
    private var subscription: AnyCancellable?

    init(feature: String) {
        subscription = PhoenixSocket.shared.events(for: feature).sink { [weak self] _ in
            Task { await self?.load() }
        }
    }

    /// Overridden to fetch the screen's data.
    func load() async {}

    /// Runs a write, reports a failure, then reloads.
    func perform(_ write: @escaping () async throws -> Void) {
        Task {
            do { try await write() } catch { self.error = error.userMessage }
            await load()
        }
    }
}

/// A sheet asking for one line of text: naming or renaming something.
struct TextPromptSheet: View {
    let title: String
    let label: String
    var confirmLabel = "Save"
    @State var text: String
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField(label, text: $text)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(confirm)
                    .accessibilityIdentifier("prompt.text")
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel, action: confirm)
                        .disabled(trimmed.isEmpty)
                        .accessibilityIdentifier("prompt.confirm")
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(200)])
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func confirm() {
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed)
        dismiss()
    }
}
