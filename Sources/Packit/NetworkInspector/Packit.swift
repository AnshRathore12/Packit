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
     public static func log(_ message: String) {
         #if DEBUG
         NetworkStore.log(message)
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
     @State private var position = CGSize.zero
     @GestureState private var dragTranslation = CGSize.zero
     @State private var isDragging = false
     #endif
 
     public init() {}
 
     public func body(content: Content) -> some View {
         #if DEBUG
         ZStack(alignment: .bottomTrailing) {
             content
 
             Button {
                 if !isDragging {
                     showInspector = true
                 }
 
             } label: {
                 Image(systemName: "paperplane.fill")
                     .font(.system(size: 24))
                     .foregroundStyle(
                         Color.white
                     )
                     .frame(width: 55, height: 55)
                     .background(
                         LinearGradient(
                             stops: [
                                 .init(color: Color.black, location: 0.0),
                                 .init(color: Color(red: 0.10, green: 0.10, blue: 0.10), location: 0.35),
                                 .init(color: Color(red: 0.30, green: 0.30, blue: 0.30), location: 0.75),
                                 .init(color: Color(red: 0.42, green: 0.42, blue: 0.42), location: 1.0)
                             ],
                             startPoint: .bottomLeading,
                             endPoint: .topTrailing
                         )
                     )
                     .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                     .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                     .overlay(RoundedRectangle(cornerRadius: 16,style: .continuous).stroke( LinearGradient(
                         colors: [
                             Color.white.opacity(0.7),
                             Color.gray.opacity(0.4),
                             Color.black.opacity(0.8),
                             Color.gray.opacity(0.5)
                         ],
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing
                     ), lineWidth: 1.2))
             }
             .padding()
             .offset(
                 x: position.width + dragTranslation.width,
                 y: position.height + dragTranslation.height
             )
             .simultaneousGesture(
                 DragGesture(minimumDistance: 8)
                     .updating($dragTranslation) { value, state, _ in
                         state = value.translation
                         isDragging = true
                     }
                     .onEnded { value in
 //                        isDragging = false
                         position.width += value.translation.width
                         position.height += value.translation.height
                         DispatchQueue.main.async {
                                        isDragging = false
                         }
                     }
             )
             .sheet(isPresented: $showInspector) {
                 PackitDevToolsView()
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
