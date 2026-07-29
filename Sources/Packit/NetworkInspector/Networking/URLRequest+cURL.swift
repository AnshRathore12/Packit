import Foundation

extension URLRequest {
    public var curlString: String {
        guard let url = url else { return "" }
        
        var lines: [String] = []
        let escapedURL = url.absoluteString.replacingOccurrences(of: "'", with: "'\\''")
        lines.append("curl --location '\(escapedURL)'")
        
        if let method = httpMethod, method != "GET" {
            lines.append("--request \(method)")
        }
        
        if let headers = allHTTPHeaderFields {
            for (key, value) in headers {
                let escapedValue = value.replacingOccurrences(of: "'", with: "'\\''")
                lines.append("--header '\(key): \(escapedValue)'")
            }
        }
        
        if let body = httpBody, let bodyString = String(data: body, encoding: .utf8), !bodyString.isEmpty {
            let escapedBody = bodyString.replacingOccurrences(of: "'", with: "'\\''")
            lines.append("--data '\(escapedBody)'")
        }
        
        return lines.joined(separator: " \\\n")
    }
}
