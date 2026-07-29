import SwiftUI
import Foundation

/// Public wrapper for the Packit Network Inspector.
///
/// **Automatically disabled in release builds.**
/// All methods become safe no-ops when compiled without the DEBUG flag,
/// so you never need to wrap Packit calls in `#if DEBUG` yourself.
public struct Packit {
    
    /// Call this in your App's `init()` or `AppDelegate` to start intercepting ALL traffic.
    ///
    /// In release builds this is a complete no-op — no swizzling, no URLProtocol
    /// registration, and zero performance overhead.
    public static func startIntercepting() {
        #if DEBUG
        URLProtocol.registerClass(MyURLProtocol.self)
        swizzleURLSessionConfiguration()
        #endif
    }
    
    #if DEBUG
    private static func swizzleURLSessionConfiguration() {
        guard let defaultClass = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.default)),
              let swizzledDefault = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.swizzledDefaultSessionConfiguration)),
              let ephemeralClass = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeral)),
              let swizzledEphemeral = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.swizzledEphemeralSessionConfiguration)) else {
            return
        }
        
        method_exchangeImplementations(defaultClass, swizzledDefault)
        method_exchangeImplementations(ephemeralClass, swizzledEphemeral)
    }
    #endif
}

#if DEBUG
extension URLSessionConfiguration {
    @objc class func swizzledDefaultSessionConfiguration() -> URLSessionConfiguration {
        let config = swizzledDefaultSessionConfiguration() // Calls original default
        var protocols = config.protocolClasses ?? []
        protocols.insert(MyURLProtocol.self, at: 0)
        config.protocolClasses = protocols
        return config
    }
    
    @objc class func swizzledEphemeralSessionConfiguration() -> URLSessionConfiguration {
        let config = swizzledEphemeralSessionConfiguration() // Calls original ephemeral
        var protocols = config.protocolClasses ?? []
        protocols.insert(MyURLProtocol.self, at: 0)
        config.protocolClasses = protocols
        return config
    }
}
#endif

public struct NetworkInspectorOverlayModifier: ViewModifier {
    #if DEBUG
    @State private var showInspector = false
    @State private var dragOffset = CGSize.zero
    @State private var position = CGSize.zero
    #endif
    
    public init() {}
    
    public func body(content: Content) -> some View {
        #if DEBUG
        ZStack(alignment: .bottomTrailing) {
            content
            
            Button {
                showInspector = true
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
            }
            .padding()
            .offset(x: position.width + dragOffset.width, y: position.height + dragOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        position.width += value.translation.width
                        position.height += value.translation.height
                        dragOffset = .zero
                    }
            )
            .sheet(isPresented: $showInspector) {
                DevToolsTabView()
            }
        }
        #else
        content
        #endif
    }
}

public extension View {
    /// Adds a draggable floating button that opens the Packit inspector.
    ///
    /// In release builds this is a passthrough — your view is returned unmodified
    /// with zero overhead.
    func withNetworkInspectorOverlay() -> some View {
        self.modifier(NetworkInspectorOverlayModifier())
    }
}

/// Public wrapper view to display the Inspector.
///
/// Renders `EmptyView` in release builds.
public struct PackitView: View {
    public init() {}
    
    public var body: some View {
        #if DEBUG
        NetworkInspectorView()
        #else
        EmptyView()
        #endif
    }
}
