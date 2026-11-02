import Foundation
import NetworkInspectorCore

public enum URLSessionConfigurationFactory {

    public static func makeInspectable(configuration: URLSessionConfiguration) -> URLSessionConfiguration {
        let copy = configuration
        var protocols = copy.protocolClasses ?? []
        if !protocols.contains(where: { $0 == NetworkURLProtocol.self }) {
            protocols.insert(NetworkURLProtocol.self, at: 0)
        }
        copy.protocolClasses = protocols
        return copy
    }

    public static func defaultInspectable() -> URLSessionConfiguration {
        makeInspectable(configuration: .default)
    }

    public static func ephemeralInspectable() -> URLSessionConfiguration {
        makeInspectable(configuration: .ephemeral)
    }
}

public final class URLSessionCaptureAdapter: Sendable {
    public static let shared = URLSessionCaptureAdapter()

    public init() {}

    public func enableDefaultSessionCapture() {
        URLProtocol.registerClass(NetworkURLProtocol.self)
    }

    public func disableDefaultSessionCapture() {
        URLProtocol.unregisterClass(NetworkURLProtocol.self)
    }
}

public enum URLSessionMetricsCollector {
    public static func extractMetrics(from metrics: URLSessionTaskMetrics) -> NetworkTaskMetrics {
        NetworkTaskMetrics(urlSessionTaskMetrics: metrics)
    }
}
