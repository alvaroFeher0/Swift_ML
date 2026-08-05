import CreateML
import Foundation
import TabularData

public final class LogicManager {

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
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelURL = documentsURL.appendingPathComponent("TaskPredictor.mlmodel")
        try classifier.write(to: modelURL, metadata: nil)
        print("Model saved to: \(modelURL)")

        return classifier
    }
}
