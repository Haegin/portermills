import Foundation

@MainActor
final class CalendarViewModel: LiveViewModel {
    @Published private(set) var month: Date
    @Published var selected: Date
    @Published private(set) var eventsByDay: [Date: [CalendarEvent]] = [:]

    let calendar = Calendar.current

    init() {
        let today = Calendar.current.startOfDay(for: .now)
        month = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
        selected = today
        super.init(feature: "calendar")
    }

    /// The 42 days shown in the month grid: six full weeks.
    var gridDays: [Date] {
        let weekday = calendar.component(.weekday, from: month)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: month) ?? month
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var selectedEvents: [CalendarEvent] { eventsByDay[selected] ?? [] }

    func isInMonth(_ day: Date) -> Bool { calendar.isDate(day, equalTo: month, toGranularity: .month) }

    func showMonth(offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: month) else { return }
        show(month: next)
    }

    func showToday() {
        let today = calendar.startOfDay(for: .now)
        show(month: calendar.dateInterval(of: .month, for: today)?.start ?? today)
    }

    func select(_ day: Date) {
        if !isInMonth(day), let start = calendar.dateInterval(of: .month, for: day)?.start {
            show(month: start)
        }
        selected = day
    }

    private func show(month newMonth: Date) {
        month = newMonth
        let today = calendar.startOfDay(for: .now)
        selected = isInMonth(today) ? today : newMonth
        Task { await load() }
    }

    override func load() async {
        let days = gridDays
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return }
        let format = ISO8601DateFormatter()
        let path = "/calendar/events?from=\(format.string(from: first))&to=\(format.string(from: end))"

        do {
            let events = try await api.get(path, as: [CalendarEvent].self)
            var byDay: [Date: [CalendarEvent]] = [:]
            for event in events {
                for day in event.days(in: calendar) { byDay[day, default: []].append(event) }
            }
            eventsByDay = byDay.mapValues { list in
                list.sorted { ($0.allDay ? 0 : 1, $0.startsAt) < ($1.allDay ? 0 : 1, $1.startsAt) }
            }
        } catch {
            self.error = error.userMessage
        }
    }

    func save(_ existing: CalendarEvent?, _ request: EventRequest) {
        perform {
            if let existing {
                try await self.api.send("PATCH", "/calendar/events/\(existing.id)", body: request)
            } else {
                try await self.api.send("POST", "/calendar/events", body: request)
            }
        }
    }

    func delete(_ event: CalendarEvent) {
        perform { try await self.api.send("DELETE", "/calendar/events/\(event.id)") }
    }
}
