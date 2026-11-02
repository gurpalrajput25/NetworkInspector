import SwiftUI
import NetworkInspectorCore

public struct StatusBadgeView: View {
    public let statusCode: Int?
    public let isPending: Bool

    public init(statusCode: Int?, isPending: Bool = false) {
        self.statusCode = statusCode
        self.isPending = isPending
    }

    private var badgeColor: Color {
        guard !isPending else { return .orange }
        guard let code = statusCode else { return .gray }
        switch code {
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        case 500...599: return .red
        default: return .secondary
        }
    }

    private var text: String {
        if isPending { return "..." }
        guard let code = statusCode else { return "ERR" }
        return "\(code)"
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

public struct MethodBadgeView: View {
    public let method: String

    public init(method: String) {
        self.method = method.uppercased()
    }

    private var color: Color {
        switch method {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "PATCH": return .purple
        case "DELETE": return .red
        default: return .secondary
        }
    }

    public var body: some View {
        Text(method)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

public struct CopyButton: View {
    public let textToCopy: String
    @State private var hasCopied = false

    public init(textToCopy: String) {
        self.textToCopy = textToCopy
    }

    public var body: some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = textToCopy
            #endif
            hasCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hasCopied = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                if hasCopied {
                    Text("Copied")
                        .font(.caption2.bold())
                }
            }
            .foregroundColor(hasCopied ? .green : .accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.inspectorSecondaryBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
