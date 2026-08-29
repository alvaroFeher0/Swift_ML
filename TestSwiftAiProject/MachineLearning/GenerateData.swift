import Foundation


public final class DataGenerator {
    private var baseline = 0.5
    private var itemsAmount = 1000 // amount of items to be generated
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
    
   
    func generateData() -> [TrainingItem]{
        var items: [TrainingItem] = []
        
        for _ in 0..<itemsAmount{
            let category: String = allCategories.randomElement()!
            let dayOfWeek: Int = Int.random(in: 1...7)
            let priority: Int = Int.random(in: 1...3)
            let daysUntilDue = Int.random(in: TaskFeatures.daysUntilDueRange)
            let notesLength = Int.random(in: TaskFeatures.notesLengthRange)
            let probability = generateProbability(priority, category)
            let isCompleted = Double.random(in: 0..<1) < probability
            
            let features = TaskFeatures(
                priority: priority,
                category: category,
                dayOfWeek: dayOfWeek,
                notesLength: notesLength, 
                daysUntilDue: daysUntilDue
            )
            items.append(TrainingItem(features: features, isCompleted: isCompleted))
        }
        
        return items
    }
    
    
    
}
