import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorAnalytics

public struct NetworkDashboardView: View {
    @ObservedObject var logStore: NetworkLogStore = .shared

    @State private var showingAllRequests = false
    @State private var showingAnalytics = false
    @State private var showingErrors = false
    @State private var showingExport = false
    @State private var showingSessions = false
    @State private var showingSettings = false
    @State private var selectedTransaction: NetworkTransaction?
    @State private var isPulsing = false

    public init() {}

    private var metrics: NetworkPerformanceMetrics {
        NetworkAnalyticsEngine.computeMetrics(from: logStore.transactions)
    }

    private var healthReport: NetworkHealthReport {
        NetworkHealthCalculator.evaluate(transactions: logStore.transactions)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Health Overview Banner
                healthBannerView

                // 4 Key Metric Cards Grid
                metricsGridView

                // Quick Navigation Hub
                navigationHubView

                // Recent Activity Feed
                recentActivityView
            }
            .padding()
        }
        .navigationTitle("Network Inspector")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.3 : 0.8)
                        .opacity(isPulsing ? 1.0 : 0.4)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                RequestDetailView(transaction: transaction)
            }
        }
    }

    // MARK: - Subviews

    private var healthBannerView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(healthColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 58, height: 58)
                Circle()
                    .trim(from: 0, to: CGFloat(healthReport.score) / 100.0)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(-90))

                Text("\(healthReport.score)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("System Health:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(healthReport.status.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(healthColor)
                }

                Text(healthReport.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if let firstSuggestion = healthReport.suggestions.first {
                    Text("💡 \(firstSuggestion)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var healthColor: Color {
        switch healthReport.status {
        case .optimal: return .green
        case .good: return .blue
        case .degraded: return .orange
        case .critical: return .red
        }
    }

    private var metricsGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCardView(
                title: "Total Requests",
                value: "\(metrics.totalRequests)",
                subtitle: "\(metrics.requestsPerSecond > 0 ? String(format: "%.1f req/s", metrics.requestsPerSecond) : "Idle")",
                iconName: "network",
                color: .blue
            )

            MetricCardView(
                title: "Avg Latency",
                value: metrics.averageResponseTime < 1.0 ? String(format: "%.0f ms", metrics.averageResponseTime * 1000) : String(format: "%.2f s", metrics.averageResponseTime),
                subtitle: "P90: \(String(format: "%.0f ms", metrics.p90ResponseTime * 1000))",
                iconName: "clock.arrow.circlepath",
                color: .purple
            )

            MetricCardView(
                title: "Failure Rate",
                value: String(format: "%.1f%%", metrics.failurePercentage),
                subtitle: "\(logStore.transactions.filter { ($0.response?.statusCode ?? 200) >= 400 || $0.error != nil }.count) failed",
                iconName: "exclamationmark.triangle",
                color: metrics.failurePercentage > 5 ? .red : .green
            )

            MetricCardView(
                title: "Bandwidth",
                value: ByteCountFormatter.string(fromByteCount: metrics.totalDownloadedBytes, countStyle: .file),
                subtitle: "↑ \(ByteCountFormatter.string(fromByteCount: metrics.totalUploadedBytes, countStyle: .file))",
                iconName: "arrow.up.arrow.down",
                color: .teal
            )
        }
    }

    private var navigationHubView: some View {
        VStack(spacing: 8) {
            NavigationLink(destination: RequestListView()) {
                hubRow(title: "All Requests", subtitle: "Inspect full request logs, headers, bodies", icon: "list.bullet.rectangle", color: .blue, count: logStore.transactions.count)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: NetworkAnalyticsView()) {
                hubRow(title: "Performance Analytics", subtitle: "Percentiles, latency curves, throughput", icon: "chart.xyaxis.line", color: .purple)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ErrorAnalysisView()) {
                hubRow(title: "Error Analysis", subtitle: "Inspect 4xx, 5xx codes and network exceptions", icon: "exclamationmark.octagon", color: .red)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: SessionManagementView()) {
                hubRow(title: "Sessions", subtitle: "Manage and compare capture sessions", icon: "folder.badge.gearshape", color: .indigo, count: logStore.sessions.count)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ExportCenterView()) {
                hubRow(title: "Export Center", subtitle: "Export JSON, HAR, CSV, cURL scripts", icon: "square.and.arrow.up", color: .green)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: NetworkInspectorSettingsView()) {
                hubRow(title: "Settings & Privacy", subtitle: "Retention, credential redaction, gestures", icon: "gearshape", color: .gray)
            }
            .buttonStyle(.plain)
        }
    }

    private func hubRow(title: String, subtitle: String, icon: String, color: Color, count: Int? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let c = count {
                Text("\(c)")
                    .font(.caption.bold().monospaced())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.inspectorTertiaryFill)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(12)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recentActivityView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Requests")
                    .font(.headline)
                Spacer()
                NavigationLink("See All", destination: RequestListView())
                    .font(.caption.bold())
            }

            if logStore.transactions.isEmpty {
                Text("No recent requests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(logStore.transactions.prefix(6)) { transaction in
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
}
