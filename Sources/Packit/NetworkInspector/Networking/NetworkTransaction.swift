////
////  NetworkTransaction.swift
////  NetworkInspector
////
////  Created by Ansh Rathore on 12/07/26.
////
//
//import Foundation
//
//public struct NetworkTransaction: Identifiable, Hashable {
//    public let id = UUID()
//    public let request: URLRequest
//    public var response: URLResponse?
//    public var data: Data?
//    public var error: Error?
//    
//    public var dnsDuration: TimeInterval?
//    public var connectDuration: TimeInterval?
//    public var tlsDuration: TimeInterval?
//    public var ttfbDuration: TimeInterval?
//    public var downloadDuration: TimeInterval?
//    public var isCacheHit: Bool = false
//    
//    public init(request: URLRequest, startTime: Date, response: URLResponse? = nil, data: Data? = nil, error: Error? = nil) {
//        self.request = request
//        self.startTime = startTime
//        self.response = response
//        self.data = data
//        self.error = error
//    }
//    
//    public static func == (lhs: NetworkTransaction, rhs: NetworkTransaction) -> Bool {
//        lhs.id == rhs.id
//    }
//    
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
//    
//    public var categoryName: String {
//        // First try to extract GraphQL Operation Name from the request body
//        if let body = request.httpBody,
//           let dict = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
//           let operationName = dict["operationName"] as? String, !operationName.isEmpty {
//            return operationName
//        }
//        
//        // Fallback to the last significant path component of the URL for REST APIs
//        guard let url = request.url else { return "Unknown" }
//        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
//        
//        if let last = pathComponents.last {
//            // If the last component is a number or UUID (like an ID), use the second to last
//            if UUID(uuidString: last) != nil || Int(last) != nil {
//                if pathComponents.count > 1 {
//                    return pathComponents[pathComponents.count - 2].capitalized
//                }
//            }
//            return last.capitalized
//        }
//        
//        return "General"
//    }
//    
//    public var operationType: String {
//        // Check for GraphQL
//        if let body = request.httpBody,
//           let dict = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
//           let query = dict["query"] as? String {
//            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//            if trimmed.hasPrefix("mutation") {
//                return "MUTATION"
//            } else if trimmed.hasPrefix("subscription") {
//                return "SUBSCRIPTION"
//            } else {
//                return "QUERY"
//            }
//        }
//        
//        // Fallback to HTTP Method for REST
//        return request.httpMethod?.uppercased() ?? "GET"
//    }
//    
//    public let startTime: Date
//    public var endTime: Date?
//    
//    public var duration: TimeInterval? {
//        guard let end = endTime else { return nil }
//        return end.timeIntervalSince(startTime)
//    }
//    
//    public var formattedTime: String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss"
//        return formatter.string(from: startTime)
//    }
//    
//    public var path: String {
//        guard let url = request.url else { return "Unknown" }
//        let p = url.path.isEmpty ? "/" : url.path
//        if let query = url.query {
//            return p + "?" + query
//        }
//        return p
//    }
//    
//    public var isFailed: Bool {
//        return error != nil || (response as? HTTPURLResponse).map { $0.statusCode >= 400 } == true
//    }
//    
//    public var cURLString: String {
//        return request.curlString
//    }
//}


//
//  NetworkTransaction.swift
//  NetworkInspector
//
//  Created by Ansh Rathore on 12/07/26.
//

import Foundation

public struct NetworkTransaction: Identifiable, Hashable {

    // MARK: - Identity

    public let id: UUID

    // MARK: - Request

    public let request: URLRequest
    public let startTime: Date

    // Precomputed values.
    // These should NOT be computed properties because they can be accessed
    // repeatedly by SwiftUI.
    public let path: String
    public let categoryName: String
    public let operationType: String
    public let formattedTime: String

    // MARK: - Response

    public var response: URLResponse?
    public var data: Data?
    public var error: Error?

    // Useful for displaying response size without repeatedly inspecting Data.
    public var responseSize: Int = 0
    public var isResponseTruncated: Bool = false

    // MARK: - Timing

    public var endTime: Date?

    public var dnsDuration: TimeInterval?
    public var connectDuration: TimeInterval?
    public var tlsDuration: TimeInterval?
    public var ttfbDuration: TimeInterval?
    public var downloadDuration: TimeInterval?

    public var isCacheHit: Bool = false

    // MARK: - Initialization

    public init(
        request: URLRequest,
        startTime: Date = Date(),
        response: URLResponse? = nil,
        data: Data? = nil,
        error: Error? = nil
    ) {
        self.id = UUID()
        self.request = request
        self.startTime = startTime

        // Precompute expensive values ONCE.
        self.path = Self.makePath(from: request)
        self.categoryName = Self.makeCategoryName(from: request)
        self.operationType = Self.makeOperationType(from: request)
        self.formattedTime = Self.formatTime(startTime)

        self.response = response
        self.data = data
        self.error = error

        self.responseSize = data?.count ?? 0

        self.requestBodyString = Self.extractBodyString(from: request.httpBody)
        self.responseBodyString = Self.extractBodyString(from: data)
    }

    // MARK: - Hashable & Equatable

    public static func == (
        lhs: NetworkTransaction,
        rhs: NetworkTransaction
    ) -> Bool {
        // Check ID first for fast failure
        lhs.id == rhs.id &&
        // Check fields that change when the transaction completes
        lhs.endTime == rhs.endTime &&
        lhs.responseSize == rhs.responseSize &&
        lhs.statusCode == rhs.statusCode
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(endTime)
        hasher.combine(responseSize)
    }

    // MARK: - Computed Properties

    public var duration: TimeInterval? {
        guard let endTime else {
            return nil
        }

        return endTime.timeIntervalSince(startTime)
    }

    public var isFailed: Bool {
        if error != nil {
            return true
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode >= 400
    }

    public var statusCode: Int? {
        (response as? HTTPURLResponse)?.statusCode
    }

    public var responseHeaders: [AnyHashable: Any]? {
        (response as? HTTPURLResponse)?.allHeaderFields
    }

    public var cURLString: String {
        request.curlString
    }

    public let requestBodyString: String?
    public var responseBodyString: String?

    public static func extractBodyString(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        let maxSearchBytes = 64 * 1024
        let prefixData = data.count > maxSearchBytes ? data.prefix(maxSearchBytes) : data
        return String(data: prefixData, encoding: .utf8)
    }

    // MARK: - Private Helpers

    private static func makePath(from request: URLRequest) -> String {
        guard let url = request.url else {
            return "Unknown"
        }

        let path = url.path.isEmpty ? "/" : url.path

        guard let query = url.query, !query.isEmpty else {
            return path
        }

        return "\(path)?\(query)"
    }

    private static func makeCategoryName(
        from request: URLRequest
    ) -> String {

        // GraphQL
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body)
            as? [String: Any],
           let operationName = json["operationName"] as? String,
           !operationName.isEmpty {

            return operationName
        }

        // REST fallback
        guard let url = request.url else {
            return "Unknown"
        }

        let pathComponents = url.pathComponents.filter {
            $0 != "/" && !$0.isEmpty
        }

        guard let lastComponent = pathComponents.last else {
            return "General"
        }

        // If the last path component is an ID/UUID,
        // use the previous component.
        if UUID(uuidString: lastComponent) != nil ||
            Int(lastComponent) != nil {

            if pathComponents.count > 1 {
                return pathComponents[
                    pathComponents.count - 2
                ].capitalized
            }
        }

        return lastComponent.capitalized
    }

    private static func makeOperationType(
        from request: URLRequest
    ) -> String {

        // GraphQL
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body)
            as? [String: Any],
           let query = json["query"] as? String {

            let trimmedQuery = query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if trimmedQuery.hasPrefix("mutation") {
                return "MUTATION"
            }

            if trimmedQuery.hasPrefix("subscription") {
                return "SUBSCRIPTION"
            }

            return "QUERY"
        }

        // REST
        return request.httpMethod?.uppercased() ?? "GET"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
