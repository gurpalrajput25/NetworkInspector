import SwiftUI
import NetworkInspectorCore
import NetworkInspectorAnalytics

public struct RequestAISuggestionsView: View {
    public let transaction: NetworkTransaction
    public var onShareToTeams: (() -> Void)? = nil

    @State private var selectedMistakeId: UUID? = nil
    @State private var copiedTextNotice: String? = nil

    public init(transaction: NetworkTransaction, onShareToTeams: (() -> Void)? = nil) {
        self.transaction = transaction
        self.onShareToTeams = onShareToTeams
    }

    private var report: APISuggestionReport {
        APISuggestionEngine.analyze(transaction: transaction)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Score & Grade Hero Card
            scoreHeroCard

            // 2. Spotted Mistakes / Issues List
            if !report.spottedMistakes.isEmpty {
                mistakesSection
            } else {
                perfectComplianceCard
            }

            // 3. Recommended Correct Request Syntax
            recommendedRequestSection

            // 4. Recommended Response Schema
            recommendedResponseSection

            // 5. Standards Compliance Checklist
            checklistSection

            // 6. Share to Teams Action
            if let shareAction = onShareToTeams {
                Button {
                    shareAction()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Share AI Suggestions to Teams")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Subviews

    private var scoreHeroCard: some View {
        HStack(spacing: 16) {
            // Circular Score Gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 76, height: 76)

                Circle()
                    .trim(from: 0, to: CGFloat(report.overallScore) / 100.0)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)

                VStack(spacing: 0) {
                    Text("\(report.overallScore)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text(report.grade)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(scoreColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("API Standards Score")
                        .font(.headline)
                    Spacer()
                    Text("Grade \(report.grade)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(scoreColor.opacity(0.15))
                        .foregroundColor(scoreColor)
                        .clipShape(Capsule())
                }

                Text(report.statusSummary)
                    .font(.subheadline.bold())
                    .foregroundColor(scoreColor)

                Text(report.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var mistakesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Spotted Mistakes & Violations")
                    .font(.headline)
                Spacer()
                Text("\(report.spottedMistakes.count) Found")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
            }

            ForEach(report.spottedMistakes) { mistake in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(mistake.severity.emoji)
                            .font(.system(size: 18))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(mistake.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(mistake.severity.rawValue.uppercased())
                                    .font(.system(size: 9, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityBadgeColor(mistake.severity).opacity(0.15))
                                    .foregroundColor(severityBadgeColor(mistake.severity))
                                    .clipShape(Capsule())
                            }

                            if let rfc = mistake.rfcReference {
                                Text("Standard: \(rfc)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Text(mistake.explanation)
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    if let current = mistake.currentValue, !current.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Issue:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                            Text(current)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Recommended Fix:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                            Spacer()
                            CopyButton(textToCopy: mistake.suggestedFix)
                        }
                        Text(mistake.suggestedFix)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(12)
                .background(Color.inspectorCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var perfectComplianceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Zero Standards Violations Found")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("This API transaction follows REST naming conventions, proper HTTP status semantics, and security headers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var recommendedRequestSection: some View {
        let req = report.suggestedRequest
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Correct Request Syntax")
                        .font(.headline)
                    Text("Conforms to REST resource nouns, standard headers, and valid JSON.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                CopyButton(textToCopy: req.curl)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(req.method)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())

                    Text(req.url)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(req.curl)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(Color.inspectorCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var recommendedResponseSection: some View {
        let res = report.suggestedResponse
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended Response Schema")
                        .font(.headline)
                    Text(res.schemaDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let body = res.body {
                    CopyButton(textToCopy: body)
                }
            }

            HStack {
                Text("Status: \(res.statusCode) \(res.statusDescription)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((res.statusCode < 400 ? Color.green : Color.orange).opacity(0.15))
                    .foregroundColor(res.statusCode < 400 ? .green : .orange)
                    .clipShape(Capsule())
            }

            if let body = res.body, !body.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(body)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(Color.inspectorCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("(Empty body recommended by standard)")
                    .font(.caption.italic())
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("API Standards Checklist")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(report.standardsChecklist) { check in
                    HStack(spacing: 10) {
                        Image(systemName: check.isCompliant ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(check.isCompliant ? .green : .orange)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                                .font(.system(size: 13, weight: .medium))
                            Text(check.notes)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(8)
                    .background(Color.inspectorCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        if report.overallScore >= 90 {
            return .green
        } else if report.overallScore >= 75 {
            return .blue
        } else if report.overallScore >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    private func severityBadgeColor(_ severity: APISeverity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .suggestion: return .blue
        case .bestPractice: return .purple
        }
    }
}

