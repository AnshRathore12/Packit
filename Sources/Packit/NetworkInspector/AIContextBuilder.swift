import Foundation

/// Builds a safe, structured text summary of all live app data
/// to be injected as context into the on-device LLM prompt.
public struct AIContextBuilder {
    
    public static func buildContext() -> String {
        var sections: [String] = []
        
        sections.append(networkContext())
        sections.append(userDefaultsContext())
        sections.append(keychainContext())
        
        return sections.joined(separator: "\n\n")
    }
    
    // MARK: - Network Context
    private static func networkContext() -> String {
        let transactions = NetworkStore.shared.transactions
        guard !transactions.isEmpty else {
            return "## Network Requests\nNo network requests recorded yet."
        }
        
        var lines = ["## Network Requests (last \(min(transactions.count, 50)) calls)"]
        
        let recent = Array(transactions.prefix(50))
        for tx in recent {
            let method = tx.request.httpMethod ?? "?"
            let url = tx.request.url?.absoluteString ?? "unknown"
            let status: String
            if let http = tx.response as? HTTPURLResponse {
                status = "\(http.statusCode)"
            } else if tx.error != nil {
                status = "ERROR"
            } else {
                status = "pending"
            }
            let ms = tx.duration.map { "\(Int($0 * 1000))ms" } ?? "N/A"
            lines.append("- [\(method)] \(url) → \(status) (\(ms))")
            
            // Include request headers (mask auth values)
            if let headers = tx.request.allHTTPHeaderFields, !headers.isEmpty {
                let sensitiveKeys = ["authorization", "cookie", "x-api-key", "token"]
                let headerSummary = headers
                    .filter { !$0.key.isEmpty }
                    .map { key, value -> String in
                        let isSensitive = sensitiveKeys.contains(where: { key.lowercased().contains($0) })
                        return "  \(key): \(isSensitive ? "***MASKED***" : value)"
                    }
                    .prefix(5)
                    .joined(separator: "\n")
                lines.append(headerSummary)
            }
        }
        
        // Failed requests summary
        let failed = transactions.filter { $0.isFailed }
        if !failed.isEmpty {
            lines.append("\n### Failed Requests (\(failed.count) total)")
            for tx in failed.prefix(5) {
                let url = tx.request.url?.absoluteString ?? "unknown"
                let err = tx.error?.localizedDescription ?? "HTTP error"
                lines.append("- \(url): \(err)")
            }
        }
        
        // Slowest requests
        let slow = transactions
            .compactMap { tx -> (String, Double)? in
                guard let d = tx.duration else { return nil }
                return (tx.request.url?.absoluteString ?? "unknown", d)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        
        if !slow.isEmpty {
            lines.append("\n### Slowest Requests")
            for (url, dur) in slow {
                lines.append("- \(url): \(Int(dur * 1000))ms")
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - UserDefaults Context
    private static func userDefaultsContext() -> String {
        let service = UserDefaultsService()
        let items = service.fetchAll()
        guard !items.isEmpty else {
            return "## UserDefaults\nNo UserDefaults keys found."
        }
        
        var lines = ["## UserDefaults (\(items.count) keys)"]
        let sensitiveKeywords = ["token", "password", "secret", "apikey", "bearer"]
        
        for item in items {
            let isSensitive = sensitiveKeywords.contains(where: { item.key.lowercased().contains($0) })
            let valuePreview: String
            
            if isSensitive {
                valuePreview = "***MASKED*** (\(item.typeName))"
            } else if item.memoryUsageBytes > 500 {
                // For large values, show a summary not the full value
                valuePreview = "[\(item.typeName), \(item.memoryUsageBytes) bytes]"
            } else {
                valuePreview = "\(item.stringRepresentation) (\(item.typeName))"
            }
            
            lines.append("- \(item.key): \(valuePreview)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Keychain Context
    private static func keychainContext() -> String {
        let service = KeychainService()
        let items = service.fetchAll()
        guard !items.isEmpty else {
            return "## Keychain\nNo keychain entries found."
        }
        
        var lines = ["## Keychain (\(items.count) entries)"]
        for item in items {
            // Always mask keychain values — they are always secrets
            lines.append("- \(item.key): ***MASKED*** (\(item.typeName), \(item.memoryUsageBytes) bytes)")
        }
        
        return lines.joined(separator: "\n")
    }
}
