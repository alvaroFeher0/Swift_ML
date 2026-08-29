import EventKit

extension EKReminder {
    /// `dueDateComponents` resolved against the current calendar. `nil` for
    /// reminders with no due date at all.
    var resolvedDueDate: Date? {
        guard let dueDateComponents else { return nil }
        return Calendar.current.date(from: dueDateComponents)
    }
}

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

    func requestRemindersAccess() async -> Bool {
            do {
                return try await store.requestFullAccessToReminders()
            } catch {
                print("🔴 reminders access error: \(error)")
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

    /// Every reminder the user has not ticked off yet, across all reminder lists.
    ///
    /// Passing `nil` for both bounds keeps reminders with no due date, which the
    /// agenda shows as "Anytime". Reminders that are due sort first, oldest first.
    func incompleteReminders() async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            let predicate = store.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: nil
            )
            store.fetchReminders(matching: predicate) { reminders in
                let sorted = (reminders ?? []).sorted {
                    ($0.resolvedDueDate ?? .distantFuture) < ($1.resolvedDueDate ?? .distantFuture)
                }
                continuation.resume(returning: sorted)
            }
        }
    }

    /// Every reminder ticked off since midnight, across all reminder lists.
    func remindersCompletedToday() async -> [EKReminder] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return await withCheckedContinuation { continuation in
            let predicate = store.predicateForCompletedReminders(
                withCompletionDateStarting: startOfDay,
                ending: endOfDay,
                calendars: nil
            )
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Writes the completion flag back to the Reminders app.
    func setCompleted(_ reminder: EKReminder, completed: Bool) {
        reminder.isCompleted = completed
        do {
            try store.save(reminder, commit: true)
        } catch {
            print("🔴 could not save reminder '\(reminder.title ?? "")': \(error)")
        }
    }
}
