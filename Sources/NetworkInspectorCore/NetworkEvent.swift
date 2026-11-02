import Foundation

public enum NetworkEvent: Sendable {
    case transactionStarted(NetworkTransaction)
    case transactionUpdated(NetworkTransaction)
    case transactionCompleted(NetworkTransaction)
    case transactionFailed(NetworkTransaction, NetworkError)
    case transactionCancelled(NetworkTransaction)
    case logsCleared
    case sessionStarted(NetworkSession)
}

public protocol NetworkEventObserver: AnyObject, Sendable {
    func onNetworkEvent(_ event: NetworkEvent)
}

