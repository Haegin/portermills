import Foundation

enum APIError: Error {
    case http(Int)
    case invalidURL
}

extension Error {
    /// A short message for showing a failed request to the user.
    var userMessage: String {
        switch self as Error {
        case APIError.http(401): return "You've been signed out."
        case APIError.http(403): return "You're not allowed to do that."
        case APIError.http(404): return "That no longer exists."
        case APIError.http(409): return "Someone else got there first."
        case APIError.http(422): return "That couldn't be saved. Check the details and try again."
        case APIError.http(let code): return "The server returned an error (\(code))."
        case is URLError: return "Can't reach the server."
        default: return "Something went wrong."
        }
    }

    var isNotFound: Bool {
        if case APIError.http(404) = self as Error { return true }
        return false
    }
}

/// HTTP client for the Porter-Mills API. Field names are snake_case on the
/// wire and camelCase in Swift.
@MainActor
final class APIClient {
    static let shared = APIClient()

    /// Server origin, from the build setting API_BASE_URL via Info.plist.
    let baseURL: String = (Bundle.main.object(forInfoDictionaryKey: "PMAPIBaseURL") as? String)
        .flatMap { $0.isEmpty ? nil : $0 } ?? "http://localhost:2310"

    weak var authStore: AuthStore?

    var socketURL: URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/socket/websocket"
        return components.url
    }

    private init() {}

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try JSONDecoder.api.decode(T.self, from: await send("GET", path))
    }

    /// A request whose response body is decoded as `T`.
    func send<T: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil, as type: T.Type) async throws -> T {
        try JSONDecoder.api.decode(T.self, from: await send(method, path, body: body))
    }

    /// A request whose response body isn't needed.
    @discardableResult
    func send(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + "/api" + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder.api.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = authStore?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, authStore?.token != nil { authStore?.signOut() }
        guard (200..<300).contains(status) else { throw APIError.http(status) }
        return data
    }
}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
