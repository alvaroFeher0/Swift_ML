import SwiftUI
import SwiftData

@main
struct TodoCalendarApp: App {
    var body: some Scene {
        WindowGroup {
            TaskListView()
        }
        .modelContainer(for: TodoItem.self)
    }
}
