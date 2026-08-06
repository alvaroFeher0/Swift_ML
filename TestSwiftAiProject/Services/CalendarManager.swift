import EventKit

@Observable
final class CalendarManager {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("🔴 calendar access error: \(error)")
            return false
        }
    }

    func eventsToday() -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
    
    func buildAgenda(tasks: [TodoItem], events: [EKEvent]) -> [AgendaItem] {
        let taskItems = tasks
            .filter { !$0.isDone }
            .map { AgendaItem(id: $0.id.uuidString, title: $0.title, time: $0.dueDate, completionPercentage: 10, kind: .task($0)) }

        let eventItems = events
            .map { AgendaItem(id: $0.eventIdentifier, title: $0.title ?? "Untitled", time: $0.startDate, completionPercentage: 10, kind: .event($0)) }

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
}
