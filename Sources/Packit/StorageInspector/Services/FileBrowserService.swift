import Foundation

public class FileBrowserService {
    public static let shared = FileBrowserService()
    
    private init() {}
    
    public func contentsOfDirectory(at url: URL) -> [FileItem] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            return fileURLs
                .filter { url in
                    let name = url.lastPathComponent
                    if name == "Snapshots" || name == "WebKit" || name == "SplashBoard" || name.hasPrefix("com.apple.") {
                        return false
                    }
                    return true
                }
                .map { FileItem(url: $0) }
                .sorted {
                    if $0.isDirectory && !$1.isDirectory { return true }
                    if !$0.isDirectory && $1.isDirectory { return false }
                    return $0.name.lowercased() < $1.name.lowercased()
                }
        } catch {
            print("Failed to read directory: \(error)")
            return []
        }
    }
    
    public func delete(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to delete file: \(error)")
        }
    }
}
