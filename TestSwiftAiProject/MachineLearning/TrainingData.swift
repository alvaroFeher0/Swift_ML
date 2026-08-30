import Foundation

/// The feature vector the model sees.
///
/// Training rows and live predictions are both built through this one type, so
/// the two can't drift apart — which is exactly what happened when the generator
/// and the prediction path each decided for themselves what `daysUntilDue` meant.
struct TaskFeatures{
    
    /// The ranges the synthetic generator draws from. Real values are clamped into
    /// them: a `daysUntilDue` of 400 means nothing to a model whose every training
    /// row was 0...30.
    static let daysUntilDueRange = 0...30
    static let notesLengthRange = 0...200
    
    let priority: Int
    let category: String
    let dayOfWeek: Int
    let notesLength: Int
    let daysUntilDue: Int // how many days do i have to complete the task (it does not change over time)
    let daysRemaining: Int // deadline - T
}

// Written as an extension so the memberwise init survives — `DataGenerator`
// still needs it to build synthetic rows.
extension TaskFeatures {

    /// A task with no due date is treated as due the day after it was created.
    /// Both the features and the label key off this, so it lives in one place.
    static func effectiveDueDate(for task: TodoItem, calendar: Calendar = .current) -> Date {
        if let dueDate = task.dueDate { return dueDate }
        let startOfCreationDay = calendar.startOfDay(for: task.createdAt)
        return calendar.date(byAdding: .day, value: 1, to: startOfCreationDay)!
    }

    init(task: TodoItem,today: Date, calendar: Calendar = .current) {
        let deadline = Self.effectiveDueDate(for: task, calendar: calendar)

        switch task.priority {
            case .low: priority = 1
            case .medium: priority = 2
            case .high: priority = 3
        }

        category = TaskCategory.normalize(task.listName)
        dayOfWeek = calendar.component(.weekday, from: deadline)

        let runway = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: task.createdAt),
            to: deadline
        ).day ?? 0
        
        let left = calendar.dateComponents(
               [.day],
               from: calendar.startOfDay(for: today),
               to: deadline
           ).day ?? 0

        daysUntilDue = runway.clamped(to: Self.daysUntilDueRange)
        notesLength = (task.notes?.count ?? 0).clamped(to: Self.notesLengthRange)
        daysRemaining =  left.clamped(to: Self.daysUntilDueRange)
    }
}

enum TaskOutcome {
    case onTime
    case missed
    case undecided

    static func of(_ task: TodoItem, asOf now: Date = .now, calendar: Calendar = .current) -> TaskOutcome {
        let deadline = TaskFeatures.effectiveDueDate(for: task, calendar: calendar)

        if task.isDone, let completedAt = task.completedAt {
            return completedAt <= deadline ? .onTime : .missed
        }
        return now > deadline ? .missed : .undecided
    }
}

/// One labeled row: the features, plus what actually happened.
struct TrainingItem {
    let features: TaskFeatures
    let isCompleted: Bool

    init(features: TaskFeatures, isCompleted: Bool) {
        self.features = features
        self.isCompleted = isCompleted
    }

    /// A real task becomes a training row only once its outcome is settled;
    /// returns `nil` while it is still undecided.
    init?(labeling task: TodoItem, asOf now: Date = .now, calendar: Calendar = .current) {
        switch TaskOutcome.of(task, asOf: now, calendar: calendar) {
        case .onTime: isCompleted = true
        case .missed: isCompleted = false
        case .undecided: return nil
        }
        features = TaskFeatures(task: task, today: now, calendar: calendar)
    }

    /// The labeled dataset harvested from the user's real tasks, oldest first so
    /// a chronological train/test split is just a prefix and a suffix.
    static func labeledRows(from tasks: [TodoItem], asOf now: Date = .now) -> [TrainingItem] {
        tasks
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { TrainingItem(labeling: $0, asOf: now) }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}



