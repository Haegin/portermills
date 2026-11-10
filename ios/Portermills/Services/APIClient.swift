import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"]
        ?? "http://localhost:4000/api")!

    private weak var authStore: AuthStore?

    func configure(authStore: AuthStore) async {
        self.authStore = authStore
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(method: "GET", path: path, body: nil as EmptyBody?)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "PATCH", path: path, body: body)
    }

    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: path, body: nil as EmptyBody?)
    }

    private func request<B: Encodable, T: Decodable>(method: String, path: String, body: B?) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authStore?.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder.api.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder.api.decode(T.self, from: data)
    }
}

enum APIError: Error {
    case httpError(Int)
}

private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
