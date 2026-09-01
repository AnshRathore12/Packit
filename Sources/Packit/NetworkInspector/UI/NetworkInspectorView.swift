//
//  ContentView.swift
//  NetworkInspector
//
//  Created by Ansh Rathore on 12/07/26.
//

import SwiftUI

struct NetworkInspectorView: View {
    @ObservedObject var store = NetworkStore.shared
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showingAnalytics = false
    @State private var showingAI = false
    @State private var isSearchPresented = false
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(store.customFilters, id: \.self) { filter in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                                    store.selectedFilter = filter
                                }
                            } label: {
                                Text(filter.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(store.selectedFilter == filter ? Color.blue.opacity(0.65) : Color(.systemGray5))
                                    .foregroundColor(store.selectedFilter == filter ? .white : .primary)
                                    .clipShape(Capsule())
                                    .shadow(color: store.selectedFilter == filter ? Color.blue.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground).shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 3))
                .zIndex(1)
                
                if !store.searchQuery.isEmpty && NLAssistantService.shared.parseQuery(store.searchQuery).hasNLIntents {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("Smart Search Active")
                            .font(.caption.bold())
                            .foregroundColor(.purple)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                let isListEmpty = store.isGroupedByHost ? store.groupedTransactions.isEmpty : store.combinedTimeline.isEmpty

                if isListEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No network traffic yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Make sure you're performing actions that trigger network requests.")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .transition(.opacity)
                } else {
                    List {
                        if store.isGroupedByHost {
                            ForEach(store.groupedTransactions, id: \.key) { group in
                                Section(header: Text(group.key).font(.subheadline.bold())) {
                                    ForEach(group.value) { transaction in
                                        TransactionRow(transaction: transaction, initialSearchText: store.searchQuery)
                                    }
                                }
                            }
                        } else {
                            ForEach(store.combinedTimeline) { item in
                                switch item {
                                case .transaction(let transaction):
                                    TransactionRow(transaction: transaction, initialSearchText: store.searchQuery)
                    case .log(let log):
                                    LogRow(log: log)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: store.isGroupedByHost ? store.groupedTransactions.count : store.combinedTimeline.count)
                }
            }
            .searchable(text: $store.searchQuery,/*isPresented: $isSearchPresented,*/ prompt: "Search URLs, or ask to find specific calls...")
            .navigationTitle("Network Traffic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
//                    Button {
//                        showingAI = true
//                    } label: {
//                        Image(systemName: "brain.head.profile")
//                            .foregroundColor(.purple)
//                    }
//                    Button {
//                        withAnimation { store.sortAscending.toggle() }
//                    } label: {
//                        Image(systemName: store.sortAscending ? "arrow.up.arrow.down.circle.fill" : "arrow.down.arrow.up.circle.fill")
//                            .foregroundColor(.blue)
//                    }
                    
                    Button {
                        withAnimation { store.clearSession() }
                    } label: {
                        Image(systemName: "trash.circle.fill")
//                            .foregroundColor(.red)
                    }
//                    Button("") {
//                               print("⌘⇧F fired")
//                               isSearchPresented = true
//                           }
//                           .keyboardShortcut(
//                               "f",
//                               modifiers: [.command, .shift]
//                           ).hidden()
                    
                    // Analytics button removed
                    
//                    Button {
//                        if let url = store.exportToJSON() {
//                            ShareSheet.present(items: [url])
//                        }
//                    } label: {
//                        Image(systemName: "arrow.up.doc.fill")
//                            .foregroundColor(.purple)
//                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Toggle(isOn: $store.isGroupedByHost) {
                        Image(systemName: "rectangle.3.group.fill")
                            .foregroundColor(store.isGroupedByHost ? .teal.opacity(0.65) : .gray)
                    }
                    .toggleStyle(.button)
                    .tint(.clear)
                }
            }
//            .sheet(isPresented: $showingAI) {
////                AIAssistantView()
//            }
        }
    }
}

struct TransactionRow: View {
    let transaction: NetworkTransaction
    var initialSearchText: String = ""
    @Environment(\.colorScheme) var colorScheme
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: transaction.startTime)
    }

    private var payloadSizeString: String? {
        guard let count = transaction.data?.count, count > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .binary)
    }

    private var contentTypeLabel: String {
        if let mime = transaction.response?.mimeType?.lowercased() {
            if mime.contains("json") { return "JSON" }
            if mime.contains("image") { return "IMG" }
            if mime.contains("html") { return "HTML" }
            if mime.contains("text") { return "TXT" }
        }
        if transaction.operationType.uppercased() == "QUERY" || transaction.operationType.uppercased() == "MUTATION" {
            return "GQL"
        }
        return "REST"
    }

    var body: some View {
        ZStack {
            // Invisible NavigationLink to hide the native system chevron
            NavigationLink(destination: TransactionDetailsView(transaction: transaction, initialSearchText: initialSearchText)) {
                EmptyView()
            }
            .opacity(0)
            
            // Modernized Card UI
            HStack(spacing: 0) {
                // Left Vertical Status Accent Bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(statusColor)
                    .frame(width: 3)
                    .padding(.vertical, 0)
                    .padding(.leading, 0)

                VStack(alignment: .leading, spacing: 7) {
                    // Top Row: Method, Status, Duration & Size
                    HStack(alignment: .center, spacing: 6) {
                        // Method Badge
                        Text(transaction.operationType.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(methodColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(methodColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                        // Status Badge
                        if let response = transaction.response as? HTTPURLResponse {
                            HStack(spacing: 3) {
                                Image(systemName: (200...299).contains(response.statusCode) ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 9))
                                Text("\(response.statusCode)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(statusColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }

                        if transaction.isCacheHit {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8))
                                Text("Cached")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                        }

                        Spacer()

                        // Duration & Payload Size
                        HStack(spacing: 6) {
                            if let size = payloadSizeString {
                                Text(size)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            if let duration = transaction.duration {
                                let ms = Int(duration * 1000)
                                Text("\(ms)ms")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(ms < 300 ? .secondary : (ms < 800 ? .orange : .red))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(UIColor.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            } else if transaction.error != nil {
                                Text("Failed")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                        }
                    }

                    // Middle Row: Endpoint Category Name
                    HighlightedText(
                        text: transaction.categoryName,
                        query: initialSearchText,
                        font: .system(size: 14, weight: .semibold),
                        textColor: .primary
                    )
                    .lineLimit(1)

                    // Bottom Row: Host + Path and Metadata
                    HStack(alignment: .center, spacing: 6) {
                        let hostAndPath = (transaction.request.url?.host ?? "") + transaction.path
                        HighlightedText(
                            text: hostAndPath,
                            query: initialSearchText,
                            font: .system(size: 12, design: .monospaced),
                            textColor: .secondary
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)

                        Spacer()

                        // Content Type Tag
                        Text(contentTypeLabel)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        // Time
                        Text(formattedTime)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)

                // Trailing Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
//                    .foregroundColor(Color(UIColor.quaternaryLabel))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .padding(.trailing, 12)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
//            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
//                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: colorScheme == .light ? Color.black.opacity(0.03) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(BouncyButtonStyle())
        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                NetworkStore.shared.deleteTransaction(id: transaction.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                UIPasteboard.general.string = transaction.cURLString
            } label: {
                Label("Copy cURL", systemImage: "doc.on.doc")
            }
            .tint(.blue)
            
//            Button {
//                NetworkStore.shared.retryTransaction(transaction)
//            } label: {
//                Label("Retry", systemImage: "arrow.clockwise")
//            }
//            .tint(.green)
        }
    }
    
    private var methodColor: Color {
        switch transaction.operationType.uppercased() {
        case "GET", "QUERY": return .blue
        case "POST", "MUTATION": return .teal
        case "PUT": return .brown
        case "DELETE": return .mint
        case "PATCH": return .pink
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        if transaction.error != nil { return .red }
        guard let response = transaction.response as? HTTPURLResponse else { return .gray }
        switch response.statusCode {
        case 200...299: return .green.opacity(0.8)
        case 300...399: return .blue.opacity(0.8)
        case 400...499: return .red.opacity(0.8)
        case 500...599: return .orange.opacity(0.8)
        default: return .gray.opacity(0.8)
        }
    }
}

struct LogRow: View {
    let log: LogEntry
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: log.timestamp)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("LOG")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(width: 40, alignment: .leading)
                    .padding(.bottom, 4)
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
            }.padding(.leading, 8)
           
            
            Text(log.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)

        
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round, miterLimit: 0, dash: [6,4], dashPhase: 0)))

    }
}

#Preview {
    NetworkInspectorView()
    LogRow(log: .init(message: "Hello World ", timestamp: .init()))
}

