import CoreML
import Foundation

/// Owns model training and the loaded predictor, so both stay off the main thread
/// and training can be kicked off at app launch instead of from a button.
@MainActor
@Observable
final class ModelTrainer {
    static let shared = ModelTrainer()

    private(set) var isTraining = false
    private(set) var lastError: Error?

    /// The loaded model. `nil` until it has been compiled and loaded in the background.
    private(set) var predictor: TaskPredictor?
    /// Bumped whenever `predictor` changes, so views can refresh on it.
    private(set) var predictorGeneration = 0

    private var running: Task<Void, Never>?

    private init() {}

    /// Trains, then loads the result. Skips training when a model is already on
    /// disk unless `force` is set, but still loads the predictor either way.
    func train(force: Bool = false) {
        guard running == nil else { return }

        let alreadyTrained = FileManager.default.fileExists(atPath: LogicManager.trainedModelURL.path)
        let shouldTrain = force || !alreadyTrained
        if !shouldTrain {
            print("Training skipped: model already exists, loading it instead")
        }

        isTraining = shouldTrain
        lastError = nil

        running = Task.detached(priority: .utility) {
            var failure: Error?
            var loaded: TaskPredictor?

            do {
                if shouldTrain {
                    print("Training started")
                    let manager = try LogicManager()
                    _ = try manager.trainClassifier()
                }
                // compileModel() must not run on the main thread
                loaded = try LogicManager.makePredictor()
                print("Predictor ready")
            } catch {
                failure = error
                print("Training/loading failed: \(error)")
            }

            await MainActor.run {
                if let loaded {
                    self.predictor = loaded
                    self.predictorGeneration += 1
                }
                self.lastError = failure
                self.isTraining = false
                self.running = nil
            }
        }
    }
}
