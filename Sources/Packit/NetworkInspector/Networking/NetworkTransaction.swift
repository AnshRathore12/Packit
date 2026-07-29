//
//  NetworkTransaction.swift
//  NetworkInspector
//
//  Created by Ansh Rathore on 12/07/26.
//

import Foundation

public struct NetworkTransaction: Identifiable, Hashable {
    public let id = UUID()
    public let request: URLRequest
    public var response: URLResponse?
    public var data: Data?
    public var error: Error?
    
    public var dnsDuration: TimeInterval?
    public var connectDuration: TimeInterval?
    public var tlsDuration: TimeInterval?
    public var ttfbDuration: TimeInterval?
    public var downloadDuration: TimeInterval?
    public var isCacheHit: Bool = false
    
    public init(request: URLRequest, startTime: Date, response: URLResponse? = nil, data: Data? = nil, error: Error? = nil) {
        self.request = request
        self.startTime = startTime
        self.response = response
        self.data = data
        self.error = error
    }
    
    public static func == (lhs: NetworkTransaction, rhs: NetworkTransaction) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public var categoryName: String {
        // First try to extract GraphQL Operation Name from the request body
        if let body = request.httpBody,
           let dict = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let operationName = dict["operationName"] as? String, !operationName.isEmpty {
            return operationName
        }
        
        // Fallback to the last significant path component of the URL for REST APIs
        guard let url = request.url else { return "Unknown" }
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        
        if let last = pathComponents.last {
            // If the last component is a number or UUID (like an ID), use the second to last
            if UUID(uuidString: last) != nil || Int(last) != nil {
                if pathComponents.count > 1 {
                    return pathComponents[pathComponents.count - 2].capitalized
                }
            }
            return last.capitalized
        }
        
        return "General"
    }
    
    public var operationType: String {
        // Check for GraphQL
        if let body = request.httpBody,
           let dict = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let query = dict["query"] as? String {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.hasPrefix("mutation") {
                return "MUTATION"
            } else if trimmed.hasPrefix("subscription") {
                return "SUBSCRIPTION"
            } else {
                return "QUERY"
            }
        }
        
        // Fallback to HTTP Method for REST
        return request.httpMethod?.uppercased() ?? "GET"
    }
    
    public let startTime: Date
    public var endTime: Date?
    
    public var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: startTime)
    }
    
    public var path: String {
        guard let url = request.url else { return "Unknown" }
        let p = url.path.isEmpty ? "/" : url.path
        if let query = url.query {
            return p + "?" + query
        }
        return p
    }
    
    public var isFailed: Bool {
        return error != nil || (response as? HTTPURLResponse).map { $0.statusCode >= 400 } == true
    }
    
    public var cURLString: String {
        return request.curlString
    }
}
