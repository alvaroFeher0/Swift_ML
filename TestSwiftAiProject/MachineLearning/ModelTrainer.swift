import CreateML

public final class LogicManager {
    
    private let dataGenerator = DataGenerator()
    
    public func getDataTable() throws -> MLDataTable{
        let data = dataGenerator.generateData()
        
        let priorities = data.map { $0.priority }
        let categories = data.map { $0.category }
        let daysOfWeek = data.map { $0.dayOfWeek }
        let daysUntilDue = data.map { $0.daysUntilDue }
        let notesLengths = data.map { $0.notesLength }
        let isCompletedValues = data.map { $0.isCompleted }
    
        let table = try MLDataTable(dictionary: [
            "priority": priorities,
            "category": categories,
            "dayOfWeek": daysOfWeek,
            "daysUntilDue": daysUntilDue,
            "notesLength": notesLengths,
            "isCompleted": isCompletedValues
        ])
        
        return table
    }
    
}
