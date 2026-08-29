import SwiftUI
import SwiftData
import EventKit

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var tasks: [TodoItem]
    @State private var showingAdd = false
    @State private var showingOldTasks = false
    @State private var calendarManager = CalendarManager()
    @State private var taskManager = TaskManager()
    @State private var agenda: [AgendaItem] = []
    @State private var remindersAccessGranted = true
    private var trainer = ModelTrainer.shared

    /// Anything already due before today. Items with no time at all count as
    /// "today", so they stay in the main list rather than hiding away.
    private var oldItems: [AgendaItem] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return agenda.filter { ($0.time ?? .distantFuture) < startOfToday }
    }

    private var todayItems: [AgendaItem] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return agenda.filter { ($0.time ?? .distantFuture) >= startOfToday }
    }

    var body: some View {
        NavigationStack {
            List {
                if !remindersAccessGranted {
                    Text("Reminders access is off, so your reminders aren't shown. Turn it on in Settings › Privacy & Security › Reminders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !oldItems.isEmpty {
                    Section {
                        if showingOldTasks {
                            ForEach(oldItems) { item in
                                AgendaRow(item: item) { complete(item) }
                            }
                        }
                    } header: {
                        Button {
                            withAnimation { showingOldTasks.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(showingOldTasks ? 90 : 0))
                                Text("Earlier")
                                Spacer()
                                Text("\(oldItems.count)")
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Earlier, \(oldItems.count) items")
                        .accessibilityHint(showingOldTasks ? "Hides earlier items" : "Shows earlier items")
                    }
                }

                Section("Today") {
                    ForEach(todayItems) { item in
                        AgendaRow(item: item) { complete(item) }
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
            .sheet(isPresented: $showingAdd, onDismiss: refresh) {
                AddTaskView()
            }
            .task {
                _ = await calendarManager.requestAccess()
                remindersAccessGranted = await calendarManager.requestRemindersAccess()
                await refreshAgenda()
            }
            .onChange(of: tasks) { refresh() }
            .onChange(of: trainer.predictorGeneration) { refresh() }
        }
    }

    /// Ticks an agenda item off, wherever it lives. Events are read-only here.
    private func complete(_ item: AgendaItem) {
        switch item.kind {
        case .task(let task):
            task.toggleCompletion()
        case .reminder(let reminder):
            calendarManager.setCompleted(reminder, completed: true)
        case .event:
            return
        }
        refresh()
    }

    /// Fire-and-forget wrapper, for the synchronous callbacks.
    private func refresh() {
        Task { await refreshAgenda() }
    }

    private func refreshAgenda() async {
        let events = calendarManager.eventsToday()
        let reminders = remindersAccessGranted ? await calendarManager.incompleteReminders() : []
        agenda = taskManager.buildAgenda(tasks: tasks, events: events, reminders: reminders, predictor: trainer.predictor)
    }
}

struct AgendaRow: View {
    let item: AgendaItem
    let onComplete: () -> Void

    var body: some View {
        HStack {
            switch item.kind {
            case .task(let task):
                Button(action: onComplete) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)
            case .reminder:
                Button(action: onComplete) {
                    Image(systemName: "circle")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            case .event:
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading) {
                Text(item.title)
                if let time = item.time {
                    Text(time, format: .dateTime.day().month().hour().minute())

                } else {
                    Text("Anytime today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if case .reminder(let reminder) = item.kind {
                    Text(reminder.calendar.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let percentage = item.completionPercentage {
                Spacer()
                CompletionRing(percentage: percentage)

                // add more rings with the probability of completing the task the next few days
                //Spacer()
                //CompletionRing(percentage: percentage)
            }
        }
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
