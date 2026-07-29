import Foundation

/// A fast, zero-dependency fuzzy search engine using Levenshtein edit distance.
/// Finds matches even with typos, missing characters, or transpositions.
public struct FuzzySearchEngine {
    
    /// Returns a score from 0.0 (no match) to 1.0 (perfect match).
    /// Threshold of 0.5 works well for developer tool searches.
    public static func score(_ query: String, against target: String) -> Double {
        let query = query.lowercased()
        let target = target.lowercased()
        
        if query.isEmpty { return 1.0 }
        if target.isEmpty { return 0.0 }
        if target.contains(query) { return 1.0 } // Exact substring — instant win
        
        let qChars = Array(query)
        let tChars = Array(target)
        let distance = levenshtein(qChars, tChars)
        let maxLen = max(qChars.count, tChars.count)
        
        return 1.0 - (Double(distance) / Double(maxLen))
    }
    
    /// Returns true if the query fuzzy-matches any part of the target.
    public static func matches(_ query: String, in target: String, threshold: Double = 0.5) -> Bool {
        if query.isEmpty { return true }
        let q = query.lowercased()
        let t = target.lowercased()
        
        // Fast path: exact substring
        if t.contains(q) { return true }
        
        // Sliding window: check each window of target equal to query length
        let qChars = Array(q)
        let tChars = Array(t)
        let windowSize = min(qChars.count + 2, tChars.count)
        
        if windowSize <= 0 { return false }
        
        for start in 0...(tChars.count - windowSize) {
            let window = Array(tChars[start..<(start + windowSize)])
            let dist = levenshtein(qChars, window)
            let maxLen = max(qChars.count, window.count)
            let windowScore = 1.0 - (Double(dist) / Double(maxLen))
            if windowScore >= threshold { return true }
        }
        
        return false
    }
    
    // MARK: - Levenshtein Distance (Dynamic Programming)
    private static func levenshtein(_ s: [Character], _ t: [Character]) -> Int {
        let m = s.count, n = t.count
        if m == 0 { return n }
        if n == 0 { return m }
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if s[i-1] == t[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
}
