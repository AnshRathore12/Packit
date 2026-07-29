import SwiftUI

public struct PreferenceRow: View {
    public let item: PreferenceItem
    
    @EnvironmentObject var store: PreferencesStore
    @State private var isRevealed: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    public init(item: PreferenceItem) {
        self.item = item
    }
    
    public var body: some View {
        ZStack {
            NavigationLink(destination: PreferenceDetailView(item: item)) {
                EmptyView()
            }
            .opacity(0)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.key)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Text("\(item.memoryUsageBytes) B")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .center, spacing: 8) {
                    Text(item.typeName.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(typeColor(for: item.typeName))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor(for: item.typeName).opacity(0.15))
                        .clipShape(Capsule())
                    
                    if item.isSensitive && !isRevealed {
                        Text(String(repeating: "*", count: min(32, max(8, item.stringRepresentation.count))))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(item.stringRepresentation)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(item.isSensitive ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    Spacer()
                    
                    if item.isSensitive {
                        Button {
                            withAnimation { isRevealed.toggle() }
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: colorScheme == .light ? Color.black.opacity(0.04) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contextMenu {
            Button {
                UIPasteboard.general.string = item.key
            } label: {
                Label("Copy Key", systemImage: "doc.on.doc")
            }
            
            Button {
                UIPasteboard.general.string = item.stringRepresentation
            } label: {
                Label("Copy Value", systemImage: "doc.on.clipboard")
            }
            
            Button {
                let textToShare = "\(item.key): \(item.stringRepresentation)"
                ShareSheet.present(items: [textToShare])
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive) {
                store.deletePreference(key: item.key)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                store.deletePreference(key: item.key)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                UIPasteboard.general.string = item.stringRepresentation
            } label: {
                Label("Copy Value", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
    }
    
    private func typeColor(for typeName: String) -> Color {
        switch typeName {
        case "String": return .blue
        case "Bool": return .green
        case "Int", "Double", "Float": return .orange
        case "Data": return .purple
        case "Array", "Dictionary": return .pink
        case "Date": return .cyan
        default: return .gray
        }
    }
}
