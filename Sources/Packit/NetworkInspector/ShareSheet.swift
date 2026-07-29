import SwiftUI
import UIKit

struct ShareSheet {
    static func present(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else { return }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Handle iPad popover constraints
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Find top most view controller
        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        topController.present(activityVC, animated: true)
    }
}
