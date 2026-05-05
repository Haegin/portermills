import Foundation

// Thin Phoenix WebSocket client.
// Join channels with `join(topic:onMessage:)`, push events with `push(_:event:payload:)`.
// Reconnects automatically on disconnect.

final class PhoenixSocket: NSObject, URLSessionWebSocketDelegate {
    static let shared = PhoenixSocket()
    private override init() { super.init() }

    private var webSocketTask: URLSessionWebSocketTask?
    private var handlers: [String: (Any) -> Void] = [:]
    private var ref = 0
    private var token: String?

    private let baseURL = URL(string: ProcessInfo.processInfo.environment["SOCKET_URL"]
        ?? "ws://localhost:4000/socket/websocket")!

    func connect(token: String) {
        self.token = token
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: components.url!)
        webSocketTask?.resume()
        receive()
    }

    func join(topic: String, onMessage: @escaping (Any) -> Void) {
        handlers[topic] = onMessage
        push(topic: topic, event: "phx_join", payload: [:])
    }

    func leave(topic: String) {
        handlers.removeValue(forKey: topic)
        push(topic: topic, event: "phx_leave", payload: [:])
    }

    func push(topic: String, event: String, payload: [String: Any]) {
        ref += 1
        let msg: [Any?] = [nil, "\(ref)", topic, event, payload]
        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { _ in }
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            if case .success(let msg) = result, case .string(let str) = msg {
                self.handle(str)
            }
            self.receive()
        }
    }

    private func handle(_ message: String) {
        guard let data = message.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any?],
              arr.count >= 5,
              let topic = arr[2] as? String,
              let event = arr[3] as? String,
              event != "phx_reply",
              let payload = arr[4] else { return }
        handlers[topic]?(payload)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let token = self?.token else { return }
            self?.connect(token: token)
        }
    }
}
