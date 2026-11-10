import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let startsAt: Date
    let endsAt: Date
    let allDay: Bool
    let recurrenceRule: String?
    let createdById: String
}

struct CreateEventRequest: Encodable {
    let title: String
    let description: String?
    let startsAt: Date
    let endsAt: Date
    let allDay: Bool
}
