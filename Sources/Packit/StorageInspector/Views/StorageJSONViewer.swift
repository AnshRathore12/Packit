import SwiftUI

public struct StorageJSONViewer: View {
    let url: URL
    @State private var jsonString: String = ""
    @State private var isLoading = true
    @State private var searchText = ""
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if jsonString.isEmpty {
                Text("Failed to read file or file is empty.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    JSONViewer(jsonString: jsonString, searchText: searchText)
                        .padding()
                }
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search JSON...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    ShareSheet.present(items: [url])
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.jsonString = content
                        self.isLoading = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
