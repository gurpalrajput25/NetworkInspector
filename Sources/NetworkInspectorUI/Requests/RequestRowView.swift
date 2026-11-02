import SwiftUI
import NetworkInspectorCore

public struct RequestRowView: View {
    public let transaction: NetworkTransaction

    public init(transaction: NetworkTransaction) {
        self.transaction = transaction
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    MethodBadgeView(method: transaction.request.rawMethod)
                    StatusBadgeView(
                        statusCode: transaction.response?.statusCode,
                        isPending: transaction.status == .pending
                    )

                    Text(transaction.request.path)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Text(transaction.formattedDuration)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(durationColor)
                }

                HStack(spacing: 8) {
                    Text(transaction.request.host)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text(transaction.request.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    if transaction.request.isMultipart || (transaction.multipartParts?.isEmpty == false) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text(transaction.formattedResponseSize)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if let err = transaction.error {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text(err.localizedDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var durationColor: Color {
        guard let d = transaction.duration else { return .secondary }
        if d > 2.0 { return .red }
        if d > 0.8 { return .orange }
        return .secondary
    }
}

