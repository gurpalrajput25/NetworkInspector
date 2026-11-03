import SwiftUI
import NetworkInspectorCore
import NetworkInspectorAnalytics

public struct RequestAISuggestionsView: View {
    public let transaction: NetworkTransaction
    public var onShareToTeams: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

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
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Share AI Suggestions to Teams")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(colorScheme == .dark ? 0.25 : 0.12))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.85, green: 0.6, blue: 1.0) : .purple)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 8)
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
                        .background(scoreColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .foregroundColor(scoreColor)
                        .clipShape(Capsule())
                }

                Text(report.statusSummary)
                    .font(.subheadline.bold())
                    .foregroundColor(scoreColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(report.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var mistakesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                            HStack(alignment: .top) {
                                Text(mistake.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text(mistake.severity.rawValue.uppercased())
                                    .font(.system(size: 9, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityBadgeColor(mistake.severity).opacity(colorScheme == .dark ? 0.25 : 0.15))
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
                        .foregroundColor(.primary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    if let current = mistake.currentValue, !current.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Current Issue:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(current)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.red)
                                    .textSelection(.enabled)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(colorScheme == .dark ? 0.15 : 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.red.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Recommended Fix:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                            Spacer()
                            CopyButton(textToCopy: mistake.suggestedFix)
                        }
                        Text(mistake.suggestedFix)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? Color(red: 0.6, green: 0.95, blue: 0.6) : Color(red: 0.1, green: 0.55, blue: 0.1))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(colorScheme == .dark ? 0.15 : 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.green.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(12)
                .background(Color.inspectorCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.inspectorCardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
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
                HStack(alignment: .top) {
                    Text(req.method)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())

                    Text(req.url)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(req.curl)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(Color.inspectorCodeBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.inspectorCardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
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
                    .background((res.statusCode < 400 ? Color.green : Color.orange).opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .foregroundColor(res.statusCode < 400 ? .green : .orange)
                    .clipShape(Capsule())
            }

            if let body = res.body, !body.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(body)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(Color.inspectorCodeBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.inspectorCardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("(Empty body recommended by standard)")
                    .font(.caption.italic())
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
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
                                .foregroundColor(.primary)
                            Text(check.notes)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(Color.inspectorCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.inspectorCardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
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
