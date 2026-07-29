import SwiftUI

public struct DatabaseTableView: View {
    let url: URL
    let tableName: String
    
    @State private var columns: [SQLiteColumn] = []
    @State private var rows: [SQLiteRow] = []
    @State private var isLoading = true
    
    public init(url: URL, tableName: String) {
        self.url = url
        self.tableName = tableName
    }
    
    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if rows.isEmpty {
                Text("Table is empty.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Row
                        HStack(spacing: 0) {
                            ForEach(columns) { col in
                                Text(col.name)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(minWidth: 120, alignment: .leading)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .border(Color(UIColor.separator), width: 0.5)
                            }
                        }
                        
                        // Data Rows
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                HStack(spacing: 0) {
                                    ForEach(columns) { col in
                                        Text(row.data[col.name] ?? "NULL")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(row.data[col.name] == "NULL" ? .gray : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(minWidth: 120, alignment: .leading)
                                            .border(Color(UIColor.separator), width: 0.5)
                                    }
                                }
                                .background(index % 2 == 0 ? Color.clear : Color(UIColor.systemGray6).opacity(0.3))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(tableName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let service = SQLiteService(url: url)
            if service.open() {
                let cols = service.getColumns(for: tableName)
                let dataRows = service.getRows(for: tableName, limit: 100)
                service.close()
                DispatchQueue.main.async {
                    self.columns = cols
                    self.rows = dataRows
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}
