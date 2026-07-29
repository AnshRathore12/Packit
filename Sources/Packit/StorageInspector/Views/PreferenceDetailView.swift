import SwiftUI

public struct PreferenceDetailView: View {
    public let item: PreferenceItem
    public let initialSearchText: String?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: PreferencesStore
    @State private var isRevealed: Bool = false
    @State private var searchText: String = ""
    
    public init(item: PreferenceItem, initialSearchText: String? = nil) {
        self.item = item
        self.initialSearchText = initialSearchText
    }
    
    public var body: some View {
        List {
            Section {
                HStack {
                    Text("Key")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.key)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                HStack {
                    Text("Type")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.typeName)
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack {
                    Text("Size")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(item.memoryUsageBytes) bytes")
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("Metadata")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        if item.isSensitive {
                            Button {
                                withAnimation {
                                    isRevealed.toggle()
                                }
                            } label: {
                                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    
                    if item.isSensitive && !isRevealed {
                        Text(String(repeating: "*", count: min(32, max(8, item.stringRepresentation.count))))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text(item.stringRepresentation)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Value")
            }
            
            if let data = item.value as? Data {
                if let previewStr = parseDataPreview(data) {
                    Section {
                        NavigationLink("Preview Data Content") {
                            ScrollView {
                                JSONViewer(jsonString: previewStr, searchText: searchText.isEmpty ? (initialSearchText ?? "") : searchText)
                                    .padding()
                            }
                            .navigationTitle("Data Content")
                            .navigationBarTitleDisplayMode(.inline)
                        }
                    } header: {
                        Text("Data Preview")
                    }
                }
            } else if item.typeName == "Dictionary" || item.typeName == "Array" {
                Section {
                    let previewStr: String = {
                        if JSONSerialization.isValidJSONObject(item.value),
                           let json = try? JSONSerialization.data(withJSONObject: item.value, options: .prettyPrinted),
                           let str = String(data: json, encoding: .utf8) {
                            return str
                        } else {
                            return String(describing: item.value)
                        }
                    }()
                    
                    NavigationLink("Preview Collection Content") {
                        ScrollView {
                            JSONViewer(jsonString: previewStr, searchText: searchText.isEmpty ? (initialSearchText ?? "") : searchText)
                                .padding()
                        }
                        .navigationTitle("Collection Content")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                } header: {
                    Text("Collection Preview")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search content...")
        .onAppear {
            // initialSearchText is passed directly to JSONViewer instead of filling the UI search bar
        }
        .navigationTitle(item.key)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        let text = "\(item.key):\n\(item.stringRepresentation)"
                        ShareSheet.present(items: [text])
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
            }
        }
    }
    
    private func parseDataPreview(_ data: Data) -> String? {
        // 1. Try to parse as JSON or UTF8 String
        if let str = String(data: data, encoding: .utf8), !str.isEmpty {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyStr = String(data: pretty, encoding: .utf8) {
                return prettyStr
            }
            return str
        }
        
        // 2. Try to parse as Binary Property List
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            return String(describing: plist)
        }
        
        // 3. Try NSKeyedUnarchiver for custom objects
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            if let obj = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) {
                return String(describing: obj)
            }
        } catch { }
        
        // 4. Try generic object unarchiving (less strict)
        do {
            if let obj = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) {
                return String(describing: obj)
            }
        } catch { }
        
        return nil
    }
}
