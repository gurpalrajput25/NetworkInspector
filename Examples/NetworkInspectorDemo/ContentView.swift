import SwiftUI
import NetworkInspector
import NetworkInspectorCore

public struct DemoContentView: View {
    @State private var showingInspector = false
    @State private var statusMessage = "Tap any button below to trigger real network requests."
    @State private var isRequesting = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Network Inspector Control")) {
                    Button {
                        showingInspector = true
                    } label: {
                        HStack {
                            Image(systemName: "gauge.with.needle.fill")
                                .foregroundColor(.accentColor)
                            Text("Open Network Inspector")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        NetworkInspector.clearLogs()
                        statusMessage = "Logs cleared."
                    } label: {
                        Label("Clear Inspector Logs", systemImage: "trash")
                    }
                }

                Section(header: Text("API Simulations (URLSession & Alamofire)")) {
                    Button("1. Trigger GET Request (User Profile)") {
                        executeGetRequest()
                    }

                    Button("2. Trigger POST Request with JWT Token") {
                        executePostWithJWT()
                    }

                    Button("3. Trigger 404 / 500 Error") {
                        executeFailedRequest()
                    }

                    Button("4. Trigger Slow Request (3.5s)") {
                        executeSlowRequest()
                    }

                    Button("5. Trigger Multipart Image Upload") {
                        executeMultipartUpload()
                    }
                }

                Section(header: Text("Last Request Status")) {
                    Text(statusMessage)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("NetworkInspector Demo")
            .sheet(isPresented: $showingInspector) {
                NetworkInspector.makeInspectorView()
            }
        }
    }

    // MARK: - Simulation Actions

    private func executeGetRequest() {
        statusMessage = "Executing GET request..."
        let config = NetworkInspector.urlSessionConfiguration(from: .default)
        let session = URLSession(configuration: config)
        let url = URL(string: "https://httpbin.org/get?user_id=usr_42&source=demo")!

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                statusMessage = "GET Completed: HTTP \(code) (\(data?.count ?? 0) bytes)"
            }
        }.resume()
    }

    private func executePostWithJWT() {
        statusMessage = "Executing POST with JWT Auth..."
        let config = NetworkInspector.urlSessionConfiguration(from: .default)
        let session = URLSession(configuration: config)
        let url = URL(string: "https://httpbin.org/post")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Demo JWT with sub, email, name, role
        let demoJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfOTA5MCIsImVtYWlsIjoiam9obi5kb2VAZXhhbXBsZS5jb20iLCJuYW1lIjoiSm9obiBEb2UiLCJyb2xlIjoidmVuZG9yX2FkbWluIiwiZXhwIjoyMDgwMDAwMDAwfQ.demo_signature"
        request.setValue("Bearer \(demoJWT)", forHTTPHeaderField: "Authorization")

        let payload = ["action": "save_event", "title": "Summer Festival 2026", "price": 49.99] as [String: Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                statusMessage = "POST Completed: HTTP \(code). Check Inspector for decoded JWT User profile!"
            }
        }.resume()
    }

    private func executeFailedRequest() {
        statusMessage = "Triggering 404 Not Found..."
        let config = NetworkInspector.urlSessionConfiguration(from: .default)
        let session = URLSession(configuration: config)
        let url = URL(string: "https://httpbin.org/status/404")!

        session.dataTask(with: url) { _, response, error in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                statusMessage = "Failure simulated: HTTP \(code)"
            }
        }.resume()
    }

    private func executeSlowRequest() {
        statusMessage = "Triggering slow 3.5-second delayed endpoint..."
        let config = NetworkInspector.urlSessionConfiguration(from: .default)
        let session = URLSession(configuration: config)
        let url = URL(string: "https://httpbin.org/delay/3")!

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                statusMessage = "Slow request finished: \(data?.count ?? 0) bytes received."
            }
        }.resume()
    }

    private func executeMultipartUpload() {
        statusMessage = "Executing simulated multipart upload..."
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append("Event Poster\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"poster_image\"; filename=\"poster.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append("fake_jpeg_image_binary_data".data(using: .utf8)!)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let config = NetworkInspector.urlSessionConfiguration(from: .default)
        let session = URLSession(configuration: config)
        var request = URLRequest(url: URL(string: "https://httpbin.org/post")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        session.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                statusMessage = "Multipart uploaded: HTTP \(code)"
            }
        }.resume()
    }
}

