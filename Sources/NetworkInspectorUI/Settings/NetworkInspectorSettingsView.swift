import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorIntegrations

public struct NetworkInspectorSettingsView: View {
    @ObservedObject var logStore: NetworkLogStore = .shared

    @AppStorage("netinspector_shake_enabled") private var isShakeEnabled = true
    @AppStorage("netinspector_floating_button") private var isFloatingButtonEnabled = false
    @AppStorage("netinspector_max_logs") private var maxLogCount = 1000
    @AppStorage("netinspector_persistence") private var isPersistenceEnabled = false

    @State private var teamsWebhookText = ""
    @State private var showingClearConfirmation = false

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("Storage & Retention")) {
                Picker("Max Captured Logs", selection: $maxLogCount) {
                    Text("200").tag(200)
                    Text("500").tag(500)
                    Text("1,000").tag(1000)
                    Text("2,500").tag(2500)
                }

                Toggle("Persist to Disk", isOn: $isPersistenceEnabled)
                    .onChange(of: isPersistenceEnabled) { enabled in
                        logStore.configure(
                            maxLogCount: maxLogCount,
                            enablePersistence: enabled,
                            privacyConfig: .default
                        )
                    }

                HStack {
                    Text("Currently In Memory")
                    Spacer()
                    Text("\(logStore.transactions.count) requests")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Gestures & Activation")) {
                Toggle("Shake Device to Open", isOn: $isShakeEnabled)
                Toggle("Floating Debug Button", isOn: $isFloatingButtonEnabled)
            }

            Section(header: Text("Microsoft Teams Integration")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Webhook URL")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("https://...", text: $teamsWebhookText)
                        .font(.system(size: 13, design: .monospaced))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onChange(of: teamsWebhookText) { text in
                            if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                TeamsIntegration.shared.webhookURL = url
                            }
                        }
                }
            }

            Section(header: Text("Privacy & Redaction")) {
                HStack {
                    Text("Authorization Header")
                    Spacer()
                    Text("Masked").foregroundColor(.green)
                }
                HStack {
                    Text("Cookie / Tokens")
                    Spacer()
                    Text("Redacted").foregroundColor(.green)
                }
                HStack {
                    Text("Sensitive JSON Keys")
                    Spacer()
                    Text("password, token, secret...").foregroundColor(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Clear All Captured Logs")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings & Privacy")
        .inspectorNavigationTitleDisplayModeInline()
        .onAppear {
            if let saved = TeamsIntegration.shared.webhookURL?.absoluteString {
                teamsWebhookText = saved
            }
        }
        .alert("Clear All Logs?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                logStore.clearAll()
            }
        } message: {
            Text("This will remove all current network logs from memory and cache.")
        }
    }
}
