import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import NetworkInspectorUI

public enum NetworkInspectorLauncher {

    #if canImport(UIKit)
    @MainActor
    public static func present(from viewController: UIViewController? = nil) {
        guard let presenter = viewController ?? topViewController() else { return }

        // Avoid presenting if already presenting NetworkInspector
        if presenter is UIHostingController<NetworkInspectorView> ||
            presenter.presentedViewController is UIHostingController<NetworkInspectorView> {
            return
        }

        let inspectorView = NetworkInspectorView()
        let hostingController = UIHostingController(rootView: inspectorView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        presenter.present(hostingController, animated: true)
    }

    @MainActor
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
    #else
    public static func present() {}
    #endif
}

#if canImport(UIKit)
public extension NSNotification.Name {
    static let deviceDidShakeNotification = NSNotification.Name("com.networkinspector.deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShakeNotification, object: nil)
        }
    }
}
#endif

