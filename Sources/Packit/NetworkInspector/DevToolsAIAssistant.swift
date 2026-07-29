import Foundation
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Actionable Item (Deep Link)

/// A tappable deep-link card attached to an AI response.
public struct AIActionableItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let badge: String          // e.g. "GET", "POST", "STRING", "DATA"
    public let badgeColor: ItemColor
    public let type: ItemType
    public var searchQuery: String? = nil
    
    public enum ItemColor { case blue, green, red, orange, purple, gray }
    
    public enum ItemType {
        case networkTransaction(NetworkTransaction)
        case userDefaultsKey(PreferenceItem)
        case keychainItem(PreferenceItem)
    }
}

// MARK: - Message Model

public struct AIMessage: Identifiable {
    public let id = UUID()
    public let role: Role
    public var content: String
    public var actionableItems: [AIActionableItem]
    public let timestamp = Date()
    
    public enum Role { case user, assistant }
    
    public init(role: Role, content: String, actionableItems: [AIActionableItem] = []) {
        self.role = role
        self.content = content
        self.actionableItems = actionableItems
    }
}

// MARK: - Assistant

@MainActor
public class DevToolsAIAssistant: ObservableObject {
    public static let shared = DevToolsAIAssistant()
    
    @Published public var messages: [AIMessage] = []
    @Published public var isThinking: Bool = false
    @Published public var isAvailable: Bool = false
    @Published public var availabilityMessage: String = ""
    @Published public var streamingResponse: String = ""
    
    private init() { checkAvailability() }
    
    private func checkAvailability() {
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                isAvailable = true
                availabilityMessage = ""
            case .unavailable(let reason):
                isAvailable = false
                switch reason {
                case .deviceNotEligible:
                    availabilityMessage = "This device does not support Apple Intelligence."
                case .appleIntelligenceNotEnabled:
                    availabilityMessage = "Enable Apple Intelligence in Settings → Apple Intelligence & Siri."
                case .modelNotReady:
                    availabilityMessage = "Apple Intelligence model is downloading. Try again soon."
                @unknown default:
                    availabilityMessage = "Apple Intelligence is unavailable right now."
                }
            }
        } else {
            isAvailable = false
            availabilityMessage = "Full AI requires iOS 26 with Apple Intelligence."
        }
    }
    
    public func send(_ userMessage: String) async {
        guard !userMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        messages.append(AIMessage(role: .user, content: userMessage))
        isThinking = true
        streamingResponse = ""
        
        // Always run rule engine to collect actionable items
        let (ruleText, actionableItems) = generateFallbackResponse(for: userMessage)
        
        var finalText = ruleText
        
        if #available(iOS 26.0, *), isAvailable {
            do {
                finalText = try await generateWithFoundationModels(query: userMessage, ruleContext: ruleText)
            } catch {
                // Fall back silently — we already have rule results
            }
        }
        
        messages.append(AIMessage(role: .assistant, content: finalText, actionableItems: actionableItems))
        isThinking = false
        streamingResponse = ""
    }
    
    public func clearHistory() {
        messages = []
        streamingResponse = ""
    }
    
    // MARK: - Foundation Models (iOS 26+)
    
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(query: String, ruleContext: String) async throws -> String {
        let context = buildTruncatedContext(maxChars: 3000)
        let systemPrompt = """
        You are DevTools AI, a concise iOS debugging assistant inside a developer tool.
        You have access to live app data below. Answer based only on this data.
        Be concise (under 150 words). Use bullet points and emoji.
        Never reveal masked values (***MASKED***).
        
        === LIVE APP DATA ===
        \(context)
        === END DATA ===
        """
        let session = LanguageModelSession(instructions: systemPrompt)
        var fullResponse = ""
        let stream = session.streamResponse(to: query)
        for try await partialResponse in stream {
            fullResponse = partialResponse.content
            streamingResponse = fullResponse
        }
        return fullResponse.isEmpty ? ruleContext : fullResponse
    }
    
    private func buildTruncatedContext(maxChars: Int) -> String {
        let full = AIContextBuilder.buildContext()
        if full.count <= maxChars { return full }
        return String(full.prefix(maxChars)) + "\n[...truncated]"
    }
    
    // MARK: - Rule Engine (returns text + actionable items)
    
    private func generateFallbackResponse(for query: String) -> (String, [AIActionableItem]) {
        let q = query.lowercased()
        
        // --- Failed requests ---
        if q.contains("fail") || q.contains("error") || q.contains("crash") {
            let failed = NetworkStore.shared.transactions.filter { $0.isFailed }
            if failed.isEmpty { return ("✅ No failed requests found in the current session.", []) }
            let items = failed.prefix(10).map { tx -> AIActionableItem in
                let url = tx.request.url?.path ?? "unknown"
                let status = (tx.response as? HTTPURLResponse).map { "\($0.statusCode)" } ?? "ERR"
                return AIActionableItem(title: url, subtitle: status + " · " + (tx.request.url?.host ?? ""), badge: tx.request.httpMethod ?? "?", badgeColor: .red, type: .networkTransaction(tx))
            }
            return ("❌ Found \(failed.count) failed request(s). Tap to inspect:", Array(items))
        }
        
        // --- Slow requests ---
        if q.contains("slow") || q.contains("lag") || q.contains("performance") {
            let slow = NetworkStore.shared.transactions
                .filter { ($0.duration ?? 0) > 0.5 }
                .sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
            if slow.isEmpty { return ("✅ No slow requests (>500ms) found.", []) }
            let items = slow.prefix(10).map { tx -> AIActionableItem in
                let ms = Int((tx.duration ?? 0) * 1000)
                let url = tx.request.url?.path ?? "unknown"
                return AIActionableItem(title: url, subtitle: "\(ms)ms · " + (tx.request.url?.host ?? ""), badge: tx.request.httpMethod ?? "?", badgeColor: ms > 1000 ? .red : .orange, type: .networkTransaction(tx))
            }
            return ("🐌 \(slow.count) slow request(s) found. Tap to inspect:", Array(items))
        }
        
        // --- Auth / token leaks ---
        if q.contains("token") || q.contains("auth") || q.contains("leak") || q.contains("header") {
            let authCalls = NetworkStore.shared.transactions.filter { tx in
                (tx.request.allHTTPHeaderFields ?? [:]).keys.contains(where: {
                    $0.lowercased().contains("auth") || $0.lowercased().contains("token") || $0.lowercased().contains("api-key")
                })
            }
            if authCalls.isEmpty { return ("🔒 No requests with auth headers detected.", []) }
            let items = authCalls.prefix(10).map { tx -> AIActionableItem in
                let url = tx.request.url?.path ?? "unknown"
                return AIActionableItem(title: url, subtitle: "Has Authorization header · " + (tx.request.url?.host ?? ""), badge: tx.request.httpMethod ?? "?", badgeColor: .purple, type: .networkTransaction(tx))
            }
            return ("🔑 \(authCalls.count) request(s) sending auth headers (values masked). Tap to inspect:", Array(items))
        }
        
        // --- Location data ---
        if q.contains("location") || q.contains("lat") || q.contains("lng") || q.contains("gps") {
            let txs = NetworkStore.shared.transactions.filter { tx in
                let url = tx.request.url?.absoluteString.lowercased() ?? ""
                return url.contains("lat") || url.contains("lng") || url.contains("location") || url.contains("geo")
            }
            if txs.isEmpty { return ("📍 No location-related API calls detected.", []) }
            let items = txs.prefix(10).map { tx -> AIActionableItem in
                let url = tx.request.url?.path ?? "unknown"
                return AIActionableItem(title: url, subtitle: tx.request.url?.host ?? "", badge: tx.request.httpMethod ?? "?", badgeColor: .blue, type: .networkTransaction(tx))
            }
            return ("📍 Found \(txs.count) location-related call(s):", Array(items))
        }
        
        // --- Member data / UserDefaults ---
        if q.contains("member") || q.contains("user") || q.contains("profile") {
            let udItems = UserDefaultsService().fetchAll().filter {
                let k = $0.key.lowercased()
                return k.contains("member") || k.contains("user") || k.contains("profile")
            }
            let netTxs = NetworkStore.shared.transactions.filter { tx in
                let url = tx.request.url?.absoluteString.lowercased() ?? ""
                return url.contains("member") || url.contains("user") || url.contains("profile")
            }
            var items: [AIActionableItem] = []
            items += udItems.prefix(5).map { item in
                AIActionableItem(title: item.key, subtitle: "\(item.typeName) · \(item.memoryUsageBytes) bytes", badge: item.typeName.uppercased().prefix(4).description, badgeColor: .green, type: .userDefaultsKey(item))
            }
            items += netTxs.prefix(5).map { tx in
                AIActionableItem(title: tx.request.url?.path ?? "unknown", subtitle: tx.request.url?.host ?? "", badge: tx.request.httpMethod ?? "?", badgeColor: .blue, type: .networkTransaction(tx))
            }
            if items.isEmpty { return ("📭 No member/user related data found.", []) }
            return ("👤 Found \(items.count) member/user related item(s):", items)
        }
        
        // --- Keychain ---
        if q.contains("keychain") || q.contains("secure") || q.contains("secret") {
            let items = KeychainService().fetchAll()
            if items.isEmpty { return ("🔐 No keychain entries found.", []) }
            let actionable = items.prefix(10).map { item in
                AIActionableItem(title: item.key, subtitle: "\(item.typeName) · \(item.memoryUsageBytes) bytes [value masked]", badge: "KEY", badgeColor: .purple, type: .keychainItem(item))
            }
            return ("🔐 Found \(items.count) keychain entry/entries:", Array(actionable))
        }
        
        // --- Crypto / holdings / portfolio ---
        if q.contains("bitcoin") || q.contains("crypto") || q.contains("coin") || q.contains("btc") || q.contains("holdings") || q.contains("portfolio") || q.contains("market") {
            let txs = NetworkStore.shared.transactions.filter { tx in
                let url = tx.request.url?.absoluteString.lowercased() ?? ""
                return url.contains("bitcoin") || url.contains("crypto") || url.contains("coin") ||
                       url.contains("btc") || url.contains("market") || url.contains("coingecko") ||
                       url.contains("coinmarketcap") || url.contains("price")
            }
            let udItems = UserDefaultsService().fetchAll().filter {
                let k = $0.key.lowercased()
                return k.contains("coin") || k.contains("btc") || k.contains("crypto") || k.contains("holding") || k.contains("portfolio")
            }
            var items: [AIActionableItem] = []
            items += txs.prefix(8).map { tx in
                let ms = tx.duration.map { "\(Int($0 * 1000))ms" } ?? "pending"
                let status = (tx.response as? HTTPURLResponse).map { "\($0.statusCode)" } ?? "–"
                return AIActionableItem(title: tx.request.url?.path ?? "unknown", subtitle: "\(status) · \(ms) · " + (tx.request.url?.host ?? ""), badge: tx.request.httpMethod ?? "?", badgeColor: .orange, type: .networkTransaction(tx))
            }
            items += udItems.prefix(5).map { item in
                AIActionableItem(title: item.key, subtitle: "\(item.typeName) · \(item.memoryUsageBytes) bytes", badge: item.typeName.uppercased().prefix(4).description, badgeColor: .green, type: .userDefaultsKey(item))
            }
            if items.isEmpty { return ("📭 No crypto/Bitcoin related data found.", []) }
            return ("🪙 Found \(items.count) crypto-related item(s). Tap to inspect:", items)
        }
        
        // --- Generic Hybrid Semantic Search across everything ---
        
        let txScores = NetworkStore.shared.transactions.map { tx -> (NetworkTransaction, Double) in
            let text = [tx.request.url?.path ?? "", tx.categoryName, tx.request.httpMethod ?? ""]
                .joined(separator: " ")
            let score = SemanticSearchEngine.hybridScore(q, against: text)
            return (tx, score)
        }
        .filter { $0.1 > 0.2 } // threshold
        .sorted { $0.1 > $1.1 }
        
        let matchingTxs = txScores.prefix(5).map { $0.0 }
        
        let udScores = UserDefaultsService().fetchAll().map { item -> (PreferenceItem, Double) in
            let text = [item.key, item.stringRepresentation].joined(separator: " ")
            let score = SemanticSearchEngine.hybridScore(q, against: text)
            return (item, score)
        }
        .filter { $0.1 > 0.2 } // threshold
        .sorted { $0.1 > $1.1 }
        
        let matchingUD = udScores.prefix(5).map { $0.0 }
        
        var items: [AIActionableItem] = []
        items += matchingTxs.map { tx in
            AIActionableItem(title: tx.request.url?.path ?? "unknown", subtitle: tx.request.url?.host ?? "", badge: tx.request.httpMethod ?? "?", badgeColor: .blue, type: .networkTransaction(tx), searchQuery: query)
        }
        items += matchingUD.map { item in
            AIActionableItem(title: item.key, subtitle: "\(item.typeName) · \(item.memoryUsageBytes) bytes", badge: item.typeName.uppercased().prefix(4).description, badgeColor: .green, type: .userDefaultsKey(item), searchQuery: query)
        }
        
        if !items.isEmpty {
            return ("🧠 Found \(items.count) semantic match(es) for '\(query)'. Tap to inspect:", items)
        }
        
        return ("🤔 No data found related to '\(query)'. Try: 'failed requests', 'slow APIs', 'auth tokens', 'member data', or 'keychain'.", [])
    }
    
    private func errorDescription(_ error: Error) -> String {
        let desc = error.localizedDescription
        if desc.contains("-1") { return "model unavailable" }
        return desc
    }
}
