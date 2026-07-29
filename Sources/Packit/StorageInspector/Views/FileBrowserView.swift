import SwiftUI

public struct FileBrowserView: View {
    public let currentURL: URL
    public let title: String
    
    @State private var items: [FileItem] = []
    @State private var searchQuery = ""
    @State private var previewURL: URL? = nil
    
    public init(url: URL, title: String? = nil) {
        self.currentURL = url
        self.title = title ?? url.lastPathComponent
    }
    
    private var filteredItems: [FileItem] {
        if searchQuery.isEmpty {
            return items
        }
        return items.filter { $0.name.lowercased().contains(searchQuery.lowercased()) }
    }
    
    public var body: some View {
        List {
            if items.isEmpty {
                Text("Directory is empty")
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredItems) { item in
                    if item.isDirectory {
                        NavigationLink(destination: FileBrowserView(url: item.url)) {
                            FileRow(item: item)
                        }
                    } else if item.name.lowercased().hasSuffix(".json") {
                        NavigationLink(destination: StorageJSONViewer(url: item.url)) {
                            FileRow(item: item)
                        }
                    } else if item.name.lowercased().hasSuffix(".db") || item.name.lowercased().hasSuffix(".sqlite") {
                        NavigationLink(destination: DatabaseInspectorView(url: item.url)) {
                            FileRow(item: item)
                        }
                    } else {
                        // For other files, tap to open QuickLook Preview
                        FileRow(item: item)
                            .onTapGesture {
                                handleFileTap(item.url)
                            }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let item = filteredItems[index]
                        FileBrowserService.shared.delete(url: item.url)
                    }
                    refresh()
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "Search files...")
        .onAppear {
            refresh()
        }
        .refreshable {
            refresh()
        }
        .sheet(item: Binding(
            get: { previewURL.map { IdentifiableURL(url: $0) } },
            set: { previewURL = $0?.url }
        )) { ident in
            QuickLookPreview(url: ident.url)
                .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func handleFileTap(_ url: URL) {
        if url.pathExtension.isEmpty {
            // Check if it's an image (like Kingfisher caches)
            if let _ = UIImage(contentsOfFile: url.path) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent + ".jpg")
                try? FileManager.default.removeItem(at: tempURL)
                if (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil {
                    previewURL = tempURL
                    return
                }
            }
        }
        previewURL = url
    }
    
    private func refresh() {
        items = FileBrowserService.shared.contentsOfDirectory(at: currentURL)
    }
}

fileprivate struct FileRow: View {
    let item: FileItem
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncFileIcon(url: item.url, isDirectory: item.isDirectory, fallbackIcon: iconForFile(item.name))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack {
                    Text(item.formattedDate)
                    Spacer()
                    Text(item.formattedSize)
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForFile(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.hasSuffix(".db") || lower.hasSuffix(".sqlite") || lower.hasSuffix(".db-shm") || lower.hasSuffix(".db-wal") {
            return "cylinder.split.1x2.fill"
        } else if lower.hasSuffix(".json") {
            return "curlybraces"
        } else if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".gif") {
            return "photo.fill"
        } else if lower.hasSuffix(".pdf") || lower.hasSuffix(".txt") {
            return "doc.text.fill"
        } else if lower.hasSuffix(".zip") || lower.hasSuffix(".tar") {
            return "doc.zipper"
        } else {
            return "doc.fill"
        }
    }
}

fileprivate struct AsyncFileIcon: View {
    let url: URL
    let isDirectory: Bool
    let fallbackIcon: String
    
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: isDirectory ? "folder.fill" : fallbackIcon)
                    .foregroundColor(isDirectory ? .blue : .gray)
                    .font(.system(size: 24))
                    .frame(width: 30)
            }
        }
        .onAppear {
            if !isDirectory {
                let lower = url.lastPathComponent.lowercased()
                let isImageExt = lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".gif") || lower.hasSuffix(".webp")
                let hasNoExt = url.pathExtension.isEmpty
                
                if isImageExt || hasNoExt {
                    loadThumbnail()
                }
            }
        }
    }
    
    private func loadThumbnail() {
        Task.detached(priority: .background) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 100
            ]
            
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return
            }
            
            let thumbnail = UIImage(cgImage: cgImage)
            await MainActor.run {
                self.image = thumbnail
            }
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
