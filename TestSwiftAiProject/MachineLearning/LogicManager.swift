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

        let priorities = Column(name: "priority", contents: rows.map { $0.features.priority })
        let categories = Column(name: "category", contents: rows.map { $0.features.category })
        let daysOfWeek = Column(name: "dayOfWeek", contents: rows.map { $0.features.dayOfWeek })
        let daysUntilDue = Column(name: "daysUntilDue", contents: rows.map { $0.features.daysUntilDue })
        let daysRemaining = Column(name: "daysRemaining", contents: rows.map { $0.features.daysRemaining })
        let notesLengths = Column(name: "notesLength", contents: rows.map { $0.features.notesLength })
        let isCompletedValues = Column(name: "isCompleted", contents: rows.map { $0.isCompleted ? 1 : 0 })

        return DataFrame(columns: [
            priorities.eraseToAnyColumn(),
            categories.eraseToAnyColumn(),
            daysOfWeek.eraseToAnyColumn(),
            daysUntilDue.eraseToAnyColumn(),
            daysRemaining.eraseToAnyColumn(),
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
        let f = TaskFeatures(task: todoTask, today:Date())

        let input = TaskPredictorInput(
                priority: Int64(f.priority),
                category: f.category,
                dayOfWeek: Int64(f.dayOfWeek),
                daysUntilDue: Int64(f.daysUntilDue),
                daysRemaining: Int64(f.daysRemaining),
                notesLength: Int64(f.notesLength),
            )

        let output = try model.prediction(input: input)
        return (output.isCompletedProbability[1] ?? 0.0) * 100
    }
}
