import Foundation


public final class DataGenerator {
    private var baseline = 0.5
    private var itemsAmount = 1000 // amount of items to be generated
  
    struct TrainingItem{
        let isCompleted: Bool
        let category: String
        let dayOfWeek: Int // 1 to 7
        let priority: Int // 1 = low, 2 = medium, 3 = high
        let daysUntilDue: Int
        let notesLength: Int
    }
    
    private let processCategories: Set<String> = ["Admin", "Chores", "Routine"]
    private let allCategories = TaskCategory.all
    
    private func isProcessCategory(_ category: String) -> Bool {
        processCategories.contains(category)
    }
    
    private func generateProbability(_ priority: Int, _ category: String) -> Double{
        var probability = baseline

        if priority == 3 {
            probability *= 1.7   // your 70% boost for high priority
        }

        if isProcessCategory(category) {
            probability *= 0.7   // procrastination penalty — tune this number yourself
        }

        return min(max(probability, 0), 1)
    }
    
    func generateData() -> [TrainingItem]{
        var items: [TrainingItem] = []
        
        for _ in 0..<itemsAmount{
            let category: String = allCategories.randomElement()!
            let dayOfWeek: Int = Int.random(in: 1...7)
            let priority: Int = Int.random(in: 1...3)
            let daysUntilDue = Int.random(in: 0...30)
            let notesLength = Int.random(in: 0...200)
            let probability = generateProbability(priority, category)
            let isCompleted = Double.random(in: 0..<1) < probability
            
            items.append(TrainingItem(
                isCompleted: isCompleted,
                category: category,
                dayOfWeek: dayOfWeek,
                priority: priority,
                daysUntilDue: daysUntilDue,
                notesLength: notesLength
            ))
        }
        
        return items
    }
    
    
    
}
