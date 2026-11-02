import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct DeviceDiagnosticInfo: Codable, Sendable {
    public let deviceModel: String
    public let systemName: String
    public let systemVersion: String
    public let appName: String
    public let appVersion: String
    public let buildNumber: String
    public let locale: String
    public let timeZone: String

    public init(
        deviceModel: String = DeviceDiagnosticInfo.resolveDeviceModel(),
        systemName: String = DeviceDiagnosticInfo.resolveSystemName(),
        systemVersion: String = DeviceDiagnosticInfo.resolveSystemVersion(),
        appName: String = DeviceDiagnosticInfo.resolveAppName(),
        appVersion: String = DeviceDiagnosticInfo.resolveAppVersion(),
        buildNumber: String = DeviceDiagnosticInfo.resolveBuildNumber(),
        locale: String = Locale.current.identifier,
        timeZone: String = TimeZone.current.identifier
    ) {
        self.deviceModel = deviceModel
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.locale = locale
        self.timeZone = timeZone
    }

    public static func current() -> DeviceDiagnosticInfo {
        DeviceDiagnosticInfo(
            deviceModel: resolveDeviceModel(),
            systemName: resolveSystemName(),
            systemVersion: resolveSystemVersion(),
            appName: resolveAppName(),
            appVersion: resolveAppVersion(),
            buildNumber: resolveBuildNumber(),
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier
        )
    }

    public static func resolveDeviceModel() -> String {
        #if canImport(UIKit)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
        #else
        return "Mac"
        #endif
    }

    public static func resolveSystemName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.systemName
        #else
        return "macOS"
        #endif
    }

    public static func resolveSystemVersion() -> String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    public static func resolveAppName() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "HostApp"
    }

    public static func resolveAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    public static func resolveBuildNumber() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
