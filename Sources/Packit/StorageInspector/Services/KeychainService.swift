import Foundation
import Combine
import Security

public class KeychainService: StorageProvider {
    public let didChangePublisher = PassthroughSubject<Void, Never>()
    
    public init() {}
    
    public func fetchAll() -> [PreferenceItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        
        var preferences: [PreferenceItem] = []
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               let data = item[kSecValueData as String] as? Data {
                
                // Try to parse string, otherwise fallback to Data
                let valueToStore: Any
                if let stringVal = String(data: data, encoding: .utf8) {
                    valueToStore = stringVal
                } else {
                    valueToStore = data
                }
                
                preferences.append(PreferenceItem(key: account, value: valueToStore))
            }
        }
        
        return preferences
    }
    
    public func set(value: Any, forKey key: String) {
        guard let stringVal = value as? String, let data = stringVal.data(using: .utf8) else {
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            SecItemAdd(newQuery as CFDictionary, nil)
        }
        
        // Notify UI to refresh
        didChangePublisher.send()
    }
    
    public func remove(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        
        didChangePublisher.send()
    }
    
    public func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        SecItemDelete(query as CFDictionary)
        
        didChangePublisher.send()
    }
}
