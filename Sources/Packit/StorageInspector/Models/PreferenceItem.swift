import Foundation

public struct PreferenceItem: Identifiable, Equatable, Hashable {
    public let id: String
    public let key: String
    public let value: Any
    public let typeName: String
    public let isEditable: Bool
    
    public init(key: String, value: Any) {
        self.id = key
        self.key = key
        self.value = value
        
        let parsed = Self.parse(value: value)
        self.typeName = parsed.typeName
        self.isEditable = parsed.isEditable
    }
    
    public static func == (lhs: PreferenceItem, rhs: PreferenceItem) -> Bool {
        return lhs.key == rhs.key
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    public var stringRepresentation: String {
        return Self.parse(value: value).stringRepresentation
    }
    
    public var isSensitive: Bool {
        let lowerKey = key.lowercased()
        let sensitiveKeywords = ["token", "password", "secret", "apikey", "accesstoken", "refreshtoken", "authorization", "bearer"]
        return sensitiveKeywords.contains(where: { lowerKey.contains($0) })
    }
    
    public var memoryUsageBytes: Int {
        if let data = value as? Data {
            return data.count
        } else if let str = value as? String {
            return str.utf8.count
        } else if let array = value as? [Any], let data = try? JSONSerialization.data(withJSONObject: array) {
            return data.count
        } else if let dict = value as? [String: Any], let data = try? JSONSerialization.data(withJSONObject: dict) {
            return data.count
        }
        return MemoryLayout.size(ofValue: value)
    }
    
    // MARK: - Parser Helpers
    
    private static func parse(value: Any) -> (typeName: String, stringRepresentation: String, isEditable: Bool) {
        let mirror = Mirror(reflecting: value)
        var typeStr = String(describing: type(of: value))
        
        // Handle optional unwrapping visually
        if let displayStyle = mirror.displayStyle, displayStyle == .optional {
            if let firstChild = mirror.children.first {
                typeStr = String(describing: type(of: firstChild.value))
                return parseInner(value: firstChild.value, typeName: typeStr)
            } else {
                return ("Optional", "nil", false)
            }
        }
        
        return parseInner(value: value, typeName: typeStr)
    }
    
    private static func parseInner(value: Any, typeName: String) -> (typeName: String, stringRepresentation: String, isEditable: Bool) {
        if let str = value as? String {
            return ("String", str, true)
        } else if let b = value as? Bool {
            // Bool actually checks as Int in Objective-C bridged UserDefaults sometimes, 
            // but swift detects it if strongly typed. 
            // Note: CFBoolean checking might be needed in UserDefaultsService
            return ("Bool", b ? "true" : "false", true)
        } else if let d = value as? Double {
            return ("Double", String(d), true)
        } else if let f = value as? Float {
            return ("Float", String(f), true)
        } else if let i = value as? Int {
            return ("Int", String(i), true)
        } else if let date = value as? Date {
            let formatter = ISO8601DateFormatter()
            return ("Date", formatter.string(from: date), false)
        } else if let data = value as? Data {
            return ("Data", "\(data.count) bytes", false)
        } else if let array = value as? [Any] {
            return ("Array", "[\(array.count) items]", false)
        } else if let dict = value as? [String: Any] {
            return ("Dictionary", "{\(dict.keys.count) keys}", false)
        } else if let url = value as? URL {
            return ("URL", url.absoluteString, false)
        } else {
            return ("Unknown", String(describing: value), false)
        }
    }
}
