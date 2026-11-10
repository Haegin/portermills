import SwiftUI

/// Sheet for creating or editing an event.
struct EventEditor: View {
    enum Target: Identifiable {
        case new(Date)
        case existing(CalendarEvent)

        var id: String {
            switch self {
            case .new(let day): return "new-\(day.timeIntervalSince1970)"
            case .existing(let event): return event.id
            }
        }
    }

    let target: Target
    let onSave: (CalendarEvent?, EventRequest) -> Void
    let onDelete: (CalendarEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var allDay = false
    @State private var start = Date.now
    @State private var end = Date.now
    @State private var confirmingDelete = false

    private var existing: CalendarEvent? {
        if case .existing(let event) = target { return event }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                    .accessibilityIdentifier("event.title")
                Section {
                    Toggle("All day", isOn: $allDay)
                    DatePicker("Starts", selection: startBinding, displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $end, in: start..., displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                if existing != nil {
                    Section {
                        Button("Delete Event", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("event.save")
                }
            }
            .confirmationDialog("Delete this event for everyone?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Event", role: .destructive) {
                    if let existing { onDelete(existing) }
                    dismiss()
                }
            }
            .onAppear(perform: populate)
        }
    }

    /// Moving the start keeps the event's length. Only the picker goes through
    /// this, so filling in the form doesn't shift the end.
    private var startBinding: Binding<Date> {
        Binding(
            get: { start },
            set: { newStart in
                end = max(newStart, end.addingTimeInterval(newStart.timeIntervalSince(start)))
                start = newStart
            }
        )
    }

    private func populate() {
        switch target {
        case .existing(let event):
            title = event.title
            notes = event.description ?? ""
            allDay = event.allDay
            start = event.startsAt
            end = event.endsAt
        case .new(let day):
            let calendar = Calendar.current
            let nextHour = calendar.component(.hour, from: .now) + 1
            start = calendar.date(bySettingHour: min(nextHour, 23), minute: 0, second: 0, of: day) ?? day
            end = start.addingTimeInterval(3600)
        }
    }

    private func save() {
        let calendar = Calendar.current
        // All-day events run from the first day's midnight to the last day's final second.
        let from = allDay ? calendar.startOfDay(for: start) : start
        let to = allDay
            ? (calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end)
            : end
        onSave(existing, EventRequest(
            title: title.trimmingCharacters(in: .whitespaces),
            description: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            startsAt: from,
            endsAt: to,
            allDay: allDay
        ))
        dismiss()
    }
}
