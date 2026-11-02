import Foundation
import NetworkInspectorCore

public enum NetworkLogPersistence {
    private static var storageURL: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("NetworkInspector", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("transactions.json")
    }

    public static func save(transactions: [NetworkTransaction]) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(transactions)
                try data.write(to: storageURL, options: .atomic)
            } catch {
                // Fail silently in release
            }
        }
    }

    public static func load() -> [NetworkTransaction]? {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([NetworkTransaction].self, from: data)
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: storageURL)
    }
}

