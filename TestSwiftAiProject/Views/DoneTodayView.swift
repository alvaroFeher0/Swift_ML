import SwiftUI
import SwiftData
import EventKit

struct DoneTodayView: View {
    @Query(sort: \TodoItem.completedAt, order: .reverse) private var tasks: [TodoItem]
    @State private var calendarManager = CalendarManager()
    @State private var taskManager = TaskManager()
    @State private var done: [AgendaItem] = []
    @State private var remindersAccessGranted = true

    var body: some View {
        NavigationStack {
            List {
                if done.isEmpty {
                    Text("Nothing ticked off yet today.")
                        .foregroundStyle(.secondary)
                }

                ForEach(done) { item in
                    HStack {
                        Button {
                            undo(item)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading) {
                            Text(item.title)
                                .strikethrough()
                                .foregroundStyle(.secondary)

                            if let time = item.time {
                                Text(time, format: .dateTime.hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if case .reminder(let reminder) = item.kind {
                                Text(reminder.calendar.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Done Today")
            .task {
                remindersAccessGranted = await calendarManager.requestRemindersAccess()
                await refreshDone()
            }
            .onChange(of: tasks) { refresh() }
        }
    }

    /// Puts an item back on the agenda.
    private func undo(_ item: AgendaItem) {
        switch item.kind {
        case .task(let task):
            task.toggleCompletion()
        case .reminder(let reminder):
            calendarManager.setCompleted(reminder, completed: false)
        case .event:
            return
        }
        refresh()
    }

    /// Fire-and-forget wrapper, for the synchronous callbacks.
    private func refresh() {
        Task { await refreshDone() }
    }

    private func refreshDone() async {
        let reminders = remindersAccessGranted ? await calendarManager.remindersCompletedToday() : []
        done = taskManager.buildDoneToday(tasks: tasks, reminders: reminders)
    }
}
