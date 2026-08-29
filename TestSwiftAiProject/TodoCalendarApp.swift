import SwiftUI
import SwiftData

@main
struct TodoCalendarApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    ModelTrainer.shared.train()
                }
        }
        .modelContainer(for: TodoItem.self)
    }
}
