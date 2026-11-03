import SwiftUI

public struct HeaderListView: View {
    public let headers: [String: String]

    public init(headers: [String: String]) {
        self.headers = headers
    }

    private var sortedHeaders: [(key: String, value: String)] {
        headers.map { ($0.key, $0.value) }.sorted { $0.key.lowercased() < $1.key.lowercased() }
    }

    public var body: some View {
        if headers.isEmpty {
            Text("No headers available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
        } else {
            VStack(spacing: 8) {
                ForEach(sortedHeaders, id: \.key) { header in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text(header.key)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            CopyButton(textToCopy: header.value)
                        }
                        Text(header.value)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .background(Color.inspectorCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.inspectorCardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
