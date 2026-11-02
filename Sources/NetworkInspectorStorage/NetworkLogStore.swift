import Foundation
import Combine
import NetworkInspectorCore
import NetworkInspectorPrivacy

public final class NetworkLogStore: ObservableObject, @unchecked Sendable {
    public static let shared = NetworkLogStore()

    @Published public private(set) var transactions: [NetworkTransaction] = []
    @Published public private(set) var sessions: [NetworkSession] = []
    @Published public private(set) var activeSession: NetworkSession
    @Published public var currentUser: JWTUserDetails?

    private let lock = NSRecursiveLock()
    private var maxLogCount: Int = 1000
    private var isPersistenceEnabled: Bool = false
    private let redactor: SensitiveDataRedactor

    public init(
        maxLogCount: Int = 1000,
        enablePersistence: Bool = false,
        privacyConfig: NetworkPrivacyConfiguration = .default
    ) {
        self.maxLogCount = maxLogCount
        self.isPersistenceEnabled = enablePersistence
        self.redactor = SensitiveDataRedactor(configuration: privacyConfig)

        let initialSession = NetworkSession(name: "Session 1")
        self.activeSession = initialSession
        self.sessions = [initialSession]

        if enablePersistence {
            loadPersistedData()
        }
    }

    public func configure(maxLogCount: Int, enablePersistence: Bool, privacyConfig: NetworkPrivacyConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        self.maxLogCount = maxLogCount
        self.isPersistenceEnabled = enablePersistence
    }

    public func setCurrentUser(_ user: JWTUserDetails?) {
        lock.lock()
        defer { lock.unlock() }
        self.currentUser = user
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func clearCurrentUser() {
        setCurrentUser(nil)
    }

    public func startNewSession(name: String? = nil) {
        lock.lock()
        defer { lock.unlock() }

        var current = activeSession
        current.endedAt = Date()
        if let idx = sessions.firstIndex(where: { $0.id == current.id }) {
            sessions[idx] = current
        }

        let sessionName = name ?? "Session \(sessions.count + 1)"
        let newSession = NetworkSession(name: sessionName)
        activeSession = newSession
        sessions.insert(newSession, at: 0)

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func record(_ transaction: NetworkTransaction) {
        lock.lock()
        defer { lock.unlock() }

        var sanitized = redactor.sanitizeTransaction(transaction)

        // Automatically update active currentUser if this transaction has user details
        if let user = sanitized.userDetails ?? transaction.userDetails {
            self.currentUser = user
            sanitized.userDetails = user
        } else if sanitized.userDetails == nil, let activeUser = self.currentUser {
            // Inherit the session's active logged-in user profile
            sanitized.userDetails = activeUser
        }

        if let index = transactions.firstIndex(where: { $0.id == sanitized.id }) {
            transactions[index] = sanitized
        } else {
            transactions.insert(sanitized, at: 0)
            if transactions.count > maxLogCount {
                transactions.removeLast()
            }
            activeSession.transactionCount += 1
            if sanitized.error != nil || sanitized.response?.isServerError == true || sanitized.response?.isClientError == true {
                activeSession.errorCount += 1
            }
            if let idx = sessions.firstIndex(where: { $0.id == activeSession.id }) {
                sessions[idx] = activeSession
            }
        }

        if isPersistenceEnabled {
            NetworkLogPersistence.save(transactions: transactions)
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func transaction(with id: UUID) -> NetworkTransaction? {
        lock.lock()
        defer { lock.unlock() }
        return transactions.first { $0.id == id }
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        transactions.removeAll()
        activeSession.transactionCount = 0
        activeSession.errorCount = 0
        if let idx = sessions.firstIndex(where: { $0.id == activeSession.id }) {
            sessions[idx] = activeSession
        }
        if isPersistenceEnabled {
            NetworkLogPersistence.clear()
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func delete(at indexSet: IndexSet) {
        lock.lock()
        defer { lock.unlock() }
        for index in indexSet.sorted(by: >) {
            if index < transactions.count {
                transactions.remove(at: index)
            }
        }
        if isPersistenceEnabled {
            NetworkLogPersistence.save(transactions: transactions)
        }
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func delete(ids: Set<UUID>) {
        lock.lock()
        defer { lock.unlock() }
        transactions.removeAll { ids.contains($0.id) }
        if isPersistenceEnabled {
            NetworkLogPersistence.save(transactions: transactions)
        }
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    private func loadPersistedData() {
        if let persisted = NetworkLogPersistence.load() {
            self.transactions = persisted
        }
    }
}
