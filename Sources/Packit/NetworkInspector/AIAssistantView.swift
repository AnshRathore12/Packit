import SwiftUI

public struct AIAssistantView: View {
    @StateObject private var assistant = DevToolsAIAssistant.shared
    @State private var inputText: String = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Extracted navigation state to prevent SwiftUI loops
    @State private var selectedTransaction: NetworkTransaction?
    @State private var selectedPreference: PreferenceItem?
    @State private var activeSearchQuery: String = ""
    @State private var showTransaction: Bool = false
    @State private var showPreference: Bool = false
    
    private let suggestedQuestions = [
        "Show me all failed requests",
        "Which API is the slowest?",
        "Am I leaking any auth tokens?",
        "Is member_data containing member_id?",
        "Where am I getting location data?",
        "What is stored in the keychain?",
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Availability banner
                if !assistant.isAvailable, !assistant.availabilityMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(assistant.availabilityMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if assistant.messages.isEmpty { welcomeView }
                            
                            ForEach(assistant.messages) { message in
                                MessageBubble(message: message) { item in
                                    activeSearchQuery = item.searchQuery ?? ""
                                    switch item.type {
                                    case .networkTransaction(let tx): 
                                        selectedTransaction = tx
                                        showTransaction = true
                                    case .userDefaultsKey(let pref), .keychainItem(let pref): 
                                        selectedPreference = pref
                                        showPreference = true
                                    }
                                }
                                .id(message.id)
                            }
                            
                            if assistant.isThinking {
                                if assistant.streamingResponse.isEmpty {
                                    ThinkingIndicator()
                                } else {
                                    StreamingBubble(text: assistant.streamingResponse)
                                }
                            }
                            
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: assistant.messages.count) { _ in
                        withAnimation { proxy.scrollTo("bottom") }
                    }
                    .onChange(of: assistant.streamingResponse) { _ in
                        proxy.scrollTo("bottom")
                    }
                }
                
                Divider()
                inputBar
            }
            .navigationTitle("DevTools AI ✨")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !assistant.messages.isEmpty {
                        Button { withAnimation { assistant.clearHistory() } } label: {
                            Image(systemName: "trash.circle.fill").foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
            }
            .navigationDestination(isPresented: $showTransaction) {
                if let tx = selectedTransaction {
                    TransactionDetailsView(transaction: tx, initialSearchText: activeSearchQuery)
                }
            }
            .navigationDestination(isPresented: $showPreference) {
                if let pref = selectedPreference {
                    PreferenceDetailView(item: pref, initialSearchText: activeSearchQuery)
                        .environmentObject(PreferencesStore(service: UserDefaultsService()))
                }
            }
        }
    }
    
    // MARK: - Welcome
    private var welcomeView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "wand.and.stars.inverse")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("DevTools AI").font(.headline)
                    Text("Tap a question or type your own").font(.caption).foregroundColor(.secondary)
                }
            }
            
            Text("Suggested Questions")
                .font(.caption.bold()).foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        inputText = question
                        sendMessage()
                    } label: {
                        Text(question)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.leading)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Input bar
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your app data...", text: $inputText, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .onSubmit { sendMessage() }
            
            Button { sendMessage() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let msg = inputText
        inputText = ""
        Task { await assistant.send(msg) }
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: AIMessage
    var onTapCard: ((AIActionableItem) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.role == .user { Spacer(minLength: 60) }
                
                if message.role == .assistant {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                        Image(systemName: "wand.and.stars.inverse")
                            .foregroundColor(.white)
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.role == .user ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(18)
                        .textSelection(.enabled)
                    
                    Text(formattedTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                if message.role == .assistant { Spacer(minLength: 60) }
            }
            
            // Deep-link cards
            if !message.actionableItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(message.actionableItems) { item in
                        ActionableItemCard(item: item) {
                            onTapCard?(item)
                        }
                    }
                }
                .padding(.leading, 36) // align with bubble
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Actionable Item Card
private struct ActionableItemCard: View {
    let item: AIActionableItem
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        } label: {
            HStack(spacing: 10) {
                // Badge
                Text(item.badge)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15))
                    .clipShape(Capsule())
                
                // Title + Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(badgeColor.opacity(0.7))
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(badgeColor.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(BouncyButtonStyle())
    }
    
    private var badgeColor: Color {
        switch item.badgeColor {
        case .blue:   return .blue
        case .green:  return .green
        case .red:    return .red
        case .orange: return .orange
        case .purple: return .purple
        case .gray:   return .gray
        }
    }
}

// MARK: - Thinking Indicator
private struct ThinkingIndicator: View {
    @State private var animating = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .onAppear { animating = true }
    }
}

// MARK: - Streaming Bubble
private struct StreamingBubble: View {
    let text: String
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: "wand.and.stars.inverse").foregroundColor(.white).font(.system(size: 11, weight: .bold))
            }
            Text(text + "▌")
                .font(.system(size: 15)).foregroundColor(.primary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(18)
            Spacer(minLength: 60)
        }
    }
}
