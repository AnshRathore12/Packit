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
            case "image", "photo", "picture":
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
