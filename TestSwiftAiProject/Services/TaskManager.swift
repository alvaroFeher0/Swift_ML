
import Foundation
import EventKit
@Observable
final class TaskManager {
    
   public func buildAgenda(tasks: [TodoItem], events: [EKEvent], reminders: [EKReminder], predictor: TaskPredictor?) -> [AgendaItem] {


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

    /// Everything the user ticked off today, most recently completed first.
    /// `time` carries the completion date here rather than the due date.
    public func buildDoneToday(tasks: [TodoItem], reminders: [EKReminder]) -> [AgendaItem] {
        let calendar = Calendar.current

        let taskItems = tasks
            .compactMap { task -> AgendaItem? in
                guard task.isDone, let completedAt = task.completedAt,
                      calendar.isDateInToday(completedAt) else { return nil }
                return AgendaItem(
                    id: task.id.uuidString,
                    title: task.title,
                    time: completedAt,
                    completionPercentage: nil,
                    kind: .task(task)
                )
            }

        // The caller only ever hands us reminders completed today, so there is
        // nothing to filter here.
        let reminderItems = reminders
            .map { AgendaItem(id: $0.calendarItemIdentifier, title: $0.title ?? "Untitled", time: $0.completionDate, completionPercentage: nil, kind: .reminder($0)) }

        return (taskItems + reminderItems).sorted {
            ($0.time ?? .distantPast) > ($1.time ?? .distantPast)
        }
    }
}
