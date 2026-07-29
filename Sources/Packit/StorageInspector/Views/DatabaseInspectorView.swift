import SwiftUI

public struct DatabaseInspectorView: View {
    let url: URL
    @State private var tables: [SQLiteTable] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if tables.isEmpty {
                Text("No tables found in this database.")
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(tables) { table in
                        NavigationLink(destination: DatabaseTableView(url: url, tableName: table.name)) {
                            HStack {
                                Image(systemName: "tablecells")
                                    .foregroundColor(.blue)
                                Text(table.name)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("\(table.rowCount) rows")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTables()
        }
    }
    
    private func loadTables() {
        DispatchQueue.global(qos: .userInitiated).async {
            let service = SQLiteService(url: url)
            if service.open() {
                let fetchedTables = service.getTables()
                service.close()
                DispatchQueue.main.async {
                    self.tables = fetchedTables
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to open SQLite Database."
                    self.isLoading = false
                }
            }
        }
    }
}
