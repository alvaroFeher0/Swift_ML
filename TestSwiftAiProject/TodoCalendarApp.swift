import SwiftUI
import SwiftData

@main
struct TodoCalendarApp: App {
    /// Built by hand rather than via `.modelContainer(for:)` so the trainer can be
    /// handed the same container and open its own background context.
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: TodoItem.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    ModelTrainer.shared.train(container: container)
                }
        }
        .modelContainer(container)
    }
}
