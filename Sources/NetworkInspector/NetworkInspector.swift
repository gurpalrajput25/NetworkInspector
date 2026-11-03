import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorIntegrations
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

    /// Current authenticated user profile (auto-extracted from request headers or manually set).
    public static var currentUser: JWTUserDetails? {
        get { NetworkLogStore.shared.currentUser }
        set { NetworkLogStore.shared.setCurrentUser(newValue) }
    }

    /// Explicitly configure the currently logged-in user profile so diagnostic cards and Teams notifications reflect their details.
    public static func setLoggedInUser(
        name: String? = nil,
        email: String? = nil,
        userId: String? = nil,
        role: String? = nil,
        organizerId: String? = nil,
        rawPayload: [String: String] = [:]
    ) {
        let user = JWTUserDetails(
            userId: userId,
            email: email,
            name: name,
            role: role,
            organizerId: organizerId,
            rawPayload: rawPayload
        )
        NetworkLogStore.shared.setCurrentUser(user)
    }

    /// Sets the active user by decoding a live JWT bearer token directly.
    public static func setActiveJWT(_ jwt: String) {
        if let user = JWTDecoder.decode(jwt: jwt) {
            NetworkLogStore.shared.setCurrentUser(user)
        }
    }

    /// Clears the currently logged-in user upon logout.
    public static func clearCurrentUser() {
        NetworkLogStore.shared.clearCurrentUser()
    }

    /// Configures Microsoft Teams incoming webhook integration.
    public static func configureTeams(webhookURL: URL, environmentName: String = "Development") {
        TeamsIntegration.shared.configure(webhookURL: webhookURL, environmentName: environmentName)
    }

    /// Retained for backward compatibility.
    @available(*, deprecated, message: "Postman synchronization is deprecated in favor of native API standards & AI suggestions.")
    public static func configurePostman(apiKey: String, collectionUid: String, workspaceId: String) {
        TeamsIntegration.shared.configurePostman(apiKey: apiKey, collectionUid: collectionUid, workspaceId: workspaceId)
    }
}

