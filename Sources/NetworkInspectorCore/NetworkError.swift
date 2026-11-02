import Foundation

public struct NetworkError: Codable, Sendable, Equatable {
    public let domain: String
    public let code: Int
    public let localizedDescription: String
    public let failureReason: String?

    public init(
        domain: String,
        code: Int,
        localizedDescription: String,
        failureReason: String? = nil
    ) {
        self.domain = domain
        self.code = code
        self.localizedDescription = localizedDescription
        self.failureReason = failureReason
    }

    public init(error: Error) {
        let nsError = error as NSError
        self.domain = nsError.domain
        self.code = nsError.code
        self.localizedDescription = nsError.localizedDescription
        self.failureReason = nsError.localizedFailureReason
    }
}

