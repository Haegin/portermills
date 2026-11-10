import Foundation
import Security

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var currentUser: AuthUser?

    var isAuthenticated: Bool { token != nil }

    init() {
        token = Keychain.read(key: "auth_token")
        if let data = Keychain.readData(key: "auth_user") {
            currentUser = try? JSONDecoder.api.decode(AuthUser.self, from: data)
        }
    }

    func setAuth(token: String, user: AuthUser) {
        self.token = token
        self.currentUser = user
        Keychain.write(key: "auth_token", value: token)
        if let data = try? JSONEncoder.api.encode(user) {
            Keychain.writeData(key: "auth_user", data: data)
        }
        PhoenixSocket.shared.connect(token: token)
    }

    func signOut() {
        token = nil
        currentUser = nil
        Keychain.delete(key: "auth_token")
        Keychain.delete(key: "auth_user")
    }
}

struct AuthUser: Codable {
    let id: String
    let name: String
    let email: String
    let familyId: String
}

private enum Keychain {
    static func read(key: String) -> String? {
        guard let data = readData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func readData(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func write(key: String, value: String) {
        writeData(key: key, data: Data(value.utf8))
    }

    static func writeData(key: String, data: Data) {
        delete(key: key)
        let attrs: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }
}
