import Foundation
import Combine
import SwiftUI

public enum SortOption {
    case alphabetical
    case reverseAlphabetical
    case byType
    case bySize
}

@MainActor
public class PreferencesStore: ObservableObject {
    @Published public var preferences: [PreferenceItem] = []
    @Published public var searchQuery: String = ""
    @Published public var sortOption: SortOption = .alphabetical
    @Published public var isLoading: Bool = false
    
    // Cached original data from UserDefaults to avoid disk reads on every search stroke
    private var allPreferencesCache: [PreferenceItem] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let service: StorageProvider
    
    public init(service: StorageProvider) {
        self.service = service
        setupBindings()
        refresh()
    }
    
    private func setupBindings() {
        // Auto-refresh when UserDefaults change in the background
        service.didChangePublisher
            // Debounce to prevent UI thrashing if many keys change rapidly
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
            
        // Trigger filtering whenever search query or sort option changes
        Publishers.CombineLatest($searchQuery, $sortOption)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.applyFiltersAndSort()
            }
            .store(in: &cancellables)
    }
    
    public func refresh() {
        isLoading = true
        
        Task {
            // Read off the main thread
            let items = await Task.detached(priority: .userInitiated) {
                return self.service.fetchAll()
            }.value
            
            self.allPreferencesCache = items
            self.applyFiltersAndSort()
            self.isLoading = false
        }
    }
    
    private func applyFiltersAndSort() {
        var filtered = allPreferencesCache
        
        // 1. Search
        if !searchQuery.isEmpty {
            let query = searchQuery
            filtered = filtered.filter { item in
                FuzzySearchEngine.matches(query, in: item.key) ||
                FuzzySearchEngine.matches(query, in: item.stringRepresentation) ||
                FuzzySearchEngine.matches(query, in: item.typeName)
            }
        }
        
        // 2. Sort
        switch sortOption {
        case .alphabetical:
            filtered.sort { $0.key.lowercased() < $1.key.lowercased() }
        case .reverseAlphabetical:
            filtered.sort { $0.key.lowercased() > $1.key.lowercased() }
        case .byType:
            filtered.sort {
                if $0.typeName == $1.typeName {
                    return $0.key.lowercased() < $1.key.lowercased()
                }
                return $0.typeName < $1.typeName
            }
        case .bySize:
            filtered.sort {
                if $0.memoryUsageBytes == $1.memoryUsageBytes {
                    return $0.key.lowercased() < $1.key.lowercased()
                }
                return $0.memoryUsageBytes > $1.memoryUsageBytes
            }
        }
        
        self.preferences = filtered
    }
    
    // MARK: - Actions
    
    public func deletePreference(key: String) {
        service.remove(forKey: key)
        // Auto-refresh is triggered via didChangeNotification
    }
    
    public func clearAll() {
        service.clearAll()
        // Auto-refresh is triggered via didChangeNotification
    }
    
    public func updatePreference(key: String, newValue: Any) {
        service.set(value: newValue, forKey: key)
    }
    
    // MARK: - Statistics (Nice to Have)
    
    public var totalCount: Int {
        return allPreferencesCache.count
    }
    
    public var totalMemoryUsageBytes: Int {
        return allPreferencesCache.reduce(0) { $0 + $1.memoryUsageBytes }
    }
    
    public var formattedMemoryUsage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(totalMemoryUsageBytes))
    }
    
    public var typeBreakdown: [String: Int] {
        var counts: [String: Int] = [:]
        for item in allPreferencesCache {
            counts[item.typeName, default: 0] += 1
        }
        return counts
    }
}
