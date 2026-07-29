import SwiftUI

/// Full tabbed developer tools interface (Network + Storage inspectors).
///
/// Renders `EmptyView` in release builds — no debug UI will ever leak into production.
public struct DevToolsTabView: View {
    public init() {}
    
    public var body: some View {
        #if DEBUG
        NetworkInspectorView()
        #else
        EmptyView()
        #endif
    }
}

/// Container view for browsing on-device storage engines.
///
/// Renders `EmptyView` in release builds.
public struct StorageInspectorContainerView: View {
    public init() {}
    
    public var body: some View {
        #if DEBUG
        NavigationStack {
            List {
                Section("Storage Engines") {
                    NavigationLink(destination: PreferencesView(title: "UserDefaults", service: UserDefaultsService.shared)) {
                        Label("UserDefaults", systemImage: "tablecells.fill")
                    }
                    
                    NavigationLink(destination: PreferencesView(title: "Keychain", service: KeychainService())) {
                        Label("Keychain", systemImage: "lock.shield.fill")
                    }
                    
                    NavigationLink(destination: FileBrowserView(url: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!, title: "Cache")) {
                        Label("Cache", systemImage: "clock.arrow.circlepath")
                    }
                    
                    NavigationLink(destination: FileBrowserView(url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!, title: "Documents")) {
                        Label("Documents", systemImage: "folder.fill.badge.gearshape")
                    }
                    NavigationLink(destination: Text("Database Inspector (Coming Soon)")) {
                        Label("Database", systemImage: "cylinder.fill")
                    }
                    .disabled(true)
                }
            }
            .navigationTitle("Storage")
        }
        #else
        EmptyView()
        #endif
    }
}
