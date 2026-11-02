import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorURLSession
import NetworkInspectorUI

public enum NetworkInspector {

    /// Initializes and starts the Network Inspector SDK with the given configuration.
    public static func start(configuration: NetworkInspectorConfiguration = .development) {
        NetworkInspectorManager.shared.start(configuration: configuration)
    }

    /// Stops the Network Inspector SDK and unregisters network interception.
    public static func stop() {
        NetworkInspectorManager.shared.stop()
    }

    /// Returns a URLSessionConfiguration configured with NetworkInspector capture capabilities.
    public static func urlSessionConfiguration(
        from configuration: URLSessionConfiguration = .default
    ) -> URLSessionConfiguration {
        URLSessionConfigurationFactory.makeInspectable(configuration: configuration)
    }

    /// Presents the full SwiftUI Network Inspector modal dashboard on the key window.
    #if canImport(UIKit)
    @MainActor
    public static func present(from viewController: UIViewController? = nil) {
        NetworkInspectorLauncher.present(from: viewController)
    }
    #else
    public static func present() {}
    #endif

    /// Returns the standalone SwiftUI view for embedding directly in your app.
    public static func makeInspectorView() -> some View {
        NetworkInspectorView()
    }

    /// Clears all captured transactions and resets the in-memory log buffer.
    public static func clearLogs() {
        NetworkLogStore.shared.clearAll()
    }

    /// Starts a new logical session for grouping upcoming network transactions.
    public static func startNewSession(name: String? = nil) {
        NetworkLogStore.shared.startNewSession(name: name)
    }

    /// Access the shared reactive log store for custom UI binding.
    public static var logStore: NetworkLogStore {
        NetworkLogStore.shared
    }
}

