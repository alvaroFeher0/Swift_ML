import SwiftUI
import SwiftData
import EventKit

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var tasks: [TodoItem]
    @State private var showingAdd = false
    @State private var calendarManager = CalendarManager()
    @State private var agenda: [AgendaItem] = []
    @State private var remindersAccessGranted = true
    private var trainer = ModelTrainer.shared

    var body: some View {
        NavigationStack {
            List {
                if !remindersAccessGranted {
                    Text("Reminders access is off, so your reminders aren't shown. Turn it on in Settings › Privacy & Security › Reminders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(agenda) { item in
                    HStack {
                        switch item.kind {
                        case .task(let task):
                            Button {
                                task.toggleCompletion()
                                refresh()
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                        case .reminder(let reminder):
                            Button {
                                calendarManager.setCompleted(reminder, completed: true)
                                refresh()
                            } label: {
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

    /// Fire-and-forget wrapper, for the synchronous callbacks.
    private func refresh() {
        Task { await refreshAgenda() }
    }

    private func refreshAgenda() async {
        let events = calendarManager.eventsToday()
        let reminders = remindersAccessGranted ? await calendarManager.incompleteReminders() : []
        agenda = buildAgenda(tasks: tasks, events: events, reminders: reminders, predictor: trainer.predictor)
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

func buildAgenda(tasks: [TodoItem], events: [EKEvent], reminders: [EKReminder], predictor: TaskPredictor?) -> [AgendaItem] {


    let taskItems = tasks
        .filter { !$0.isDone }
        .map { task -> AgendaItem in
            var percentage: Double?
            if let predictor {
                do {
                    percentage = try LogicManager.predictTask(todoTask: task, using: predictor)
                } catch {
                    print("Prediction failed for \(task.title): \(error)")
                }
            }

            return AgendaItem(
                id: task.id.uuidString,
                title: task.title,
                time: task.dueDate,
                completionPercentage: percentage,
                kind: .task(task)
            )
        }

    let eventItems = events
        .map { AgendaItem(id: $0.eventIdentifier, title: $0.title ?? "Untitled", time: $0.startDate, completionPercentage: nil, kind: .event($0)) }

    // The caller only ever hands us incomplete reminders, so there is nothing to
    // filter here — the Reminders app is the source of truth for "done".
    let reminderItems = reminders
        .map { AgendaItem(id: $0.calendarItemIdentifier, title: $0.title ?? "Untitled", time: $0.resolvedDueDate, completionPercentage: nil, kind: .reminder($0)) }

    let combined = taskItems + eventItems + reminderItems
    return combined.sorted { a, b in
        switch (a.time, b.time) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case let (t1?, t2?): return t1 < t2
        }
    }
}
