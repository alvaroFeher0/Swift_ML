import CoreML
import CreateML
import Foundation
import TabularData

public final class LogicManager {

    /// Where `trainClassifier()` writes the freshly trained model. The vocabulary
    /// version is in the filename so a category-set change retrains automatically
    /// instead of loading a model with a stale one-hot encoding.
    static var trainedModelURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("TaskPredictor-v\(TaskCategory.vocabularyVersion).mlmodel")
    }

    private let dataGenerator = DataGenerator()
    private let data: DataFrame
    private let trainingSet: DataFrame
    private let testSet: DataFrame
     
    
    init() throws {
        self.data = LogicManager.buildDataFrame(using: dataGenerator)
        let split = LogicManager.splitDataFrame(self.data)
        self.trainingSet = split.training
        self.testSet = split.test
    }

    private static func buildDataFrame(using generator: DataGenerator) -> DataFrame {
        let rows = generator.generateData()

        let priorities = Column(name: "priority", contents: rows.map { $0.priority })
        let categories = Column(name: "category", contents: rows.map { $0.category })
        let daysOfWeek = Column(name: "dayOfWeek", contents: rows.map { $0.dayOfWeek })
        let daysUntilDue = Column(name: "daysUntilDue", contents: rows.map { $0.daysUntilDue })
        let notesLengths = Column(name: "notesLength", contents: rows.map { $0.notesLength })
        let isCompletedValues = Column(name: "isCompleted", contents: rows.map { $0.isCompleted ? 1 : 0 })

        return DataFrame(columns: [
            priorities.eraseToAnyColumn(),
            categories.eraseToAnyColumn(),
            daysOfWeek.eraseToAnyColumn(),
            daysUntilDue.eraseToAnyColumn(),
            notesLengths.eraseToAnyColumn(),
            isCompletedValues.eraseToAnyColumn()
        ])
    }

    private static func splitDataFrame(_ df: DataFrame, testSize: Double = 0.2) -> (training: DataFrame, test: DataFrame) {
        let trainFraction = 1.0 - testSize
        let (trainingSlice, testSlice) = df.randomSplit(by: trainFraction, seed: 5)
        return (training: DataFrame(trainingSlice), test: DataFrame(testSlice))
    }

    public func trainClassifier() throws -> MLClassifier {
        let classifier = try MLClassifier(trainingData: trainingSet, targetColumn: "isCompleted")

        let trainingAccuracy = 1.0 - classifier.trainingMetrics.classificationError
        let testAccuracy = 1.0 - classifier.evaluation(on: testSet).classificationError

        print("Training accuracy: \(trainingAccuracy)")
        print("Test accuracy: \(testAccuracy)")
        
        let modelURL = LogicManager.trainedModelURL
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
        try classifier.write(to: modelURL, metadata: nil)
        print("Model saved to: \(modelURL)")

        return classifier
    }
    
    
    private static func convertTodoToTrainData(todoItem: TodoItem) throws -> (priority: Int, category: String, dayOfWeek: Int, daysUntilDue: Int, notesLength: Int){
        let calendar = Calendar.current
        let priority: Int
        
        switch todoItem.priority {
          case .low: priority = 1
          case .medium: priority = 2
          case .high: priority = 3
        }
        
        let category = TaskCategory.normalize(todoItem.listName)
        let effectiveDueDate: Date
        if let dueDate = todoItem.dueDate {
            effectiveDueDate = dueDate
        } else {
            let startOfCreationDay = calendar.startOfDay(for: todoItem.createdAt)
            effectiveDueDate = calendar.date(byAdding: .day, value: 1, to: startOfCreationDay)!
        }

        let dayOfWeek = calendar.component(.weekday, from: effectiveDueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: .now, to: effectiveDueDate).day ?? 0
        let notesLength = todoItem.notes?.count ?? 0
        
        return (priority, category, dayOfWeek, daysUntilDue, notesLength)
    }
    
    /// Compiles and loads the model trained at launch, falling back to the one
    /// bundled with the app. `trainClassifier()` writes an uncompiled `.mlmodel`,
    /// so Core ML has to compile it before it can be loaded.
    ///
    /// Call this off the main thread — `compileModel` warns and blocks otherwise.
    nonisolated static func makePredictor() throws -> TaskPredictor {
        if FileManager.default.fileExists(atPath: trainedModelURL.path) {
            let compiledURL = try MLModel.compileModel(at: trainedModelURL)
            return try TaskPredictor(contentsOf: compiledURL)
        }
        return try TaskPredictor(configuration: MLModelConfiguration())
    }

    // predict how likely is a task to be completed in time, as a 0-100 percentage
    static func predictTask(todoTask: TodoItem, using model: TaskPredictor) throws -> Double {
        let f = try LogicManager.convertTodoToTrainData(todoItem: todoTask)

        let input = TaskPredictorInput(
                priority: Int64(f.priority),
                category: f.category,
                dayOfWeek: Int64(f.dayOfWeek),
                daysUntilDue: Int64(f.daysUntilDue),
                notesLength: Int64(f.notesLength),
            )

        let output = try model.prediction(input: input)
        return (output.isCompletedProbability[1] ?? 0.0) * 100
    }
}
