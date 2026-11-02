import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage

public struct SessionManagementView: View {
    @ObservedObject var logStore: NetworkLogStore = .shared
    @State private var newSessionName = ""
    @State private var showingNewSessionAlert = false

    public init() {}

    public var body: some View {
        List {
            Section(header: Text("Active Session")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "record.circle")
                            .foregroundColor(.green)
                        Text(logStore.activeSession.name)
                            .font(.headline)
                        Spacer()
                        Text("Active Now")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 16) {
                        Label("\(logStore.activeSession.transactionCount) requests", systemImage: "network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label("\(logStore.activeSession.errorCount) errors", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Started \(logStore.activeSession.startedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button {
                        showingNewSessionAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Start New Session")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
            }

            Section(header: Text("Previous Sessions (\(logStore.sessions.count - 1))")) {
                if logStore.sessions.count <= 1 {
                    Text("No previous sessions recorded.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(logStore.sessions.filter { $0.id != logStore.activeSession.id }) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.name)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("\(session.transactionCount) reqs")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                            }
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .inspectorInsetGroupedListStyle()
        .navigationTitle("Session Management")
        .inspectorNavigationTitleDisplayModeInline()
        .alert("Start New Session", isPresented: $showingNewSessionAlert) {
            TextField("Session Name (e.g. Checkout Flow)", text: $newSessionName)
            Button("Cancel", role: .cancel) { newSessionName = "" }
            Button("Start") {
                let name = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
                logStore.startNewSession(name: name.isEmpty ? nil : name)
                newSessionName = ""
            }
        } message: {
            Text("Starting a new session groups all upcoming requests together.")
        }
    }
}
