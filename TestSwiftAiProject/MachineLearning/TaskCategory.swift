import Foundation

/// The category vocabulary shared by training and inference.
///
/// `TodoItem.listName` is free-form text, but the model one-hot encodes `category`
/// against a fixed set fixed at training time. Feeding it anything outside that set
/// makes Core ML reject the whole row, so every list name is normalized through
/// `normalize(_:)` before it reaches the model.
enum TaskCategory {
    /// Bump when `all` changes, so an existing on-disk model gets retrained
    /// instead of being loaded with a stale vocabulary.
    static let vocabularyVersion = 2

    static let fallback = "Other"

    static let all = [
        "Admin", "Chores", "Routine", "Work", "Personal", "Study", "Exercise",
        "Inbox", fallback
    ]

    /// Maps a free-form list name onto a category the model was trained on.
    static func normalize(_ listName: String) -> String {
        all.first { $0.caseInsensitiveCompare(listName) == .orderedSame } ?? fallback
    }
}
