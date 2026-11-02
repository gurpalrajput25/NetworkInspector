import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage

public struct NetworkInspectorView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            TabView {
                NetworkDashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "gauge.with.needle")
                    }

                RequestListView()
                    .tabItem {
                        Label("Requests", systemImage: "list.bullet.rectangle")
                    }

                NetworkAnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.xyaxis.line")
                    }

                NetworkInspectorSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}
