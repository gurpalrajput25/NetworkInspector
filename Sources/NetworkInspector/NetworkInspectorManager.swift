import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorPrivacy
import NetworkInspectorIntegrations
import NetworkInspectorURLSession
import NetworkInspectorUI

public final class NetworkInspectorManager: @unchecked Sendable {
    public static let shared = NetworkInspectorManager()

    public private(set) var configuration: NetworkInspectorConfiguration = .development
    private var isStarted = false
    private let lock = NSLock()

    private init() {}

    public func start(configuration: NetworkInspectorConfiguration = .development) {
        lock.lock()
        defer { lock.unlock() }

        guard !isStarted else { return }
        self.configuration = configuration
        self.isStarted = true

        guard configuration.isEnabled else { return }

        // Configure storage
        NetworkLogStore.shared.configure(
            maxLogCount: configuration.maxLogCount,
            enablePersistence: configuration.enablePersistence,
            privacyConfig: configuration.privacy
        )

        // Configure Teams
        if let webhook = configuration.teamsWebhookURL {
            TeamsIntegration.shared.configure(
                webhookURL: webhook,
                environmentName: configuration.environmentName
            )
        }

        // Register default URLSession capture
        URLSessionCaptureAdapter.shared.enableDefaultSessionCapture()

        // Setup Shake Gesture Listener
        #if canImport(UIKit)
        if configuration.isShakeToOpenEnabled {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleShakeNotification),
                name: .deviceDidShakeNotification,
                object: nil
            )
        }
        #endif
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        URLSessionCaptureAdapter.shared.disableDefaultSessionCapture()
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: .deviceDidShakeNotification, object: nil)
        #endif
        self.isStarted = false
    }

    #if canImport(UIKit)
    @objc private func handleShakeNotification() {
        guard configuration.isShakeToOpenEnabled else { return }
        DispatchQueue.main.async {
            NetworkInspectorLauncher.present()
        }
    }
    #endif
}

