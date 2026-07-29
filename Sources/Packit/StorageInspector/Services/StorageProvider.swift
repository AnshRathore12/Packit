import Foundation
import Combine

public protocol StorageProvider {
    /// Publisher that emits whenever the underlying storage changes
    var didChangePublisher: PassthroughSubject<Void, Never> { get }
    
    /// Fetches all keys and values from the storage
    func fetchAll() -> [PreferenceItem]
    
    /// Writes a value for a specific key
    func set(value: Any, forKey key: String)
    
    /// Removes a value for a specific key
    func remove(forKey key: String)
    
    /// Clears all non-system values from the storage
    func clearAll()
}
