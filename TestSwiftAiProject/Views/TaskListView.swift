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
                                Text(time, format: .dateTime.day().month().hour().minute())
        
                            } else {
                                Text("Anytime today")
                                    .font(.caption)
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
            .sheet(isPresented: $showingAdd, onDismiss: refreshAgenda) {
                AddTaskView()
            }
            .task {
                _ = await calendarManager.requestAccess()
                _= await calendarManager.requestRemindersAccess()
                refreshAgenda()
            }
            .onChange(of: tasks) { refreshAgenda() }
            .onChange(of: trainer.predictorGeneration) { refreshAgenda() }
        }
    }

    private func refreshAgenda() {
        let events = calendarManager.eventsToday()
        agenda = buildAgenda(tasks: tasks, events: events, predictor: trainer.predictor)
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

func buildAgenda(tasks: [TodoItem], events: [EKEvent], predictor: TaskPredictor?) -> [AgendaItem] {
    
    
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
