import SwiftUI

struct CalendarView: View {
    @StateObject private var vm = CalendarViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.events.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(vm.events) { event in
                            EventRow(event: event)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteEvent(event) }
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Calendar")
            .task { await vm.load() }
        }
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.headline)
            Text(event.startsAt, style: .date).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
