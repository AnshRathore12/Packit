//
//  NetworkStore.swift
//  NetworkInspector
//
//  Created by Ansh Rathore on 12/07/26.
//

import Foundation
import Combine

public struct FilterType: Equatable, Hashable {
    public let id: String
    public let name: String
    public let predicate: (NetworkTransaction) -> Bool
    
    public init(id: String, name: String, predicate: @escaping (NetworkTransaction) -> Bool) {
        self.id = id
        self.name = name
        self.predicate = predicate
    }
    
    public static func == (lhs: FilterType, rhs: FilterType) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static let all = FilterType(id: "all", name: "All", predicate: { _ in true })
    public static let failed = FilterType(id: "failed", name: "Failed ", predicate: { $0.isFailed })
    public static let slow = FilterType(id: "slow", name: "Slow ", predicate: { ($0.duration ?? 0) > 0.5 })
    public static let post = FilterType(id: "post", name: "POST", predicate: { $0.request.httpMethod?.uppercased() == "POST" || $0.operationType == "MUTATION" })
    public static let get = FilterType(id: "get", name: "GET", predicate: { $0.request.httpMethod?.uppercased() == "GET" || $0.operationType == "QUERY" })
    public static let images = FilterType(id: "images", name: "Images ", predicate: { $0.response?.mimeType?.hasPrefix("image/") == true })
    
    public static let defaultFilters: [FilterType] = [.all, .failed, .slow, .post, .get, .images]
}

enum TimelineItem: Identifiable {
    case transaction(NetworkTransaction)
    case log(LogEntry)
    
    var id: UUID {
        switch self {
        case .transaction(let tx): return tx.id
        case .log(let log): return log.id
        }
    }
    
    var timestamp: Date {
        switch self {
        case .transaction(let tx): return tx.startTime
        case .log(let log): return log.timestamp
        }
    }
}

class NetworkStore: ObservableObject {
    static let shared = NetworkStore()
    
    @Published var transactions: [NetworkTransaction] = []
    @Published var logs: [LogEntry] = []
    @Published var searchQuery: String = ""
    @Published public var customFilters: [FilterType] = FilterType.defaultFilters
    @Published var selectedFilter: FilterType = .all
    @Published var isGroupedByHost: Bool = false
    @Published var sortAscending: Bool = false // false = Newest First, true = Oldest First
    
    var combinedTimeline: [TimelineItem] {
        let txItems = filteredTransactions.map { TimelineItem.transaction($0) }
        let logItems = logs.map { TimelineItem.log($0) }
        
        var combined = txItems
        
        if selectedFilter == .all && searchQuery.isEmpty && !isGroupedByHost {
            combined.append(contentsOf: logItems)
        }
        
        if sortAscending {
            return combined.sorted { $0.timestamp < $1.timestamp }
        } else {
            return combined.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    var filteredTransactions: [NetworkTransaction] {
        var result = transactions
        
        result = result.filter { selectedFilter.predicate($0) }
        if !searchQuery.isEmpty {
            let intent = NLAssistantService.shared.parseQuery(searchQuery)
            
            if intent.hasNLIntents {
                // Natural Language Filter Mode
                result = result.filter { transaction in
                    // Method Intent
                    if !intent.httpMethods.isEmpty {
                        let method = transaction.request.httpMethod?.uppercased() ?? ""
                        if !intent.httpMethods.contains(method) { return false }
                    }
                    
                    // Failure Intent
                    if intent.requiresFailure {
                        if !transaction.isFailed { return false }
                    }
                    
                    // Slow Intent
                    if intent.requiresSlow {
                        if (transaction.duration ?? 0) <= 0.5 { return false }
                    }
                    
                    // Image Intent
                    if intent.requiresImage {
                        if transaction.response?.mimeType?.hasPrefix("image/") != true { return false }
                    }
                    
                    // Also check standard search terms if they typed extra words
                    if !intent.searchTerms.isEmpty {
                        let urlMatch = intent.searchTerms.contains(where: { transaction.request.url?.absoluteString.lowercased().contains($0) == true })
                        if !urlMatch { return false }
                    }
                    
                    return true
                }
            } else {
                // Fuzzy Search Mode (handles typos automatically)
                result = result.filter { transaction in
                    let url = transaction.request.url?.absoluteString ?? ""
                    let method = transaction.request.httpMethod ?? ""
                    let status = (transaction.response as? HTTPURLResponse).map { String($0.statusCode) } ?? ""
                    let category = transaction.categoryName
                    return FuzzySearchEngine.matches(searchQuery, in: url) ||
                           FuzzySearchEngine.matches(searchQuery, in: method) ||
                           FuzzySearchEngine.matches(searchQuery, in: status) ||
                           FuzzySearchEngine.matches(searchQuery, in: category)
                }
            }
        }
        
        return result
    }
    
    var groupedTransactions: [(key: String, value: [NetworkTransaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            transaction.request.url?.host ?? "Unknown Host"
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - Phase 3 Features
    
    func duplicateCount(for transaction: NetworkTransaction) -> Int {
        return transactions.filter {
            $0.request.url?.absoluteString == transaction.request.url?.absoluteString &&
            $0.request.httpMethod == transaction.request.httpMethod
        }.count
    }
    
    var averageResponseTimes: [(path: String, avgDuration: TimeInterval, count: Int)] {
        let grouped = Dictionary(grouping: transactions) { $0.path }
        return grouped.map { (path, txs) in
            let validDurations = txs.compactMap { $0.duration }
            let total = validDurations.reduce(0, +)
            let avg = validDurations.isEmpty ? 0 : total / Double(validDurations.count)
            return (path: path, avgDuration: avg, count: txs.count)
        }.sorted { $0.avgDuration > $1.avgDuration } // Sort by slowest first
    }
    
    func exportToJSON() -> URL? {
        let exportableTransactions: [[String: Any]] = transactions.map { tx in
            var dict: [String: Any] = [
                "id": tx.id.uuidString,
                "url": tx.request.url?.absoluteString ?? "",
                "method": tx.request.httpMethod ?? "GET",
                "startTime": tx.startTime.timeIntervalSince1970
            ]
            if let duration = tx.duration { dict["duration"] = duration }
            if let response = tx.response as? HTTPURLResponse { dict["statusCode"] = response.statusCode }
            if let reqHeaders = tx.request.allHTTPHeaderFields { dict["requestHeaders"] = reqHeaders }
            if let resHeaders = (tx.response as? HTTPURLResponse)?.allHeaderFields as? [String: String] { dict["responseHeaders"] = resHeaders }
            return dict
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: exportableTransactions, options: .prettyPrinted)
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("NetworkSession-\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export JSON: \(error)")
            return nil
        }
    }
    
    private let maxTransactions = 250
    private let maxPayloadSize = 2 * 1024 * 1024 // 2 MB
    
    private init() {}
    
    func addTransaction(_ transaction: NetworkTransaction) {
        DispatchQueue.main.async {
            self.transactions.insert(transaction, at: 0)
            if self.transactions.count > self.maxTransactions {
                self.transactions.removeLast(self.transactions.count - self.maxTransactions)
            }
        }
    }
    
    func updateTransaction(id: UUID, with response: URLResponse?, data: Data?, error: Error?) {
        DispatchQueue.main.async {
            if let index = self.transactions.firstIndex(where: { $0.id == id }) {
                var transaction = self.transactions[index]
                transaction.response = response
                if let data = data {
                    if transaction.data == nil {
                        transaction.data = Data()
                    }
                    let currentCount = transaction.data?.count ?? 0
                    if currentCount < self.maxPayloadSize {
                        let remainingSpace = self.maxPayloadSize - currentCount
                        if data.count <= remainingSpace {
                            transaction.data?.append(data)
                        } else {
                            transaction.data?.append(data.prefix(remainingSpace))
                            // Optional: Could add a flag here to UI to show "Truncated"
                        }
                    }
                }
                transaction.error = error
                if response != nil || error != nil {
                    transaction.endTime = Date()
                }
                self.transactions[index] = transaction
            }
        }
    }
    
    public static func log(_ message: String) {
        DispatchQueue.main.async {
            let entry = LogEntry(message: message, timestamp: Date())
            NetworkStore.shared.logs.append(entry)
        }
    }
    
    func clearSession() {
        DispatchQueue.main.async {
            self.transactions.removeAll()
            self.logs.removeAll()
        }
    }
    
    func deleteTransaction(id: UUID) {
        DispatchQueue.main.async {
            self.transactions.removeAll(where: { $0.id == id })
        }
    }
    
    func retryTransaction(_ transaction: NetworkTransaction) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MyURLProtocol.self]
        let session = URLSession(configuration: configuration)
        session.dataTask(with: transaction.request).resume()
    }
}
