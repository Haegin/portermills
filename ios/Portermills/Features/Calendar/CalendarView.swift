import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var editing: EventEditor.Target?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthGrid(viewModel: viewModel)
                    .padding(.horizontal, 8)
                    .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                        if value.translation.width < -50 { viewModel.showMonth(offset: 1) }
                        if value.translation.width > 50 { viewModel.showMonth(offset: -1) }
                    })
                Divider()
                dayList
            }
            .navigationTitle(viewModel.month.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { viewModel.showMonth(offset: -1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous month")
                    Button("Today") { viewModel.showToday() }
                    Button { viewModel.showMonth(offset: 1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next month")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { editing = .new(viewModel.selected) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add event")
                        .accessibilityIdentifier("calendar.add")
                    AccountMenu()
                }
            }
            .sheet(item: $editing) { target in
                EventEditor(target: target, onSave: viewModel.save, onDelete: viewModel.delete)
            }
            .errorAlert($viewModel.error)
            .task { await viewModel.load() }
        }
    }

    private var dayList: some View {
        List {
            Section(viewModel.selected.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                if viewModel.selectedEvents.isEmpty {
                    Text("Nothing planned").foregroundStyle(.secondary)
                }
                ForEach(viewModel.selectedEvents) { event in
                    Button { editing = .existing(event) } label: {
                        EventRow(event: event, day: viewModel.selected, calendar: viewModel.calendar)
                    }
                    .foregroundStyle(.primary)
                    .swipeActions {
                        Button("Delete", role: .destructive) { viewModel.delete(event) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.load() }
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    let day: Date
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeLabel).font(.caption).foregroundStyle(.secondary)
            Text(event.title).font(.body)
            if let description = event.description, !description.isEmpty {
                Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timeLabel: String {
        let startsToday = calendar.isDate(event.startsAt, inSameDayAs: day)
        let endsToday = calendar.isDate(event.endsAt, inSameDayAs: day)
        let time = Date.FormatStyle(date: .omitted, time: .shortened)
        switch (event.allDay, startsToday, endsToday) {
        case (true, _, _): return "All day"
        case (false, true, true): return "\(event.startsAt.formatted(time)) – \(event.endsAt.formatted(time))"
        case (false, true, false): return "From \(event.startsAt.formatted(time))"
        case (false, false, true): return "Until \(event.endsAt.formatted(time))"
        default: return "All day"
        }
    }
}

private struct MonthGrid: View {
    @ObservedObject var viewModel: CalendarViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            ForEach(viewModel.gridDays, id: \.self) { day in
                DayCell(
                    day: day,
                    inMonth: viewModel.isInMonth(day),
                    isToday: viewModel.calendar.isDateInToday(day),
                    isSelected: day == viewModel.selected,
                    eventCount: viewModel.eventsByDay[day]?.count ?? 0
                )
                .onTapGesture { viewModel.select(day) }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let eventCount: Int

    var body: some View {
        VStack(spacing: 3) {
            Text(day.formatted(.dateTime.day()))
                .font(.body.weight(isToday ? .bold : .regular))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    } else if isToday {
                        Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
            HStack(spacing: 3) {
                ForEach(0..<min(eventCount, 3), id: \.self) { _ in
                    Circle().fill(Color.orange.opacity(inMonth ? 1 : 0.4)).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var foreground: Color {
        if isSelected { return .white }
        if !inMonth { return .secondary.opacity(0.5) }
        if isToday { return .accentColor }
        return .primary
    }

    private var accessibilityText: String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        switch eventCount {
        case 0: return date
        case 1: return "\(date), 1 event"
        default: return "\(date), \(eventCount) events"
        }
    }
}
