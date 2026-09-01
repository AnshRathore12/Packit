//
//  NetworkStore.swift
//  NetworkInspector
//
//  Created by Ansh Rathore on 12/07/26.
//

import Foundation
import Combine

// MARK: - Filter Type

public struct FilterType: Equatable, Hashable {

    public let id: String
    public let name: String
    public let predicate: (NetworkTransaction) -> Bool

    public init(
        id: String,
        name: String,
        predicate: @escaping (NetworkTransaction) -> Bool
    ) {
        self.id = id
        self.name = name
        self.predicate = predicate
    }

    public static func == (
        lhs: FilterType,
        rhs: FilterType
    ) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static let all = FilterType(
        id: "all",
        name: "All",
        predicate: { _ in true }
    )

    public static let failed = FilterType(
        id: "failed",
        name: "Failed",
        predicate: { $0.isFailed }
    )

    public static let slow = FilterType(
        id: "slow",
        name: "Slow",
        predicate: {
            ($0.duration ?? 0) > 0.5
        }
    )

    public static let post = FilterType(
        id: "post",
        name: "POST",
        predicate: {
            $0.request.httpMethod?.uppercased() == "POST" ||
            $0.operationType == "MUTATION"
        }
    )

    public static let get = FilterType(
        id: "get",
        name: "GET",
        predicate: {
            $0.request.httpMethod?.uppercased() == "GET" ||
            $0.operationType == "QUERY"
        }
    )

    public static let images = FilterType(
        id: "images",
        name: "Images",
        predicate: {
            $0.response?.mimeType?.hasPrefix("image/") == true
        }
    )

    public static let defaultFilters: [FilterType] = [
        .all,
        .failed,
        .slow,
        .post,
        .get,
        .images
    ]
}

// MARK: - Timeline

enum TimelineItem: Identifiable {

    case transaction(NetworkTransaction)
    case log(LogEntry)

    var id: UUID {
        switch self {
        case .transaction(let transaction):
            return transaction.id

        case .log(let log):
            return log.id
        }
    }

    var timestamp: Date {
        switch self {
        case .transaction(let transaction):
            return transaction.startTime

        case .log(let log):
            return log.timestamp
        }
    }
}

// MARK: - Natural Language Intent

/// Minimal intent model to satisfy search filtering needs.
/// If you already have a richer implementation elsewhere, remove this and import that module instead.
struct NLIntent {
    var hasNLIntents: Bool
    var httpMethods: Set<String>
    var requiresFailure: Bool
    var requiresSlow: Bool
    var requiresImage: Bool
    var searchTerms: [String]

    init(
        hasNLIntents: Bool = false,
        httpMethods: Set<String> = [],
        requiresFailure: Bool = false,
        requiresSlow: Bool = false,
        requiresImage: Bool = false,
        searchTerms: [String] = []
    ) {
        self.hasNLIntents = hasNLIntents
        self.httpMethods = httpMethods
        self.requiresFailure = requiresFailure
        self.requiresSlow = requiresSlow
        self.requiresImage = requiresImage
        self.searchTerms = searchTerms
    }
}

// MARK: - Network Store

final class NetworkStore: ObservableObject {

    static let shared = NetworkStore()

    // MARK: - Published State

    @Published private(set) var transactions: [NetworkTransaction] = []

    @Published private(set) var logs: [LogEntry] = []

    @Published var searchQuery: String = ""

    @Published public var customFilters: [FilterType] =
        FilterType.defaultFilters

    @Published var selectedFilter: FilterType = .all

    @Published var isGroupedByHost: Bool = false

    @Published var sortAscending: Bool = false

    @Published private(set) var filteredTransactions: [NetworkTransaction] = []

    @Published private(set) var combinedTimeline: [TimelineItem] = []

    @Published private(set) var groupedTransactions: [(key: String, value: [NetworkTransaction])] = []

    // MARK: - Limits

    private let maxTransactions = 250

    private let maxLogs = 500

    private let maxPayloadSize = 2 * 1024 * 1024 // 2 MB

    // MARK: - Search & Filter Generation

    private var searchGeneration: UInt64 = 0

    private var searchWorkItem: DispatchWorkItem?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Search Cache

    private var cachedSearchQuery: String?

    private var cachedSearchIntent: NLQueryIntent?

    // MARK: - Initialization

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        Publishers.CombineLatest(
            Publishers.CombineLatest4(
                $searchQuery.debounce(for: .milliseconds(50), scheduler: RunLoop.main),
                $selectedFilter,
                $sortAscending,
                $isGroupedByHost
            ),
            Publishers.CombineLatest($transactions, $logs)
        )
        .sink { [weak self] (controls, data) in
            let (query, filter, sortAsc, groupByHost) = controls
            let (rawTransactions, rawLogs) = data
            self?.scheduleFilterAndSearch(
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                filter: filter,
                sortAsc: sortAsc,
                groupByHost: groupByHost,
                rawTransactions: rawTransactions,
                rawLogs: rawLogs
            )
        }
        .store(in: &cancellables)
    }

    // MARK: - Add Transaction

    func addTransaction(
        _ transaction: NetworkTransaction
    ) {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            self.transactions.insert(
                transaction,
                at: 0
            )

            // Keep memory bounded.
            if self.transactions.count > self.maxTransactions {

                self.transactions.removeLast(
                    self.transactions.count - self.maxTransactions
                )
            }
        }
    }

    // MARK: - Update Transaction

    func updateTransaction(
        id: UUID,
        with response: URLResponse?,
        data: Data?,
        error: Error?,
        isResponseTruncated: Bool = false
    ) {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            guard let index = self.transactions.firstIndex(
                where: { $0.id == id }
            ) else {
                return
            }

            var transaction = self.transactions[index]

            // Response
            if let response {
                transaction.response = response
            }

            // Error
            transaction.error = error

            // Response data
            if let data, !data.isEmpty {

                let currentSize =
                    transaction.data?.count ?? 0

                if currentSize < self.maxPayloadSize {

                    let remaining =
                        self.maxPayloadSize - currentSize

                    let amountToAppend =
                        min(data.count, remaining)

                    if transaction.data == nil {
                        transaction.data = Data()
                    }

                    transaction.data?.append(
                        data.prefix(amountToAppend)
                    )
                }

                transaction.responseSize =
                    max(
                        transaction.responseSize,
                        data.count
                    )
            }

            // Truncation
            if isResponseTruncated {
                transaction.isResponseTruncated = true
            }

            // Request completed
            if response != nil || error != nil {
                transaction.endTime = Date()
                transaction.responseBodyString = NetworkTransaction.extractBodyString(from: transaction.data)
            }

            self.transactions[index] = transaction
        }
    }

    // MARK: - Metrics

    func updateMetrics(
        transactionId: UUID,
        dnsDuration: TimeInterval?,
        connectDuration: TimeInterval?,
        tlsDuration: TimeInterval?,
        ttfbDuration: TimeInterval?,
        downloadDuration: TimeInterval?,
        isCacheHit: Bool
    ) {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            guard let index = self.transactions.firstIndex(
                where: { $0.id == transactionId }
            ) else {
                return
            }

            var transaction = self.transactions[index]

            transaction.dnsDuration = dnsDuration
            transaction.connectDuration = connectDuration
            transaction.tlsDuration = tlsDuration
            transaction.ttfbDuration = ttfbDuration
            transaction.downloadDuration = downloadDuration
            transaction.isCacheHit = isCacheHit

            self.transactions[index] = transaction
        }
    }

    // MARK: - Filtering & Search (Generation-Based)

    private func scheduleFilterAndSearch(
        query: String,
        filter: FilterType,
        sortAsc: Bool,
        groupByHost: Bool,
        rawTransactions: [NetworkTransaction],
        rawLogs: [LogEntry]
    ) {
        searchWorkItem?.cancel()
        searchGeneration &+= 1
        let currentGeneration = searchGeneration

        // Fast path for empty search and "All" filter
        if query.isEmpty && filter.id == FilterType.all.id {
            self.filteredTransactions = rawTransactions
            self.updateTimelineAndGroupings(
                filtered: rawTransactions,
                logs: rawLogs,
                query: query,
                filter: filter,
                sortAsc: sortAsc,
                groupByHost: groupByHost
            )
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            var result = rawTransactions

            // 1. Filter type (GET, POST, Images, Failed, Slow, etc.)
            if filter.id != FilterType.all.id {
                result = result.filter(filter.predicate)
            }

            // 2. Query search
            if !query.isEmpty {
                let intent = self.cachedIntent(for: query)

                if intent.hasNLIntents {
                    result = result.filter { tx in
                        if !intent.httpMethods.isEmpty {
                            let method = tx.request.httpMethod?.uppercased() ?? ""
                            if !intent.httpMethods.contains(method) { return false }
                        }
                        if intent.requiresFailure && !tx.isFailed { return false }
                        if intent.requiresSlow && (tx.duration ?? 0) <= 0.5 { return false }
                        if intent.requiresImage && tx.response?.mimeType?.hasPrefix("image/") != true { return false }
                        if !intent.searchTerms.isEmpty {
                            let url = tx.request.url?.absoluteString.lowercased() ?? ""
                            let reqBody = tx.requestBodyString?.lowercased() ?? ""
                            let resBody = tx.responseBodyString?.lowercased() ?? ""
                            let matches = intent.searchTerms.contains { term in
                                url.contains(term) || reqBody.contains(term) || resBody.contains(term)
                            }
                            if !matches { return false }
                        }
                        return true
                    }
                } else {
                    result = result.filter { tx in
                        let url = tx.request.url?.absoluteString ?? ""
                        let method = tx.request.httpMethod ?? ""
                        let status = tx.statusCode.map(String.init) ?? ""
                        let category = tx.categoryName
                        let reqBody = tx.requestBodyString ?? ""
                        let resBody = tx.responseBodyString ?? ""

                        // Check request headers
                        let reqHeadersMatch = tx.request.allHTTPHeaderFields?.contains { key, value in
                            key.range(of: query, options: .caseInsensitive) != nil ||
                            value.range(of: query, options: .caseInsensitive) != nil
                        } ?? false

                        // Check response headers
                        let resHeadersMatch = (tx.response as? HTTPURLResponse)?.allHeaderFields.contains { key, value in
                            String(describing: key).range(of: query, options: .caseInsensitive) != nil ||
                            String(describing: value).range(of: query, options: .caseInsensitive) != nil
                        } ?? false

                        return
                            url.range(of: query, options: .caseInsensitive) != nil ||
                            method.range(of: query, options: .caseInsensitive) != nil ||
                            status.range(of: query, options: .caseInsensitive) != nil ||
                            category.range(of: query, options: .caseInsensitive) != nil ||
                            reqBody.range(of: query, options: .caseInsensitive) != nil ||
                            resBody.range(of: query, options: .caseInsensitive) != nil ||
                            reqHeadersMatch ||
                            resHeadersMatch
                    }
                }
            }

            // Return to main thread
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Reject stale results from older generations
                guard currentGeneration == self.searchGeneration else { return }
                guard self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
                guard self.selectedFilter.id == filter.id else { return }

                self.filteredTransactions = result
                self.updateTimelineAndGroupings(
                    filtered: result,
                    logs: rawLogs,
                    query: query,
                    filter: filter,
                    sortAsc: sortAsc,
                    groupByHost: groupByHost
                )
            }
        }

        searchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    private func updateTimelineAndGroupings(
        filtered: [NetworkTransaction],
        logs: [LogEntry],
        query: String,
        filter: FilterType,
        sortAsc: Bool,
        groupByHost: Bool
    ) {
        // Combined Timeline
        var combined: [TimelineItem] = []
        combined.reserveCapacity(filtered.count + logs.count)
        combined.append(contentsOf: filtered.map { TimelineItem.transaction($0) })

        if filter.id == FilterType.all.id && query.isEmpty && !groupByHost {
            combined.append(contentsOf: logs.map { TimelineItem.log($0) })
        }

        if sortAsc {
            combined.sort { $0.timestamp < $1.timestamp }
        } else {
            combined.sort { $0.timestamp > $1.timestamp }
        }
        self.combinedTimeline = combined

        // Grouped Transactions
        let grouped = Dictionary(grouping: filtered) { tx in
            tx.request.url?.host ?? "Unknown Host"
        }
        self.groupedTransactions = grouped.sorted { $0.key < $1.key }
    }

    // MARK: - Search Intent Cache

    private func cachedIntent(
        for query: String
    ) -> NLQueryIntent {

        if cachedSearchQuery == query,
           let cachedSearchIntent {
            return cachedSearchIntent
        }

        let intent =
            NLAssistantService.shared.parseQuery(query)

        cachedSearchQuery = query
        cachedSearchIntent = intent

        return intent
    }

    // MARK: - Duplicate Count

    func duplicateCount(
        for transaction: NetworkTransaction
    ) -> Int {

        let url =
            transaction.request.url?
                .absoluteString

        let method =
            transaction.request.httpMethod

        return transactions.reduce(
            into: 0
        ) { count, item in

            if item.request.url?.absoluteString == url &&
                item.request.httpMethod == method {

                count += 1
            }
        }
    }

    // MARK: - Average Response Times

    var averageResponseTimes:
        [(path: String,
          avgDuration: TimeInterval,
          count: Int)] {

        let grouped =
            Dictionary(
                grouping: transactions
            ) {
                $0.path
            }

        return grouped
            .map { path, transactions in

                let durations =
                    transactions.compactMap {
                        $0.duration
                    }

                let total =
                    durations.reduce(0, +)

                let average =
                    durations.isEmpty
                    ? 0
                    : total / Double(durations.count)

                return (
                    path: path,
                    avgDuration: average,
                    count: transactions.count
                )
            }
            .sorted {
                $0.avgDuration > $1.avgDuration
            }
    }

    // MARK: - Export

    func exportToJSON() -> URL? {

        let transactions = self.transactions

        let exportableTransactions:
            [[String: Any]] =
            transactions.map { transaction in

                var dict: [String: Any] = [

                    "id":
                        transaction.id.uuidString,

                    "url":
                        transaction.request.url?
                            .absoluteString ?? "",

                    "method":
                        transaction.request.httpMethod
                        ?? "GET",

                    "startTime":
                        transaction.startTime
                            .timeIntervalSince1970
                ]

                if let duration =
                    transaction.duration {

                    dict["duration"] = duration
                }

                if let statusCode =
                    transaction.statusCode {

                    dict["statusCode"] = statusCode
                }

                if let requestHeaders =
                    transaction.request
                        .allHTTPHeaderFields {

                    dict["requestHeaders"] =
                        requestHeaders
                }

                if let responseHeaders =
                    transaction.responseHeaders
                    as? [String: String] {

                    dict["responseHeaders"] =
                        responseHeaders
                }

                return dict
            }

        do {

            let data =
                try JSONSerialization.data(
                    withJSONObject:
                        exportableTransactions,
                    options: .prettyPrinted
                )

            let fileURL =
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "NetworkSession-\(Int(Date().timeIntervalSince1970)).json"
                    )

            try data.write(
                to: fileURL,
                options: .atomic
            )

            return fileURL

        } catch {

            print(
                "Failed to export JSON: \(error)"
            )

            return nil
        }
    }

    // MARK: - Logs

    public static func log(
        _ message: String
    ) {

        DispatchQueue.main.async {

            let entry =
                LogEntry(
                    message: message,
                    timestamp: Date()
                )

            NetworkStore.shared.logs.insert(
                entry,
                at: 0
            )

            if NetworkStore.shared.logs.count >
                NetworkStore.shared.maxLogs {

                NetworkStore.shared.logs.removeLast(
                    NetworkStore.shared.logs.count -
                    NetworkStore.shared.maxLogs
                )
            }
        }
    }

    // MARK: - Clear

    func clearSession() {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            self.transactions.removeAll(
                keepingCapacity: true
            )

            self.logs.removeAll(
                keepingCapacity: true
            )

            self.cachedSearchQuery = nil
            self.cachedSearchIntent = nil
        }
    }

    // MARK: - Delete

    func deleteTransaction(
        id: UUID
    ) {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            self.transactions.removeAll {
                $0.id == id
            }
        }
    }

    // MARK: - Retry

    func retryTransaction(
        _ transaction: NetworkTransaction
    ) {

        let configuration =
            URLSessionConfiguration.default

        configuration.protocolClasses = [
            MyURLProtocol.self
        ]

        let session =
            URLSession(
                configuration: configuration
            )

        let task =
            session.dataTask(
                with: transaction.request
            )

        task.resume()
    }
}
