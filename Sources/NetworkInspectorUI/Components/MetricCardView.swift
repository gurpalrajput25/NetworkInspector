import SwiftUI

public struct MetricCardView: View {
    public let title: String
    public let value: String
    public let subtitle: String?
    public let iconName: String
    public let color: Color

    public init(
        title: String,
        value: String,
        subtitle: String? = nil,
        iconName: String,
        color: Color = .blue
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.iconName = iconName
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let sub = subtitle {
                Text(sub)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.inspectorCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
    }
}

public struct SyntaxHighlightedJSONView: View {
    public let jsonString: String

    public init(jsonString: String) {
        self.jsonString = jsonString
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(highlightedAttributedString)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color.inspectorCodeBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inspectorCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var highlightedAttributedString: AttributedString {
        var str = AttributedString(jsonString)

        // Simple regex-based syntax color styling in AttributedString
        if let regex = try? NSRegularExpression(pattern: "\"([^\"]+)\"\\s*:") {
            let ns = jsonString as NSString
            let matches = regex.matches(in: jsonString, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: jsonString),
                   let attrRange = str.range(of: jsonString[keyRange]) {
                    str[attrRange].foregroundColor = .purple
                    str[attrRange].inlinePresentationIntent = .stronglyEmphasized
                }
            }
        }

        return str
    }
}
