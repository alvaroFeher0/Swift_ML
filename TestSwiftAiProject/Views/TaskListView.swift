import SwiftUI
import SwiftData
import EventKit

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var tasks: [TodoItem]
    @State private var showingAdd = false
    @State private var calendarManager = CalendarManager()
    @State private var agenda: [AgendaItem] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(agenda) { item in
                    HStack {
                        switch item.kind {
                        case .task(let task):
                            Button {
                                task.isDone.toggle()
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
            }
            .sheet(isPresented: $showingAdd, onDismiss: refreshAgenda) {
                AddTaskView()
            }
            .task {
                _ = await calendarManager.requestAccess()
                refreshAgenda()
            }
            .onChange(of: tasks) { refreshAgenda() }
            .onAppear {
                do {
                       let data = try LogicManager().getDataTable()
                       print(data)
                   } catch {
                       print("Failed to build data table: \(error)")
                   }
            }
        }
    }

    private func refreshAgenda() {
        let events = calendarManager.eventsToday()
        agenda = buildAgenda(tasks: tasks, events: events)
    }
}

func buildAgenda(tasks: [TodoItem], events: [EKEvent]) -> [AgendaItem] {
    let taskItems = tasks
        .filter { !$0.isDone }
        .map { AgendaItem(id: $0.id.uuidString, title: $0.title, time: $0.dueDate, kind: .task($0)) }

    let eventItems = events
        .map { AgendaItem(id: $0.eventIdentifier, title: $0.title ?? "Untitled", time: $0.startDate, kind: .event($0)) }

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
