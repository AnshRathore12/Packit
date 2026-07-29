import Foundation

public struct FileItem: Identifiable, Equatable {
    public let id: String
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let sizeInBytes: Int64
    public let modificationDate: Date
    
    public init(url: URL) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.sizeInBytes = attributes[.size] as? Int64 ?? 0
            self.modificationDate = attributes[.modificationDate] as? Date ?? Date()
        } catch {
            self.sizeInBytes = 0
            self.modificationDate = Date()
        }
    }
    
    public var formattedSize: String {
        if isDirectory {
            return "Folder"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
}
