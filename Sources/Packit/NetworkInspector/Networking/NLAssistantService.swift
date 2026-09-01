import Foundation
import NaturalLanguage

public struct NLQueryIntent {
    public var httpMethods: [String] = []
    public var requiresFailure: Bool = false
    public var requiresSlow: Bool = false
    public var requiresImage: Bool = false
    public var searchTerms: [String] = [] // Fallback standard search terms
    
    public var hasNLIntents: Bool {
        return !httpMethods.isEmpty || requiresFailure || requiresSlow || requiresImage
    }
}

public class NLAssistantService {
    public nonisolated(unsafe)  static let shared = NLAssistantService()
    
    private init() {}
    
    /// Parses a natural language sentence and extracts filter intents
    public func parseQuery(_ query: String) -> NLQueryIntent {
        var intent = NLQueryIntent()
        let text = query.lowercased()
        
        // Fast path for exact single word methods
        if text == "post" { intent.httpMethods.append("POST"); return intent }
        if text == "get" { intent.httpMethods.append("GET"); return intent }
        if text == "put" { intent.httpMethods.append("PUT"); return intent }
        if text == "delete" { intent.httpMethods.append("DELETE"); return intent }
        
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
            let word = String(text[tokenRange])
            let lemma = tag?.rawValue.lowercased() ?? word
            
            // Map lemmas to intents
            switch lemma {
            // Method Intents
            case "post": intent.httpMethods.append("POST")
            case "get", "fetch": intent.httpMethods.append("GET")
            case "put", "update": intent.httpMethods.append("PUT")
            case "delete", "remove": intent.httpMethods.append("DELETE")
                
            // Status Intents
            case "fail", "error", "crash", "bad", "500", "404":
                intent.requiresFailure = true
                
            // Performance Intents
            case "slow", "lag", "delay", "laggy":
                intent.requiresSlow = true
                
            // Content Intents
            case  "photo", "picture":
                intent.requiresImage = true
                
            // Ignore Stop Words
            case "show", "me", "the", "find", "a", "an", "request", "call", "api", "network", "traffic", "all", "only":
                break
                
            default:
                // If it doesn't match an intent or a stop word, treat it as a standard search term
                intent.searchTerms.append(word)
            }
            
            return true
        }
        
        return intent
    }
}

//
//
//import Foundation
//import NaturalLanguage
//
//// MARK: - Query Intent
//
//public struct NLQueryIntent {
//
//    // MARK: HTTP / GraphQL
//
//    public var httpMethods: Set<String> = []
//
//    // MARK: Status
//
//    public var statusCodes: Set<Int> = []
//    public var statusClass: StatusClass?
//
//    // MARK: Performance
//
//    public var performance: PerformanceFilter?
//
//    // MARK: Content
//
//    public var contentTypes: Set<ContentType> = []
//
//    // MARK: Network State
//
//    public var requiresCacheHit: Bool = false
//    public var requiresPending: Bool = false
//
//    // MARK: Standard Search
//
//    public var searchTerms: [String] = []
//
//    // MARK: Backward Compatibility
//
//    /// Compatibility with existing NetworkStore filtering logic.
//    public var requiresFailure: Bool {
//        statusClass == .failure
//    }
//
//    /// Compatibility with existing NetworkStore filtering logic.
//    public var requiresSlow: Bool {
//        performance == .slow
//    }
//
//    /// Compatibility with existing NetworkStore filtering logic.
//    public var requiresImage: Bool {
//        contentTypes.contains(.image)
//    }
//
//    // MARK: Intent Check
//
//    public var hasNLIntents: Bool {
//        !httpMethods.isEmpty ||
//        !statusCodes.isEmpty ||
//        statusClass != nil ||
//        performance != nil ||
//        !contentTypes.isEmpty ||
//        requiresCacheHit ||
//        requiresPending
//    }
//
//    public init() {}
//}
//
//
//// MARK: - Status Class
//
//public enum StatusClass: Equatable {
//
//    case success       // 2xx
//    case redirect      // 3xx
//    case clientError   // 4xx
//    case serverError   // 5xx
//    case failure       // Any failed request
//}
//
//
//// MARK: - Performance Filter
//
//public enum PerformanceFilter: Equatable {
//
//    case slow
//    case fast
//    case minimumDuration(TimeInterval)
//    case maximumDuration(TimeInterval)
//}
//
//
//// MARK: - Content Type
//
//public enum ContentType: Hashable {
//
//    case image
//    case json
//    case text
//    case html
//}
//
//
//// MARK: - NL Assistant
//
//public final class NLAssistantService {
//
//    public static let shared = NLAssistantService()
//
//    private init() {}
//
//    // MARK: - Public API
//
//    /// Parses a natural-language query and converts it into
//    /// structured filtering intents.
//    public func parseQuery(_ query: String) -> NLQueryIntent {
//
//        var intent = NLQueryIntent()
//
//        let normalizedText = normalize(query)
//
//        guard !normalizedText.isEmpty else {
//            return intent
//        }
//
//        // 1. Exact method query
//
//        if let method = exactMethod(from: normalizedText) {
//            intent.httpMethods.insert(method)
//            return intent
//        }
//
//        // 2. Status codes
//
//        parseStatusCodes(
//            from: normalizedText,
//            into: &intent
//        )
//
//        // 3. Status class / meaning
//
//        parseStatusClass(
//            from: normalizedText,
//            into: &intent
//        )
//
//        // 4. HTTP / GraphQL methods
//
//        parseMethods(
//            from: normalizedText,
//            into: &intent
//        )
//
//        // 5. Performance
//
//        parsePerformance(
//            from: normalizedText,
//            into: &intent
//        )
//
//        // 6. Content types
//
//        parseContent(
//            from: normalizedText,
//            into: &intent
//        )
//
//        // 7. Network state
//
//        parseNetworkState(
//            from: normalizedText,
//            into: &intent
//        )
//
//        // 8. Standard search terms
//
//        intent.searchTerms = extractSearchTerms(
//            from: normalizedText
//        )
//
//        return intent
//    }
//}
//
//
//// MARK: - Normalization
//
//private extension NLAssistantService {
//
//    func normalize(_ query: String) -> String {
//
//        query
//            .trimmingCharacters(in: .whitespacesAndNewlines)
//            .lowercased()
//            .replacingOccurrences(
//                of: #"\s+"#,
//                with: " ",
//                options: .regularExpression
//            )
//    }
//}
//
//
//// MARK: - Exact Method
//
//private extension NLAssistantService {
//
//    func exactMethod(from text: String) -> String? {
//
//        switch text {
//
//        case "get":
//            return "GET"
//
//        case "post":
//            return "POST"
//
//        case "put":
//            return "PUT"
//
//        case "patch":
//            return "PATCH"
//
//        case "delete":
//            return "DELETE"
//
//        case "query":
//            return "QUERY"
//
//        case "mutation":
//            return "MUTATION"
//
//        default:
//            return nil
//        }
//    }
//}
//
//
//// MARK: - HTTP / GraphQL Methods
//
//private extension NLAssistantService {
//
//    func parseMethods(
//        from text: String,
//        into intent: inout NLQueryIntent
//    ) {
//
//        let tagger = NLTagger(
//            tagSchemes: [.lemma]
//        )
//
//        tagger.string = text
//
//        let options: NLTagger.Options = [
//            .omitWhitespace,
//            .omitPunctuation,
//            .joinNames
//        ]
//
//        tagger.enumerateTags(
//            in: text.startIndex..<text.endIndex,
//            unit: .word,
//            scheme: .lemma,
//            options: options
//        ) { tag, tokenRange in
//
//            let word = String(text[tokenRange])
//            let lemma = tag?.rawValue.lowercased() ?? word
//
//            if let method = self.methodAliases[lemma] {
//                intent.httpMethods.insert(method)
//            }
//
//            return true
//        }
//    }
//
//
//    var methodAliases: [String: String] {
//
//        [
//
//            // GET
//
//            "get": "GET",
//            "fetch": "GET",
//            "retrieve": "GET",
//            "read": "GET",
//            "load": "GET",
//
//            // POST
//
//            "post": "POST",
//            "create": "POST",
//            "submit": "POST",
//            "send": "POST",
//
//            // PUT
//
//            "put": "PUT",
//            "replace": "PUT",
//            "update": "PUT",
//
//            // PATCH
//
//            "patch": "PATCH",
//            "modify": "PATCH",
//            "partial": "PATCH",
//
//            // DELETE
//
//            "delete": "DELETE",
//            "remove": "DELETE",
//            "destroy": "DELETE",
//
//            // GraphQL
//
//            "query": "QUERY",
//            "queries": "QUERY",
//            "mutation": "MUTATION",
//            "mutations": "MUTATION"
//        ]
//    }
//}
//
//
//// MARK: - Status Codes
//
//private extension NLAssistantService {
//
//    func parseStatusCodes(
//        from text: String,
//        into intent: inout NLQueryIntent
//    ) {
//
//        // ---------------------------------------------
//        // Exact status codes
//        // ---------------------------------------------
//
//        let pattern = #"\b[1-5][0-9]{2}\b"#
//
//        guard let regex = try? NSRegularExpression(
//            pattern: pattern
//        ) else {
//            return
//        }
//
//        let range = NSRange(
//            text.startIndex..<text.endIndex,
//            in: text
//        )
//
//        let matches = regex.matches(
//            in: text,
//            range: range
//        )
//
//        for match in matches {
//
//            guard let matchRange = Range(
//                match.range,
//                in: text
//            ) else {
//                continue
//            }
//
//            if let code = Int(text[matchRange]) {
//                intent.statusCodes.insert(code)
//            }
//        }
//
//
//        // ---------------------------------------------
//        // Status classes
//        // ---------------------------------------------
//
//        if contains(text, ["2xx", "200s"]) {
//            intent.statusClass = .success
//        }
//
//        if contains(text, ["3xx", "300s"]) {
//            intent.statusClass = .redirect
//        }
//
//        if contains(text, ["4xx", "400s"]) {
//            intent.statusClass = .clientError
//        }
//
//        if contains(text, ["5xx", "500s"]) {
//            intent.statusClass = .serverError
//        }
//    }
//}
//
//
//// MARK: - Status Meaning
//
//private extension NLAssistantService {
//
//    func parseStatusClass(
//        from text: String,
//        into intent: inout NLQueryIntent
//    ) {
//
//        // ---------------------------------------------
//        // Success
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "success",
//                "successful",
//                "succeeded",
//                "succeed",
//                "ok",
//                "working",
//                "completed successfully"
//            ]
//        ) {
//
//            intent.statusClass = .success
//        }
//
//
//        // ---------------------------------------------
//        // Redirect
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "redirect",
//                "redirected",
//                "redirects"
//            ]
//        ) {
//
//            intent.statusClass = .redirect
//        }
//
//
//        // ---------------------------------------------
//        // Client Errors
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "client error",
//                "client errors",
//                "client failure",
//                "4xx error",
//                "4xx errors"
//            ]
//        ) {
//
//            intent.statusClass = .clientError
//        }
//
//
//        // ---------------------------------------------
//        // Server Errors
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "server error",
//                "server errors",
//                "server failure",
//                "5xx error",
//                "5xx errors"
//            ]
//        ) {
//
//            intent.statusClass = .serverError
//        }
//
//
//        // ---------------------------------------------
//        // General Failure
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "failed",
//                "failure",
//                "failures",
//                "error",
//                "errors",
//                "unsuccessful",
//                "unsuccessfully",
//                "broken"
//            ]
//        ) {
//
//            intent.statusClass = .failure
//        }
//    }
//}
//
//
//// MARK: - Performance
//
//private extension NLAssistantService {
//
//    func parsePerformance(
//        from text: String,
//        into intent: inout NLQueryIntent
//    ) {
//
//        // ---------------------------------------------
//        // Slow
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "slow",
//                "slower",
//                "slowest",
//                "sluggish",
//                "laggy",
//                "delayed",
//                "high latency",
//                "high-latency"
//            ]
//        ) {
//
//            intent.performance = .slow
//        }
//
//
//        // ---------------------------------------------
//        // Fast
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "fast",
//                "faster",
//                "fastest",
//                "quick",
//                "quickest",
//                "low latency",
//                "low-latency"
//            ]
//        ) {
//
//            intent.performance = .fast
//        }
//
//
//        // ---------------------------------------------
//        // Minimum Duration
//        //
//        // Examples:
//        //
//        // over 2 seconds
//        // above 500 ms
//        // more than 1 second
//        // longer than 1.5 seconds
//        // ---------------------------------------------
//
//        let minimumPatterns = [
//
//            #"over\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#,
//
//            #"above\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#,
//
//            #"more than\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#,
//
//            #"longer than\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#
//        ]
//
//        for pattern in minimumPatterns {
//
//            if let duration = extractDuration(
//                from: text,
//                pattern: pattern
//            ) {
//
//                intent.performance = .minimumDuration(duration)
//
//                break
//            }
//        }
//
//
//        // ---------------------------------------------
//        // Maximum Duration
//        //
//        // Examples:
//        //
//        // under 1 second
//        // below 500 ms
//        // less than 2 seconds
//        // shorter than 1.5 seconds
//        // ---------------------------------------------
//
//        let maximumPatterns = [
//
//            #"under\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#,
//
//            #"below\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#,
//
//            #"less than\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#,
//
//            #"shorter than\s+(\d+(?:\.\d+)?)\s*(ms|milliseconds|s|sec|seconds)"#
//        ]
//
//        for pattern in maximumPatterns {
//
//            if let duration = extractDuration(
//                from: text,
//                pattern: pattern
//            ) {
//
//                intent.performance = .maximumDuration(duration)
//
//                break
//            }
//        }
//    }
//
//
//    func extractDuration(
//        from text: String,
//        pattern: String
//    ) -> TimeInterval? {
//
//        guard let regex = try? NSRegularExpression(
//            pattern: pattern,
//            options: .caseInsensitive
//        ) else {
//            return nil
//        }
//
//        let range = NSRange(
//            text.startIndex..<text.endIndex,
//            in: text
//        )
//
//        guard let match = regex.firstMatch(
//            in: text,
//            range: range
//        ) else {
//            return nil
//        }
//
//        guard
//            let numberRange = Range(
//                match.range(at: 1),
//                in: text
//            ),
//            let unitRange = Range(
//                match.range(at: 2),
//                in: text
//            )
//        else {
//            return nil
//        }
//
//        guard let value = Double(
//            text[numberRange]
//        ) else {
//            return nil
//        }
//
//        let unit = text[unitRange].lowercased()
//
//        switch unit {
//
//        case "ms", "milliseconds":
//            return value / 1000.0
//
//        case "s", "sec", "seconds":
//            return value
//
//        default:
//            return nil
//        }
//    }
//}
//
//
//// MARK: - Content
//
//private extension NLAssistantService {
//
//    func parseContent(
//        from text: String,
//        into intent: inout NLQueryIntent
//    ) {
//
//        // ---------------------------------------------
//        // Image
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "image",
//                "images",
//                "photo",
//                "photos",
//                "picture",
//                "pictures",
//                "jpeg",
//                "jpg",
//                "png"
//            ]
//        ) {
//
//            intent.contentTypes.insert(.image)
//        }
//
//
//        // ---------------------------------------------
//        // JSON
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "json",
//                "json response",
//                "json responses"
//            ]
//        ) {
//
//            intent.contentTypes.insert(.json)
//        }
//
//
//        // ---------------------------------------------
//        // Text
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "text",
//                "plain text",
//                "text response"
//            ]
//        ) {
//
//            intent.contentTypes.insert(.text)
//        }
//
//
//        // ---------------------------------------------
//        // HTML
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "html",
//                "webpage",
//                "web page"
//            ]
//        ) {
//
//            intent.contentTypes.insert(.html)
//        }
//    }
//}
//
//
//// MARK: - Network State
//
//private extension NLAssistantService {
//
//    func parseNetworkState(
//        from text: String,
//        into intent: inout NLQueryIntent
//    ) {
//
//        // ---------------------------------------------
//        // Cache
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "cache",
//                "cached",
//                "from cache",
//                "cache hit",
//                "cache hits"
//            ]
//        ) {
//
//            intent.requiresCacheHit = true
//        }
//
//
//        // ---------------------------------------------
//        // Pending / In-Flight
//        // ---------------------------------------------
//
//        if contains(
//            text,
//            [
//                "pending",
//                "loading",
//                "in flight",
//                "inflight",
//                "ongoing",
//                "active"
//            ]
//        ) {
//
//            intent.requiresPending = true
//        }
//    }
//}
//
//
//// MARK: - Search Terms
//
//private extension NLAssistantService {
//
//    func extractSearchTerms(
//        from text: String
//    ) -> [String] {
//
//        let tagger = NLTagger(
//            tagSchemes: [.lemma]
//        )
//
//        tagger.string = text
//
//        let options: NLTagger.Options = [
//            .omitWhitespace,
//            .omitPunctuation,
//            .joinNames
//        ]
//
//        var terms: [String] = []
//
//        tagger.enumerateTags(
//            in: text.startIndex..<text.endIndex,
//            unit: .word,
//            scheme: .lemma,
//            options: options
//        ) { tag, tokenRange in
//
//            let word = String(text[tokenRange])
//            let lemma = tag?.rawValue.lowercased() ?? word
//
//            // Ignore recognized intent words.
//
//            if self.isIntentWord(lemma) {
//                return true
//            }
//
//            // Ignore status numbers.
//
//            if Int(lemma) != nil {
//                return true
//            }
//
//            // Ignore one-character words.
//
//            if lemma.count <= 1 {
//                return true
//            }
//
//            terms.append(word)
//
//            return true
//        }
//
//
//        // Remove duplicates while preserving order.
//
//        var seen = Set<String>()
//
//        return terms.filter {
//            seen.insert($0.lowercased()).inserted
//        }
//    }
//
//
//    func isIntentWord(
//        _ word: String
//    ) -> Bool {
//
//        let intentWords: Set<String> = [
//
//            // HTTP
//
//            "get",
//            "fetch",
//            "retrieve",
//            "read",
//            "load",
//
//            "post",
//            "create",
//            "submit",
//            "send",
//
//            "put",
//            "replace",
//            "update",
//
//            "patch",
//            "modify",
//            "partial",
//
//            "delete",
//            "remove",
//            "destroy",
//
//            // GraphQL
//
//            "query",
//            "queries",
//            "mutation",
//            "mutations",
//
//            // Status
//
//            "success",
//            "successful",
//            "succeed",
//            "succeeded",
//            "ok",
//
//            "redirect",
//            "redirected",
//            "redirects",
//
//            "client",
//            "server",
//
//            "failed",
//            "failure",
//            "failures",
//            "error",
//            "errors",
//            "unsuccessful",
//            "unsuccessfully",
//            "broken",
//
//            // Performance
//
//            "slow",
//            "slower",
//            "slowest",
//            "sluggish",
//            "laggy",
//            "delayed",
//
//            "fast",
//            "faster",
//            "fastest",
//            "quick",
//            "quickest",
//
//            "latency",
//
//            // Content
//
//            "image",
//            "images",
//            "photo",
//            "photos",
//            "picture",
//            "pictures",
//
//            "jpeg",
//            "jpg",
//            "png",
//
//            "json",
//            "text",
//            "html",
//
//            // Network
//
//            "cache",
//            "cached",
//
//            "pending",
//            "loading",
//            "inflight",
//            "ongoing",
//            "active",
//
//            // Common search words
//
//            "show",
//            "find",
//            "search",
//            "display",
//            "list",
//            "give",
//            "me",
//            "the",
//            "a",
//            "an",
//            "all",
//            "only",
//
//            "request",
//            "requests",
//            "call",
//            "calls",
//
//            "api",
//            "apis",
//            "network",
//            "traffic",
//
//            "response",
//            "responses",
//
//            // Duration
//
//            "over",
//            "above",
//            "under",
//            "below",
//            "more",
//            "less",
//            "than",
//            "longer",
//            "shorter",
//
//            "seconds",
//            "second",
//            "milliseconds",
//            "millisecond",
//            "ms"
//        ]
//
//        return intentWords.contains(word)
//    }
//}
//
//
//// MARK: - Helpers
//
//private extension NLAssistantService {
//
//    func contains(
//        _ text: String,
//        _ values: [String]
//    ) -> Bool {
//
//        values.contains { value in
//            text.localizedCaseInsensitiveContains(value)
//        }
//    }
//}
//
