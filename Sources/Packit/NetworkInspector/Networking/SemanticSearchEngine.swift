// import Foundation
// import NaturalLanguage

// /// A fully on-device semantic search engine leveraging Apple's NaturalLanguage framework.
// /// Requires 0 network requests and adds 0 bytes to the app bundle.
// public struct SemanticSearchEngine {
    
//     // NLEmbedding is available on iOS 14.0+
// //    @available(iOS 14.0, macOS 11.0, *)
// //    private static let embedding = NLEmbedding.sentenceEmbedding(for: .english)
//     @available(iOS 14.0, macOS 11.0, *)
//     nonisolated(unsafe) private static let embedding = NLEmbedding.sentenceEmbedding(for: .english)
//     /// Computes the semantic similarity score between a query and target string.
//     /// Returns a value between -1.0 (opposite meaning) and 1.0 (exact same meaning).
//     /// If NLEmbedding is unavailable, returns 0.0.
//     public static func semanticScore(_ query: String, against target: String) -> Double {
//         guard #available(iOS 14.0, macOS 11.0, *),
//               let embed = embedding else {
//             return 0.0
//         }
        
//         let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
//         let t = target.trimmingCharacters(in: .whitespacesAndNewlines)
        
//         if q.isEmpty || t.isEmpty { return 0.0 }
//         if q.lowercased() == t.lowercased() { return 1.0 }
        
//         // Clean the strings so the sentence model can read URLs like English words
//         let cleanQ = q.replacingOccurrences(of: "/", with: " ")
//                       .replacingOccurrences(of: "-", with: " ")
//                       .replacingOccurrences(of: "_", with: " ")
//                       .replacingOccurrences(of: "?", with: " ")
//         let cleanT = t.replacingOccurrences(of: "/", with: " ")
//                       .replacingOccurrences(of: "-", with: " ")
//                       .replacingOccurrences(of: "_", with: " ")
//                       .replacingOccurrences(of: "?", with: " ")
        
//         let distance = embed.distance(between: cleanQ, and: cleanT)
        
//         // distance is generally between 0.0 and 2.0. 
//         // A distance of 0 means perfect match.
//         return 1.0 - distance
//     }
    
//     /// Computes a Hybrid score (Fuzzy + Semantic)
//     /// - `fuzzyWeight`: How much weight to give exact character matching (0.0 to 1.0)
//     /// - `semanticWeight`: How much weight to give contextual meaning (0.0 to 1.0)
//     public static func hybridScore(_ query: String, against target: String, fuzzyWeight: Double = 0.4, semanticWeight: Double = 0.6) -> Double {
//         let fuzzy = FuzzySearchEngine.score(query, against: target)
        
//         // If it's an exact fuzzy match (e.g. substring), return 1.0 immediately
//         if fuzzy == 1.0 { return 1.0 }
        
//         let semantic = semanticScore(query, against: target)
        
//         // Normalize semantic score from [-1, 1] to [0, 1] to combine with fuzzy
//         let normalizedSemantic = max(0.0, (semantic + 1.0) / 2.0)
        
//         return (fuzzy * fuzzyWeight) + (normalizedSemantic * semanticWeight)
//     }
// }
