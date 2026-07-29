import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let timestamp: Date
}
