import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var error: String?

    private var currentMonth: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: displayedMonth)
    }

    @Published var displayedMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now))!

    func load() async {
        isLoading = true
        do {
            events = try await APIClient.shared.get("/calendar/events?month=\(currentMonth)")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createEvent(_ req: CreateEventRequest) async throws {
        let event: CalendarEvent = try await APIClient.shared.post("/calendar/events", body: req)
        events.append(event)
        events.sort { $0.startsAt < $1.startsAt }
    }

    func deleteEvent(_ event: CalendarEvent) async {
        try? await APIClient.shared.delete("/calendar/events/\(event.id)")
        events.removeAll { $0.id == event.id }
    }
}
