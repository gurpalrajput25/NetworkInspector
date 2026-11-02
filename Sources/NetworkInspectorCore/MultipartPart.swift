import Foundation

public struct MultipartPart: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let filename: String?
    public let mimeType: String?
    public let size: Int64
    public let isFile: Bool
    public let previewContent: String?
    public let headers: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        filename: String? = nil,
        mimeType: String? = nil,
        size: Int64 = 0,
        isFile: Bool = false,
        previewContent: String? = nil,
        headers: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.isFile = isFile
        self.previewContent = previewContent
        self.headers = headers
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

