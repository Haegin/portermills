import Foundation

struct MagicLinkRequest: Encodable {
    let email: String
}

struct VerifyTokenRequest: Encodable {
    let token: String
}

struct AuthResponse: Decodable {
    let token: String
    let user: AuthUser
}
