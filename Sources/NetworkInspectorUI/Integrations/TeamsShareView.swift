import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage
import NetworkInspectorIntegrations
import NetworkInspectorAnalytics

public struct TeamsShareView: View {
    public let transaction: NetworkTransaction
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var developerNote: String = ""
    @State private var webhookURLString: String = ""
    @State private var includeLiveToken: Bool = true
    @State private var includeAISuggestions: Bool = true
    @State private var includeAnalytics: Bool = true
    @State private var showAISuggestionsPreview: Bool = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSuccessOverlay = false
    @State private var planeOffset: CGFloat = 0
    @State private var pulseGlow = false

    public init(transaction: NetworkTransaction) {
        self.transaction = transaction
    }

    private var userDetails: JWTUserDetails? {
        transaction.userDetails
            ?? NetworkLogStore.shared.currentUser
            ?? JWTDecoder.extractFromHeaders(transaction.request.rawHeaders)
            ?? JWTDecoder.extractFromHeaders(transaction.request.headers)
    }

    private var device: DeviceDiagnosticInfo {
        DeviceDiagnosticInfo.current()
    }

    private var aiReport: APISuggestionReport {
        APISuggestionEngine.analyze(transaction: transaction)
    }

    private var requestAnalytics: RequestAnalytics {
        RequestAnalyticsBuilder.build(for: transaction)
    }

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header details
                    headerCard

                    // 👤 Authenticated User Details Card (From JWT)
                    if let user = userDetails {
                        userProfileCard(user: user)
                    } else {
                        noUserCard
                    }

                    // 🤖 AI Suggestions & Standards Card
                    aiSuggestionsCard

                    // 📊 Request Analytics & Timings Card
                    analyticsToggleCard

                    // ⚡️ Live Token Toggle
                    liveTokenCard

                    // 📱 Device Diagnostics Card
                    deviceDiagnosticsCard

                    // Webhook Configuration
                    webhookConfigurationCard

                    // Note Input
                    noteInputCard

                    // Error message
                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Send Button with Launch Animation
                    sendButton
                }
                .padding()
            }
            .background(Color.inspectorBackground)

            // Success Overlay Animation
            if showSuccessOverlay {
                successOverlayView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .background(Color.inspectorBackground)
        .navigationTitle("Share to Teams")
        .inspectorNavigationTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            if let saved = TeamsIntegration.shared.webhookURL?.absoluteString {
                webhookURLString = saved
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                MethodBadgeView(method: transaction.request.rawMethod)
                StatusBadgeView(statusCode: transaction.response?.statusCode)
                Text(transaction.request.path)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Dispatch diagnostic trace, AI suggestions, and performance analytics to Teams.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var aiSuggestionsCard: some View {
        let report = aiReport
        return VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $includeAISuggestions) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(includeAISuggestions ? .purple : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("AI Suggestions & Standards")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(report.overallScore)/100 (Grade \(report.grade))")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(report.overallScore >= 80 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundColor(report.overallScore >= 80 ? .green : .orange)
                                .clipShape(Capsule())
                        }
                        Text("Shares API standards review, spotted mistakes, and recommended syntax fixes.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if includeAISuggestions {
                Divider()
                    .overlay(Color.inspectorCardBorder)

                HStack {
                    Text(report.statusSummary)
                        .font(.caption.bold())
                        .foregroundColor(report.errorCount > 0 ? .red : (report.warningCount > 0 ? .orange : .green))

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAISuggestionsPreview.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAISuggestionsPreview ? "Hide Preview" : "View Preview")
                            Image(systemName: showAISuggestionsPreview ? "chevron.up" : "chevron.down")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                    }
                }

                if showAISuggestionsPreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(report.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !report.spottedMistakes.isEmpty {
                            ForEach(report.spottedMistakes.prefix(3)) { mistake in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(mistake.severity.emoji)
                                        .font(.caption)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mistake.title)
                                            .font(.caption.bold())
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("Fix: \(mistake.suggestedFix)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.inspectorCardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.inspectorCardBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var analyticsToggleCard: some View {
        let analytics = requestAnalytics
        return VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $includeAnalytics) {
                HStack(spacing: 10) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 20))
                        .foregroundColor(includeAnalytics ? .blue : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Request Analytics & Timings")
                                .font(.system(size: 14, weight: .semibold))
                            Text(transaction.formattedDuration)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        Text("Shares waterfall timings, byte transfer stats, and network protocol.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if includeAnalytics {
                Divider()
                    .overlay(Color.inspectorCardBorder)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protocol")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(analytics.networkProtocol)
                            .font(.caption.bold().monospaced())
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Transferred")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: analytics.totalDataTransferred, countStyle: .file))
                            .font(.caption.bold().monospaced())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Performance")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(analytics.performanceTier.rawValue.components(separatedBy: " (").first ?? "Normal")
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func userProfileCard(user: JWTUserDetails) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                        .shadow(color: .purple.opacity(pulseGlow ? 0.4 : 0.1), radius: 6)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        let title = user.name ?? user.email ?? (user.userId != nil ? "User: \(user.userId!)" : "Authenticated User")
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                        if let role = user.role {
                            Text(role.uppercased())
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .clipShape(Capsule())
                        }
                    }

                    if let email = user.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(user.isExpired ? Color.red : Color.green)
                            .frame(width: 6, height: 6)
                        Text(user.isExpired ? "Token Expired" : "Active JWT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(user.isExpired ? .red : .green)
                    }
                    if let exp = user.expirationDate {
                        Text("Exp: \(exp.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()
                .overlay(Color.inspectorCardBorder)

            HStack {
                if let uid = user.userId {
                    Text("UID: \(uid)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let org = user.organizerId ?? transaction.request.queryItems["organizer_id"] {
                    Text("Org: \(org)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var noUserCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("No Logged-In User Detected")
                    .font(.system(size: 13, weight: .semibold))
                Text("Provide an Authorization header or set via NetworkInspector.setLoggedInUser(...)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var liveTokenCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $includeLiveToken) {
                HStack(spacing: 10) {
                    Image(systemName: includeLiveToken ? "bolt.shield.fill" : "shield.slash.fill")
                        .font(.system(size: 20))
                        .foregroundColor(includeLiveToken ? .green : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Authorization Token (Direct Execution)")
                            .font(.system(size: 14, weight: .semibold))
                        Text(includeLiveToken ? "Sends unmasked Bearer token in cURL so teammates can execute requests directly." : "Token is masked ([REDACTED]) for security.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var deviceDiagnosticsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 18))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(device.deviceModel) • \(device.systemName) \(device.systemVersion)")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(device.appName) v\(device.appVersion) (\(device.buildNumber)) • \(device.timeZone)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)
        }
        .padding(12)
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var webhookConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Teams / Power Automate Webhook URL")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            TextField("https://...webhook.office.com/...", text: $webhookURLString)
                .font(.system(size: 13, design: .monospaced))
                .padding(10)
                .background(Color.inspectorCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.inspectorCardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
        .padding()
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var noteInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Developer / QA Note (Optional)")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            TextEditor(text: $developerNote)
                .frame(height: 80)
                .padding(4)
                .background(Color.inspectorCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.inspectorCardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color.inspectorSecondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sendButton: some View {
        Button {
            sendToTeams()
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                        .offset(x: planeOffset, y: -planeOffset * 0.5)
                }
                Text(isSending ? "Dispatching Trace to Teams..." : "Send Diagnostic Card to Teams")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: isSending ? [.gray] : [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: isSending ? .clear : .purple.opacity(0.3), radius: 8, y: 4)
        }
        .disabled(isSending)
    }

    private var successOverlayView: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseGlow ? 1.05 : 0.95)

                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Sent to Teams!")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Diagnostic trace, AI standards suggestions, and request analytics were successfully delivered.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    withAnimation {
                        showSuccessOverlay = false
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(Color.inspectorCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.inspectorCardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }

    private func sendToTeams() {
        errorMessage = nil
        let trimmedURL = webhookURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), url.scheme?.hasPrefix("http") == true else {
            withAnimation(.spring()) {
                errorMessage = "Please enter a valid HTTP/HTTPS Teams webhook URL."
            }
            return
        }

        TeamsIntegration.shared.webhookURL = url
        isSending = true

        withAnimation(.easeOut(duration: 0.6)) {
            planeOffset = 15
        }

        TeamsIntegration.shared.send(
            transaction: transaction,
            developerNote: developerNote.isEmpty ? nil : developerNote,
            customWebhookURL: url,
            customUser: userDetails,
            maskTokens: !includeLiveToken,
            includeAISuggestions: includeAISuggestions,
            includeAnalytics: includeAnalytics
        ) { result in
            isSending = false
            planeOffset = 0
            switch result {
            case .success:
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showSuccessOverlay = true
                }
            case .failure(let error):
                withAnimation(.spring()) {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
