import SwiftUI
import NetworkInspectorCore
import NetworkInspectorAnalytics

public struct RequestAnalyticsDetailView: View {
    public let transaction: NetworkTransaction
    public var hostAverageDuration: TimeInterval? = nil

    public init(transaction: NetworkTransaction, hostAverageDuration: TimeInterval? = nil) {
        self.transaction = transaction
        self.hostAverageDuration = hostAverageDuration
    }

    private var analytics: RequestAnalytics {
        RequestAnalyticsBuilder.build(for: transaction, hostAverageDuration: hostAverageDuration)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Hero Performance & Duration Card
            heroPerformanceCard

            // 2. Waterfall Timings Breakdown
            waterfallTimingsSection

            // 3. Data Transfer & Payload Stats
            dataTransferSection

            // 4. Protocol, Transport & Connection Info
            transportInfoSection

            // 5. Caching & Freshness Diagnostics
            cachingDiagnosticsSection
        }
    }

    // MARK: - Subviews

    private var heroPerformanceCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tierColor.opacity(0.15))
                    .frame(width: 68, height: 68)

                Image(systemName: "timer")
                    .font(.system(size: 30))
                    .foregroundColor(tierColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Total Duration")
                        .font(.headline)
                    Spacer()
                    Text(analytics.performanceTier.rawValue.components(separatedBy: " (").first ?? "Fast")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tierColor.opacity(0.15))
                        .foregroundColor(tierColor)
                        .clipShape(Capsule())
                }

                Text(transaction.formattedDuration)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundColor(.primary)

                if let comp = analytics.hostComparison {
                    Text(comp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var waterfallTimingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Waterfall & Latency Breakdown")
                .font(.headline)

            // Visual Stacked Waterfall Bar
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(analytics.phases) { phase in
                        Rectangle()
                            .fill(colorForName(phase.colorName))
                            .frame(width: max(2, proxy.size.width * CGFloat(phase.percentageOfTotal)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 12)

            // Phase Legend & Details Table
            VStack(spacing: 8) {
                ForEach(analytics.phases) { phase in
                    HStack {
                        Circle()
                            .fill(colorForName(phase.colorName))
                            .frame(width: 8, height: 8)

                        Text(phase.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        Text(phase.formattedPercentage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .trailing)

                        Text(phase.formattedDuration)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 75, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(10)
            .background(Color.inspectorCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var dataTransferSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Transfer & Payload Stats")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statBox(title: "Total Transferred", value: ByteCountFormatter.string(fromByteCount: analytics.totalDataTransferred, countStyle: .file), subtitle: "Sent + Received")
                statBox(title: "Throughput", value: analytics.formattedThroughput ?? "—", subtitle: "Transfer Speed")
                statBox(title: "Request Sent", value: ByteCountFormatter.string(fromByteCount: Int64(analytics.totalBytesSent), countStyle: .file), subtitle: "\(analytics.requestHeadersBytes)B hdrs • \(analytics.requestBodyBytes)B body")
                statBox(title: "Response Received", value: ByteCountFormatter.string(fromByteCount: analytics.totalBytesReceived, countStyle: .file), subtitle: "\(analytics.responseHeadersBytes)B hdrs • \(analytics.responseBodyBytes)B body")
            }

            // Compression Analysis Card
            HStack(spacing: 12) {
                Image(systemName: analytics.isCompressed ? "arrow.down.right.and.arrow.up.left" : "doc.plaintext")
                    .font(.system(size: 20))
                    .foregroundColor(analytics.isCompressed ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Content-Encoding: \(analytics.contentEncoding)")
                            .font(.system(size: 13, weight: .semibold))
                        if analytics.isCompressed {
                            Text("COMPRESSED")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }

                    if let uncompressed = analytics.estimatedUncompressedBytes {
                        Text("Transferred: \(ByteCountFormatter.string(fromByteCount: analytics.responseBodyBytes, countStyle: .file)) • Estimated Uncompressed: ~\(ByteCountFormatter.string(fromByteCount: uncompressed, countStyle: .file)) (~74% bandwidth saved)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if analytics.responseBodyBytes > 50000 && !analytics.isCompressed {
                        Text("Payload exceeds 50 KB without compression. Enabling Gzip/Brotli on the server is recommended.")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text("No transport compression applied.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.inspectorCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var transportInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Protocol & Connection Info")
                .font(.headline)

            VStack(spacing: 6) {
                infoRow(title: "Protocol", value: analytics.networkProtocol)
                infoRow(title: "Connection Reused", value: analytics.isReusedConnection ? "Yes (Keep-Alive TCP/TLS)" : "No (New TCP Connection)")
                infoRow(title: "Client Source", value: analytics.clientSource)
                infoRow(title: "Host", value: transaction.request.host)
                infoRow(title: "Scheme", value: transaction.request.scheme.uppercased())
            }
            .padding(10)
            .background(Color.inspectorCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var cachingDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Caching & Freshness")
                .font(.headline)

            VStack(spacing: 6) {
                infoRow(title: "Cacheable", value: analytics.isCacheable ? "Yes" : "No / Not Specified")
                if let cc = analytics.cacheControlHeader {
                    infoRow(title: "Cache-Control", value: cc)
                } else {
                    infoRow(title: "Cache-Control", value: "(None provided by server)")
                }
                if let etag = analytics.eTag {
                    infoRow(title: "ETag", value: etag)
                }
            }
            .padding(10)
            .background(Color.inspectorCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func statBox(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inspectorCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private var tierColor: Color {
        switch analytics.performanceTier {
        case .blazingFast, .fast: return .green
        case .normal: return .blue
        case .slow: return .orange
        case .critical: return .red
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "purple": return .purple
        case "blue": return .blue
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "orange": return .orange
        case "green": return .green
        default: return .blue
        }
    }
}

