import Foundation
import Combine

public class UserDefaultsService: StorageProvider {
    public static let shared = UserDefaultsService()
    
    private let userDefaults: UserDefaults
    private let suiteName: String?
    
    // Publisher that emits whenever UserDefaults changes
    public let didChangePublisher = PassthroughSubject<Void, Never>()
    
    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
        if let suite = suiteName, let defaults = UserDefaults(suiteName: suite) {
            self.userDefaults = defaults
        } else {
            self.userDefaults = .standard
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func defaultsChanged() {
        didChangePublisher.send()
    }
    
    // MARK: - Read
    
    public func fetchAll() -> [PreferenceItem] {
        print("--- DEVTOOLSKIT FETCHING DEFAULTS v2 ---")
        let dictionary = userDefaults.dictionaryRepresentation()
        
        let systemPrefixes = [
            "apple", "ns", "webkit", "com.apple", "pk", "_ui", "ui", "metal",
            "ak", "activeprototyping", "addingemoji", "clearprototype", "clearsettings",
            "remoteprototyping", "ringerbutton", "ringerswitch", "testrecipe",
            "volumedown", "volumeup", "acdmonthly", "cg", "os", "xct",
            "haptics", "tcc", "accessibility", "awd", "coreduet"
        ]
        
        var items: [PreferenceItem] = []
        for (key, value) in dictionary {
            let lowerKey = key.lowercased()
            if systemPrefixes.contains(where: { lowerKey.hasPrefix($0) }) {
                continue
            }
            
            // Handle ObjC CFBoolean mapping to Swift Bool
            let normalizedValue: Any
            if type(of: value) == type(of: NSNumber(value: true)), let num = value as? NSNumber {
                if CFGetTypeID(num) == CFBooleanGetTypeID() {
                    normalizedValue = num.boolValue
                } else {
                    normalizedValue = value
                }
            } else {
                normalizedValue = value
            }
            
            items.append(PreferenceItem(key: key, value: normalizedValue))
        }
        
        return items
    }
    
    // MARK: - Write
    
    public func set(value: Any, forKey key: String) {
        userDefaults.set(value, forKey: key)
        // Note: setting a value triggers the notification automatically
    }
    
    // MARK: - Delete
    
    public func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    public func clearAll() {
        let dictionary = userDefaults.dictionaryRepresentation()
        
        let systemPrefixes = [
            "apple", "ns", "webkit", "com.apple", "pk", "_ui", "ui", "metal",
            "ak", "activeprototyping", "addingemoji", "clearprototype", "clearsettings",
            "remoteprototyping", "ringerbutton", "ringerswitch", "testrecipe",
            "volumedown", "volumeup", "acdmonthly", "cg", "os", "xct",
            "haptics", "tcc", "accessibility", "awd", "coreduet"
        ]
        
        for (key, _) in dictionary {
            let lowerKey = key.lowercased()
            if systemPrefixes.contains(where: { lowerKey.hasPrefix($0) }) {
                continue
            }
            userDefaults.removeObject(forKey: key)
        }
    }
}

