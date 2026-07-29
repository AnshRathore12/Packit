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
                                    .background(store.selectedFilter == filter ? Color.blue : Color(.systemGray6))
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
                
                if store.combinedTimeline.isEmpty {
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
                                    TransactionRow(transaction: transaction)
                                }
                            }
                        }
                    } else {
                        ForEach(store.combinedTimeline) { item in
                            switch item {
                            case .transaction(let transaction):
                                TransactionRow(transaction: transaction)
                            case .log(let log):
                                LogRow(log: log)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: store.combinedTimeline.count)
                }
            }
            .searchable(text: $store.searchQuery, prompt: "Search URLs, or ask to find specific calls...")
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
                            .foregroundColor(store.isGroupedByHost ? .blue : .gray)
                    }
                    .toggleStyle(.button)
                    .tint(.clear)
                }
            }
            .sheet(isPresented: $showingAI) {
                AIAssistantView()
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: NetworkTransaction
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Invisible NavigationLink to hide the native system chevron
            NavigationLink(destination: TransactionDetailsView(transaction: transaction)) {
                EmptyView()
            }
            .opacity(0)
            
            // Custom Card UI
            HStack(alignment: .center, spacing: 12) {
                // Leading Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    // First Line: Title and Response Time
                    HStack(alignment: .firstTextBaseline) {
                        Text(transaction.categoryName)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let duration = transaction.duration {
                            let ms = Int(duration * 1000)
                            Text("\(ms) ms")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(ms < 300 ? .secondary : (ms < 800 ? .orange : .red))
                        } else if transaction.error != nil {
                            Text("Failed")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                        } else {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                    
                    // Second Line: Badges and URL
                    HStack(alignment: .center, spacing: 8) {
                        // HTTP Method Badge
                        Text(transaction.operationType.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(methodColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(methodColor.opacity(0.15))
                            .clipShape(Capsule())
                        
                        // Status Code Badge
                        if let response = transaction.response as? HTTPURLResponse {
                            Text("\(response.statusCode)")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(statusColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        
                        // URL Path (truncated middle)
                        let hostAndPath = (transaction.request.url?.host ?? "") + transaction.path
                        Text(hostAndPath)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Trailing Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: colorScheme == .light ? Color.black.opacity(0.04) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(BouncyButtonStyle())
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
        case "POST", "MUTATION": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        case "PATCH": return .purple
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        if transaction.error != nil { return .red }
        guard let response = transaction.response as? HTTPURLResponse else { return .gray }
        switch response.statusCode {
        case 200...299: return .green
        case 300...399: return .orange
        case 400...499: return .yellow
        case 500...599: return .red
        default: return .gray
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
            Text(formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text("LOG")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .leading)
            
            Text(log.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.05))
    }
}

#Preview {
    NetworkInspectorView()
}

