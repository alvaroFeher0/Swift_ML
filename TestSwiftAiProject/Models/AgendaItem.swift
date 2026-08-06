import Foundation
import EventKit

enum AgendaKind {
    case event(EKEvent)
    case task(TodoItem)
}

struct AgendaItem: Identifiable {
    let id: String
    let title: String
    let time: Date?
    let completionPercentage: Double?
    let kind: AgendaKind
}
