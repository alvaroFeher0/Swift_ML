import Foundation
enum TaskTypes{
    static let fallback = "other"
    static let all = [  "Admin", "Chores", "Routine", "Work", "Personal", "Study", "Exercise",
                                  "Inbox", fallback
                              ]
    static func normalize(listName: String)->String{
        all.first { $0.caseInsensitiveCompare(listName) == .orderedSame } ?? fallback
    }
    
}
