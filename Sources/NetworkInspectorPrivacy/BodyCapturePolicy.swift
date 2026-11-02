import Foundation

public enum BodyCapturePolicy: Sendable, Equatable {
    case full
    case metadataOnly
    case disabled
    case sizeLimit(Int)

    public func allowsBodyCapture(size: Int) -> Bool {
        switch self {
        case .full:
            return true
        case .metadataOnly, .disabled:
            return false
        case .sizeLimit(let limit):
            return size <= limit
        }
    }
}

