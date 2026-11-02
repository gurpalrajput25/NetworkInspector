import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorAnalytics

public struct ErrorAnalysisView: View {
    @ObservedObject var logStore: NetworkLogStore = .shared
    @State private var selectedTransaction: NetworkTransaction?

    public init() {}

    private var failedTransactions: [NetworkTransaction] {
        logStore.transactions.filter {
            $0.error != nil || ($0.response?.statusCode ?? 200) >= 400 || $0.status == .failed
        }
    }

    private var stats: NetworkStatistics {
        NetworkAnalyticsEngine.computeStatistics(from: logStore.transactions)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary KPI
                HStack(spacing: 12) {
                    MetricCardView(
                        title: "Failed Requests",
                        value: "\(failedTransactions.count)",
                        subtitle: "\(logStore.transactions.count) total",
                        iconName: "xmark.octagon.fill",
                        color: .red
                    )

                    MetricCardView(
                        title: "Failure Rate",
                        value: logStore.transactions.isEmpty ? "0%" : String(format: "%.1f%%", Double(failedTransactions.count) / Double(logStore.transactions.count) * 100),
                        subtitle: "Target: < 1.0%",
                        iconName: "percent",
                        color: failedTransactions.isEmpty ? .green : .red
                    )
                }

                // Error Classification
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Errors & Exceptions")
                        .font(.headline)

                    if stats.topErrors.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No errors recorded! Everything is healthy.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(stats.topErrors, id: \.error) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.error)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.red)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Text("\(item.count)x")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundColor(.red)
                                        .clipShape(Capsule())
                                }
                                .padding(10)
                                .background(Color.inspectorCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding()
                .background(Color.inspectorSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // List of Failed Transactions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Failed Transactions (\(failedTransactions.count))")
                        .font(.headline)

                    if failedTransactions.isEmpty {
                        Text("No failed transactions.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(failedTransactions) { transaction in
                                Button {
                                    selectedTransaction = transaction
                                } label: {
                                    RequestRowView(transaction: transaction)
                                        .padding(10)
                                        .background(Color.inspectorSecondaryBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Error Analysis")
        .inspectorNavigationTitleDisplayModeInline()
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                RequestDetailView(transaction: transaction)
            }
        }
    }
}
