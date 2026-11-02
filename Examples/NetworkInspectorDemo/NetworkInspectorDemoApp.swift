import SwiftUI
import NetworkInspector

@main
struct NetworkInspectorDemoApp: App {

    init() {
        // Plug and play initialization
        NetworkInspector.start(
            configuration: .development
        )
    }

    var body: some Scene {
        WindowGroup {
            DemoContentView()
        }
    }
}

