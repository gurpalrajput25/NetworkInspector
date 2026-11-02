import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage

public struct ExportCenterView: View {
    @ObservedObject var logStore: NetworkLogStore = .shared

    @State private var selectedFormat: ExportFormat = .json
    @State private var exportScope: ExportScope = .all
    @State private var previewText: String = ""

    public enum ExportScope: String, CaseIterable, Identifiable {
        case all = "All Requests"
        case currentSession = "Active Session"
        case errorsOnly = "Errors Only"
        public var id: String { rawValue }
    }

    public init() {}

    private var targetTransactions: [NetworkTransaction] {
        switch exportScope {
        case .all:
            return logStore.transactions
        case .currentSession:
            return logStore.transactions.filter { $0.sessionID == logStore.activeSession.id }
        case .errorsOnly:
            return logStore.transactions.filter { ($0.response?.statusCode ?? 200) >= 400 || $0.error != nil }
        }
    }

    private var exportData: Data {
        NetworkLogExporter.export(transactions: targetTransactions, format: selectedFormat) ?? Data()
    }

    private var exportString: String {
        String(data: exportData, encoding: .utf8) ?? "Unable to render text preview."
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Configuration Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Export Configuration")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Format")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Picker("Format", selection: $selectedFormat) {
                            ForEach(ExportFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scope")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Picker("Scope", selection: $exportScope) {
                            ForEach(ExportScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Text("Transactions in export:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(targetTransactions.count)")
                            .font(.subheadline.bold().monospaced())
                    }

                    ShareLink(
                        item: exportString,
                        preview: SharePreview("NetworkInspector_\(selectedFormat.rawValue).\(selectedFormat.fileExtension)")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export & Share File")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(targetTransactions.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(targetTransactions.isEmpty)
                }
                .padding()
                .background(Color.inspectorSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Preview Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Live Preview")
                            .font(.headline)
                        Spacer()
                        CopyButton(textToCopy: exportString)
                    }

                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(exportString.prefix(4000) + (exportString.count > 4000 ? "\n\n... (preview truncated) ..." : ""))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 260)
                    .background(Color.inspectorCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
                .background(Color.inspectorSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("Export Center")
        .inspectorNavigationTitleDisplayModeInline()
    }
}
