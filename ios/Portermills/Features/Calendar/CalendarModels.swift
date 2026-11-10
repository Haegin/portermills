import Foundation

struct CalendarEvent: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let startsAt: Date
    let endsAt: Date
    let allDay: Bool
    let createdById: String?

    /// The start of every local day the event touches.
    func days(in calendar: Calendar) -> [Date] {
        let first = calendar.startOfDay(for: startsAt)
        // An event ending exactly at midnight doesn't count for the next day.
        let lastMoment = endsAt > startsAt ? endsAt.addingTimeInterval(-1) : endsAt
        let last = max(first, calendar.startOfDay(for: lastMoment))
        var days: [Date] = []
        var day = first
        while day <= last {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}

/// Body for creating or updating an event.
struct EventRequest: Encodable {
    let title: String
    let description: String
    let startsAt: Date
    let endsAt: Date
    let allDay: Bool
}
