import Foundation

/// Owns model training so it can be kicked off once at app launch instead of
/// from a button in the UI.
@MainActor
@Observable
final class ModelTrainer {
    static let shared = ModelTrainer()

    private(set) var isTraining = false
    private(set) var lastError: Error?

    private var running: Task<Void, Never>?

    private init() {}

    static var modelURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("TaskPredictor.mlmodel")
    }

    /// Trains in the background. Skips the work when a model is already on disk
    /// unless `force` is set, and never runs two trainings at once.
    func train(force: Bool = false) {
        guard running == nil else { return }
        if !force && FileManager.default.fileExists(atPath: Self.modelURL.path) {
            return
        }

        isTraining = true
        lastError = nil

        running = Task.detached(priority: .utility) {
            var failure: Error?
            do {
                let manager = try LogicManager()
                _ = try manager.trainClassifier()
            } catch {
                failure = error
                print("Training failed: \(error)")
            }

            await MainActor.run {
                self.lastError = failure
                self.isTraining = false
                self.running = nil
            }
        }
    }
}
