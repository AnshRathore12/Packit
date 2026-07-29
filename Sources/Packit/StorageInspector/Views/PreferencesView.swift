import SwiftUI

public struct PreferencesView: View {
    @StateObject private var store: PreferencesStore
    
    private let title: String
    
    @State private var showingAddAlert = false
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var showingClearConfirm = false
    @State private var showingAI = false
    
    public init(title: String, service: StorageProvider) {
        self.title = title
        self._store = StateObject(wrappedValue: PreferencesStore(service: service))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                HStack(spacing: 16) {
                    StatBox(title: "Total", value: "\(store.totalCount)")
                    StatBox(title: "Memory", value: store.formattedMemoryUsage)
                    
                    let typeStats = store.typeBreakdown.sorted { $0.value > $1.value }.prefix(2)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(typeStats, id: \.key) { stat in
                            Text("\(stat.key): \(stat.value)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground).shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 3))
                .zIndex(1)
                
                if store.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if store.preferences.isEmpty && store.searchQuery.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No Preferences Found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("UserDefaults is currently empty.")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                } else {
                    List {
                        if store.sortOption == .byType {
                            let grouped = Dictionary(grouping: store.preferences, by: { $0.typeName })
                            ForEach(grouped.keys.sorted(), id: \.self) { key in
                                Section(header: Text(key)) {
                                    ForEach(grouped[key]!) { item in
                                        PreferenceRow(item: item)
                                    }
                                }
                            }
                        } else {
                            ForEach(store.preferences) { item in
                                PreferenceRow(item: item)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color(UIColor.systemGroupedBackground))
                    .refreshable {
                        store.refresh()
                    }
                    .environmentObject(store)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.searchQuery, prompt: "Search Keys and Values...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAI = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            store.sortOption = .alphabetical
                        } label: {
                            Label("A → Z", systemImage: store.sortOption == .alphabetical ? "checkmark" : "")
                        }
                        
                        Button {
                            store.sortOption = .reverseAlphabetical
                        } label: {
                            Label("Z → A", systemImage: store.sortOption == .reverseAlphabetical ? "checkmark" : "")
                        }
                        
                        Button {
                            store.sortOption = .byType
                        } label: {
                            Label("Group by Type", systemImage: store.sortOption == .byType ? "checkmark" : "")
                        }
                        
                        Button {
                            store.sortOption = .bySize
                        } label: {
                            Label("Sort by Size (Largest)", systemImage: store.sortOption == .bySize ? "checkmark" : "")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingClearConfirm = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newKey = ""
                        newValue = ""
                        showingAddAlert = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .alert("Add Preference", isPresented: $showingAddAlert) {
                TextField("Key", text: $newKey)
                TextField("Value (String)", text: $newValue)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    if !newKey.isEmpty {
                        store.updatePreference(key: newKey, newValue: newValue)
                    }
                }
            } message: {
                Text("Enter a key and a string value to save in UserDefaults.")
            }
            .confirmationDialog("Clear All Preferences?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    store.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all UserDefaults data. This action cannot be undone.")
            }
            .sheet(isPresented: $showingAI) {
                AIAssistantView()
            }
        }
    }
}

fileprivate struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
