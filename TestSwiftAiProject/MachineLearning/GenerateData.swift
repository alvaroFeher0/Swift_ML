import Foundation


public final class DataGenerator {
    private var baseline = 0.5
    private var tasksAmount = 1000 // amount of tasks to simulate; each yields one row per day it stayed open
    private let processCategories: Set<String> = ["Admin", "Chores", "Routine"]
    private let allCategories = TaskCategory.all
    
    private func isProcessCategory(_ category: String) -> Bool {
        processCategories.contains(category)
    }
    
    private func generateProbability(_ priority: Int, _ category: String) -> Double{
        var probability = baseline

        if priority == 3 {
            probability *= 1.7   // 70% boost for high priority
        }

        if isProcessCategory(category) {
            probability *= 0.7   // procrastination penalty — tune this number
        }

        return min(max(probability, 0), 1)
    }
    
   
    /// Which day inside the window a completed task actually got done. Taking the
    /// square root of a uniform draw biases the result towards the upper end —
    /// the tasks that get finished mostly get finished near the deadline.
    private func completionDay(runway: Int) -> Int {
        Int((Double(runway) * Double.random(in: 0..<1).squareRoot()).rounded())
    }

    /// Simulates tasks and emits one row per day each one stayed open.
    ///
    /// A single row per task can't teach the model anything about `daysRemaining`:
    /// every row would be day zero, where it equals `daysUntilDue`. Expanding a
    /// task across its open days is what gives the model examples of "still not
    /// done, three days left" and lets the prediction move as a deadline nears.
    func generateData() -> [TrainingItem]{
        var items: [TrainingItem] = []

        for _ in 0..<tasksAmount{
            // Task-level draws — constant across every row this task produces.
            let category: String = allCategories.randomElement()!
            let dayOfWeek: Int = Int.random(in: 1...7)
            let priority: Int = Int.random(in: 1...3)
            let runway = Int.random(in: TaskFeatures.daysUntilDueRange)
            let notesLength = Int.random(in: TaskFeatures.notesLengthRange)

            let probability = generateProbability(priority, category)
            let isCompleted = Double.random(in: 0..<1) < probability

            // A missed task stays open right up to its deadline; a completed one
            // stops the day it was done. That asymmetry is the whole signal: the
            // pool of still-open tasks gets more and more weighted towards misses
            // as the days run out.
            let lastOpenDay = isCompleted ? completionDay(runway: runway) : runway

            for elapsed in 0...lastOpenDay {
                let features = TaskFeatures(
                    priority: priority,
                    category: category,
                    dayOfWeek: dayOfWeek,
                    notesLength: notesLength,
                    daysUntilDue: runway,
                    daysRemaining: runway - elapsed
                )
                items.append(TrainingItem(features: features, isCompleted: isCompleted))
            }
        }

        return items
    }
    
    
    
}
