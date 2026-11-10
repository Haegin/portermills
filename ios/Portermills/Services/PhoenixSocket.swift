import Combine
import Foundation

/// Something that happened on one of the family's channel topics.
/// `feature` is "calendar", "lists" or "wishlists". `event` is the server's
/// event name, or `SocketEvent.joined` each time the topic is (re)joined,
/// which is the cue to refetch anything missed while disconnected.
struct SocketEvent {
    static let joined = "joined"

    let feature: String
    let event: String
}

/// Phoenix Channels client (V2 serializer) over URLSessionWebSocketTask.
///
/// While signed in it stays connected: joins the family's three topics, sends
/// heartbeats and reconnects after a drop. It only receives; all writes go
/// through the REST API.
@MainActor
final class PhoenixSocket {
    static let shared = PhoenixSocket()

    private let subject = PassthroughSubject<SocketEvent, Never>()
    private var connection: Task<Void, Never>?
    private var ref = 0

    private static let features = ["calendar", "lists", "wishlists"]

    private init() {}

    func events(for feature: String) -> AnyPublisher<SocketEvent, Never> {
        subject.filter { $0.feature == feature }.eraseToAnyPublisher()
    }

    func start(token: String, familyId: String) {
        stop()
        connection = Task { await self.run(token: token, familyId: familyId) }
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    private func run(token: String, familyId: String) async {
        while !Task.isCancelled {
            guard let base = APIClient.shared.socketURL,
                  var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return }
            components.queryItems = [
                URLQueryItem(name: "vsn", value: "2.0.0"),
                URLQueryItem(name: "token", value: token),
            ]
            guard let url = components.url else { return }

            let socket = URLSession.shared.webSocketTask(with: url)
            socket.resume()
            for feature in Self.features {
                send(socket, topic: "family:\(familyId):\(feature)", event: "phx_join")
            }

            let heartbeat = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    self.send(socket, topic: "phoenix", event: "heartbeat")
                }
            }

            await withTaskCancellationHandler {
                while let message = try? await socket.receive() {
                    if case .string(let text) = message { self.handle(text) }
                }
            } onCancel: {
                socket.cancel(with: .goingAway, reason: nil)
            }

            heartbeat.cancel()
            socket.cancel(with: .goingAway, reason: nil)
            try? await Task.sleep(for: .seconds(3))
        }
    }

    private func send(_ socket: URLSessionWebSocketTask, topic: String, event: String) {
        ref += 1
        let frame = "[\"\(ref)\",\"\(ref)\",\"\(topic)\",\"\(event)\",{}]"
        socket.send(.string(frame)) { _ in }
    }

    /// Frames are `[join_ref, ref, topic, event, payload]`.
    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let frame = try? JSONSerialization.jsonObject(with: data) as? [Any],
              frame.count >= 5,
              let topic = frame[2] as? String,
              let event = frame[3] as? String,
              topic.hasPrefix("family:"),
              let feature = topic.split(separator: ":").last.map(String.init)
        else { return }

        if event == "phx_reply" {
            let payload = frame[4] as? [String: Any]
            let joined = payload?["status"] as? String == "ok"
                && (payload?["response"] as? [String: Any])?.isEmpty == true
            if joined { subject.send(SocketEvent(feature: feature, event: SocketEvent.joined)) }
        } else if !event.hasPrefix("phx_") {
            subject.send(SocketEvent(feature: feature, event: event))
        }
    }
}
