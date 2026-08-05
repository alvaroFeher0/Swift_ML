import Foundation
import SwiftData

enum Priority: String, Codable, CaseIterable {
    case low
    case medium
    case high
}

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var notes: String?
    var dueDate: Date?
    var priority: Priority
    var listName: String
    var isDone: Bool
    var linkedEventID: String?
    var createdAt: Date
    var completedAt: Date?
    
    init(title: String, notes: String? = nil, dueDate: Date? = nil,
             priority: Priority = .medium, listName: String = "Inbox") {
            self.id = UUID()
            self.title = title
            self.notes = notes
            self.dueDate = dueDate
            self.priority = priority
            self.listName = listName
            self.isDone = false
            self.createdAt = .now
            self.completedAt = nil
        }
    
    func toggleCompletion() {
        isDone.toggle()
        completedAt = isDone ? .now : nil
    }
}
