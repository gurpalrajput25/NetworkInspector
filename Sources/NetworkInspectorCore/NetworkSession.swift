import Foundation

public struct NetworkSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let startedAt: Date
    public var endedAt: Date?
    public var transactionCount: Int
    public var errorCount: Int

    public init(
        id: UUID = UUID(),
        name: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        transactionCount: Int = 0,
        errorCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transactionCount = transactionCount
        self.errorCount = errorCount
    }
}

