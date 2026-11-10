import Foundation
import Security

struct AuthUser: Codable, Equatable {
    let id: String
    let name: String
    let email: String
    let familyId: String
}

/// The signed-in user and their API token, kept in the Keychain.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var user: AuthUser?

    var isAuthenticated: Bool { token != nil && user != nil }

    init() {
        #if DEBUG
        // UI tests start from a signed-out app.
        if ProcessInfo.processInfo.arguments.contains("--reset-session") {
            Keychain.delete(key: Self.tokenKey)
            Keychain.delete(key: Self.userKey)
        }
        #endif

        token = Keychain.read(key: Self.tokenKey).flatMap { String(data: $0, encoding: .utf8) }
        user = Keychain.read(key: Self.userKey).flatMap { try? JSONDecoder.api.decode(AuthUser.self, from: $0) }
        if token == nil || user == nil {
            token = nil
            user = nil
        }

        APIClient.shared.authStore = self
        startSocket()
    }

    func signIn(token: String, user: AuthUser) {
        self.token = token
        self.user = user
        Keychain.write(key: Self.tokenKey, data: Data(token.utf8))
        if let data = try? JSONEncoder.api.encode(user) {
            Keychain.write(key: Self.userKey, data: data)
        }
        startSocket()
    }

    func signOut() {
        token = nil
        user = nil
        Keychain.delete(key: Self.tokenKey)
        Keychain.delete(key: Self.userKey)
        PhoenixSocket.shared.stop()
    }

    private func startSocket() {
        if let token, let user {
            PhoenixSocket.shared.start(token: token, familyId: user.familyId)
        }
    }

    private static let tokenKey = "auth_token"
    private static let userKey = "auth_user"
}

private enum Keychain {
    private static let service = "app.portermills"

    static func read(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func write(key: String, data: Data) {
        delete(key: key)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
