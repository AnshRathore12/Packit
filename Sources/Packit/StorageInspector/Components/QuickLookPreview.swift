import SwiftUI
import QuickLook

public struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(parent: QuickLookPreview) {
            self.parent = parent
        }
        
        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}
