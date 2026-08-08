import SwiftUI
import SwiftData
import EventKit

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var tasks: [TodoItem]
    @State private var showingAdd = false
    @State private var calendarManager = CalendarManager()
    @State private var agenda: [AgendaItem] = []
    private var trainer = ModelTrainer.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(agenda) { item in
                    HStack {
                        switch item.kind {
                        case .task(let task):
                            Button {
                                task.toggleCompletion()
                                refreshAgenda()
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                        case .event:
                            Image(systemName: "calendar")
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading) {
                            Text(item.title)
                            if let time = item.time {
                                Text(time, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Anytime today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let percentage = item.completionPercentage {
                            Spacer()
                            CompletionRing(percentage: percentage)
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
                if trainer.isTraining {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showingAdd, onDismiss: refreshAgenda) {
                AddTaskView()
            }
            .task {
                _ = await calendarManager.requestAccess()
                refreshAgenda()
            }
            .onChange(of: tasks) { refreshAgenda() }
        }
    }

    private func refreshAgenda() {
        let events = calendarManager.eventsToday()
        agenda = buildAgenda(tasks: tasks, events: events)
    }
}

struct CompletionRing: View {
    let percentage: Double

    private var clamped: Double { min(max(percentage, 0), 100) }

    private var color: Color {
        switch clamped {
        case ..<50: return .red
        case ..<70: return .orange
        default: return .green
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: clamped / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(clamped.rounded()))")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(width: 40, height: 40)
        .animation(.easeInOut, value: clamped)
        .accessibilityElement()
        .accessibilityLabel("Completion \(Int(clamped.rounded())) percent")
    }
}

func buildAgenda(tasks: [TodoItem], events: [EKEvent]) -> [AgendaItem] {
    let taskItems = tasks
        .filter { !$0.isDone }
        .map { AgendaItem(id: $0.id.uuidString, title: $0.title, time: $0.dueDate, completionPercentage: 10.0, kind: .task($0)) }

    let eventItems = events
        .map { AgendaItem(id: $0.eventIdentifier, title: $0.title ?? "Untitled", time: $0.startDate, completionPercentage: nil, kind: .event($0)) }

    let combined = taskItems + eventItems
    return combined.sorted { a, b in
        switch (a.time, b.time) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case let (t1?, t2?): return t1 < t2
        }
    }
}
