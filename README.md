# NetworkInspector

**A reusable iOS network debugging and diagnostics SDK built with Swift and SwiftUI.**

NetworkInspector helps iOS developers, QA engineers, and backend teams capture, inspect, analyze, and share network activity directly inside an iOS application.

It supports URLSession and Alamofire integrations, with tools for request inspection, response analysis, performance monitoring, multipart debugging, and diagnostic reporting.

## Features

- **Network Capture:** Capture HTTP requests and responses through URLSession and Alamofire integrations.
- **Request Inspector:** Inspect URLs, HTTP methods, headers, query parameters, request bodies, and response data.
- **JSON Viewer:** View formatted JSON with syntax highlighting, expandable nodes, search, and copy support.
- **Multipart Inspector:** Inspect form-data fields, uploaded filenames, MIME types, and file sizes.
- **Performance Analytics:** Calculate average latency, P50, P75, P90, P95, P99, maximum duration, and request throughput.
- **Network Statistics:** View request counts, HTTP status distribution, success rates, failures, and data transfer.
- **Error Analysis:** Identify failed requests, HTTP 4XX/5XX responses, timeouts, and repeated failures.
- **Device Diagnostics:** Include device model, iOS version, app version, build number, locale, and timezone in diagnostic reports.
- **Session Management:** Group requests into debugging sessions and export session data.
- **Multiple Export Formats:** Export logs as JSON, HAR 1.2, CSV, cURL, and diagnostic reports.
- **Microsoft Teams Integration:** Share sanitized API failures and diagnostic reports with Teams.
- **Privacy Controls:** Redact sensitive headers and request/response fields before storing or exporting logs.
- **Quick Activation:** Open the inspector using shake gestures or programmatic presentation.
- **Native UI:** SwiftUI interface with Dark Mode, Light Mode, and Dynamic Type support.

## Requirements

| Requirement | Version |
|---|---|
| iOS | 16.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| Distribution | Swift Package Manager |

Alamofire integration is optional.

## Installation

NetworkInspector can be added to an existing Xcode project using Swift Package Manager.

### Option 1: Remote Package

1. Open your project in Xcode.
2. Select **File → Add Package Dependencies**.
3. Enter your NetworkInspector Git repository URL:

```text
https://github.com/gurpalrajput25/NetworkInspector.git
```

4. Select the required package products.
5. Click **Add Package**.

Choose the main SDK and the networking adapters your application needs.

### Option 2: Local Package

1. Open your Xcode project.
2. Select **File → Add Package Dependencies**.
3. Choose **Add Local**.
4. Select the NetworkInspector package directory.
5. Add the required products to your application target.

## Quick Start

### 1. Initialize NetworkInspector

Initialize the SDK once when your application launches.

**SwiftUI application**

```swift
import SwiftUI
import NetworkInspector

@main
struct MyApp: App {

    init() {
        #if DEBUG
        NetworkInspector.start(
            configuration: .development
        )
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**UIKit application**

```swift
import UIKit
import NetworkInspector

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        #if DEBUG
        NetworkInspector.start(
            configuration: .development
        )
        #endif

        return true
    }
}
```

### 2. Configure URLSession

For applications using URLSession, create an inspectable session configuration.

```swift
import Foundation
import NetworkInspector

let baseConfiguration = URLSessionConfiguration.default

baseConfiguration.timeoutIntervalForRequest = 30

let configuration =
    NetworkInspector.urlSessionConfiguration(
        from: baseConfiguration
    )

let session = URLSession(
    configuration: configuration
)
```

Use this session for network requests that should be captured.

Existing URLSession instances must be configured or integrated separately. NetworkInspector does not automatically guarantee interception of every existing session.

### 3. Configure Alamofire

For applications using Alamofire, add the optional `NetworkInspectorAlamofire` product.

```swift
import Alamofire
import NetworkInspectorAlamofire

let monitor =
    NetworkInspectorAlamofire.makeEventMonitor()

let session = Session(
    eventMonitors: [monitor]
)
```

Use this session for requests that should appear in NetworkInspector.

The adapter should coexist with your existing Alamofire interceptors and event monitors.

## Opening NetworkInspector

There are multiple ways to open the inspector.

### Programmatic Presentation

```swift
NetworkInspector.present()
```

### UIKit

```swift
import UIKit
import NetworkInspector

class SettingsViewController: UIViewController {

    @objc func openNetworkInspector() {
        NetworkInspector.present(from: self)
    }
}
```

### SwiftUI

```swift
import SwiftUI
import NetworkInspector

struct SettingsView: View {

    @State private var showInspector = false

    var body: some View {
        Button("Open Network Inspector") {
            showInspector = true
        }
        .sheet(isPresented: $showInspector) {
            NetworkInspector.makeInspectorView()
        }
    }
}
```

### Shake Gesture

Enable shake-to-open in the SDK configuration.

```swift
NetworkInspector.start(
    configuration: NetworkInspectorConfiguration(
        isEnabled: true,
        isShakeToOpenEnabled: true
    )
)
```

Shake the physical device or use the Simulator's **Device → Shake** command to open the inspector.

## Configuration

NetworkInspector provides configurable capture and privacy settings.

Example:

```swift
let configuration = NetworkInspectorConfiguration(
    isEnabled: true,
    captureRequestHeaders: true,
    captureResponseHeaders: true,
    captureRequestBody: true,
    captureResponseBody: true,
    enableAnalytics: true,
    enablePersistence: true,
    isShakeToOpenEnabled: true,
    maxLogCount: 1000,
    maxBodySize: 1_000_000
)

NetworkInspector.start(
    configuration: configuration
)
```

Configuration options may vary by SDK version.

## Request Inspection

NetworkInspector provides detailed information for each captured request.

**Request information**
- URL and HTTP method.
- Request headers.
- Query parameters.
- Request body.
- Content type.
- Multipart fields.
- Uploaded file metadata.

**Response information**
- HTTP status code.
- Response headers.
- Response body.
- Response content type.
- Response size.
- Network errors.

**Performance information**
- Request duration.
- DNS lookup timing, when available.
- Connection timing, when available.
- TLS handshake timing, when available.
- Time to first byte, when available.
- Response transfer timing, when available.

## Performance Analytics

NetworkInspector calculates performance metrics from captured requests.

| Metric | Description |
|---|---|
| Average | Average response duration |
| P50 | Median response duration |
| P75 | 75th percentile |
| P90 | 90th percentile |
| P95 | 95th percentile |
| P99 | 99th percentile |
| Maximum | Slowest request |
| Throughput | Requests per second |
| Failure Rate | Percentage of failed requests |

Analytics can be viewed across the current session and filtered by available time ranges and endpoints.

## Multipart Inspection

Multipart requests can be inspected without unnecessarily buffering large file contents.

Available information includes:

- Form-data field names.
- Text values, subject to redaction.
- Uploaded filenames.
- MIME types.
- File sizes.
- Multipart boundary information, when available.
- Upload duration.
- Upload progress, when observable.

## Microsoft Teams Integration

NetworkInspector supports sharing diagnostic information with Microsoft Teams through a configured integration.

Supported reporting includes:

- API failures.
- HTTP 4XX and 5XX responses.
- Slow requests.
- Request details.
- Sanitized cURL commands.
- Device diagnostics.
- Developer and QA notes.
- Session summaries.

Before sharing, sensitive information should be redacted.

**Security:** Do not embed shared webhook secrets or permanent Power Automate webhook URLs in the distributed SDK. Use an appropriately protected integration, delegated authentication, or an organization-managed relay.

Teams integration is optional and does not affect core network capture.

## Privacy and Security

NetworkInspector provides configurable privacy controls.

### Header Redaction

Sensitive headers should be masked by default:

- Authorization
- Proxy-Authorization
- Cookie
- Set-Cookie
- X-API-Key

### Request and Response Redaction

Sensitive JSON fields should be masked before storage and export.

Examples:

- password
- token
- access_token
- refresh_token
- secret
- apiKey
- creditCard
- cvv

Custom redaction rules can be configured.

### Additional Controls

- Disable request body capture.
- Disable response body capture.
- Exclude specific domains.
- Configure log retention.
- Limit stored request counts.
- Restrict capture in production.
- Export sanitized diagnostic reports.

### JWT User Information & Logged-In User Tracking

NetworkInspector automatically identifies and tracks the authenticated user across network sessions:

1. **Automatic Request Header Parsing**: When any network request includes an `Authorization`, `token`, `x-access-token`, `x-auth-token`, or `id-token` header, the SDK automatically decodes the JWT claims (`sub`, `email`, `name`, `role`, `org`, `exp`).
2. **Automatic Login Response Extraction**: When authentication endpoints return a JSON response containing `access_token`, `token`, `id_token`, or nested token payloads, the user profile is automatically extracted.
3. **Explicit User Profile Configuration**: You can programmatically set the currently logged-in user at any time (e.g. upon app login) so that all subsequent traces, diagnostic exports, and Teams notifications immediately show their identity:

```swift
// Option A: Set user profile explicitly
NetworkInspector.setLoggedInUser(
    name: "Gurpal Singh",
    email: "singhgurpal@seasiainfotech.com",
    userId: "usr_9988",
    role: "Admin",
    organizerId: "org_123"
)

// Option B: Set active user from a raw JWT token
NetworkInspector.setActiveJWT(userTokenString)

// Option C: Clear upon user logout
NetworkInspector.clearCurrentUser()
```

---

## ⚡️ Postman Direct Import & Live Token Options

NetworkInspector allows you to export and share requests with **unmasked live tokens** so that backend and QA engineers can reproduce issues in Postman in seconds:

1. **In-App Request Detail (cURL Tab)**:
   - Toggle between **🛡 Masked** (for safe screenshots) and **⚡️ Live Token (Postman)**.
   - Tap **Copy Live cURL (for Postman)**.
   - In Postman: Click **Import** → **Raw text** → Paste the cURL command and click **Import**. Postman immediately configures the URL, HTTP method, headers with your active Bearer token, and request body.
2. **Microsoft Teams Diagnostic Cards**:
   - In the **Share to Teams** dialog, toggle **Live Token (Direct Postman Import)** on or off.
   - When enabled, the Adaptive Card sent to your Teams channel contains the unmasked cURL command and full authenticated user profile for 1-click Postman execution.
3. **Export Center (HAR & cURL)**:
   - Toggle **Include Live Tokens (for Postman)** when exporting `.har` or `.sh` files to test in Charles, Postman, or Insomnia.

## Export Formats

NetworkInspector supports exporting captured network information.

| Format | Purpose |
|---|---|
| JSON | Structured request and response data |
| HAR 1.2 | HTTP archive for compatible debugging tools |
| CSV | Network statistics |
| cURL | Reproduce requests in a terminal |
| Diagnostic Report | Share debugging information with QA and backend teams |

Exports must respect configured redaction rules.

## Example Project

The repository includes an example iOS application demonstrating NetworkInspector integration.

The example covers:

- URLSession requests.
- Alamofire requests.
- GET and POST requests.
- Failed API responses.
- Multipart uploads.
- Request inspection.
- Dashboard presentation.
- Performance analytics.
- Log clearing.
- Diagnostic exports.

Open the example project in Xcode to explore the SDK.

## Running Tests

Run the package tests from the repository root:

```bash
swift test
```

Tests should cover:

- URLSession capture.
- Alamofire integration.
- Request and response parsing.
- Multipart metadata.
- Sensitive data redaction.
- Storage limits.
- Analytics calculations.
- Concurrent requests.
- Export formats.

## Limitations

NetworkInspector uses supported networking integration points rather than modifying application networking methods through swizzling.

Capture coverage depends on how the host application creates and configures its networking sessions.

- URLSession configurations must support the configured URLProtocol integration.
- Existing sessions may require explicit integration.
- Alamofire requires its dedicated adapter.
- Background sessions and custom networking stacks may require separate integration.
- Request and response bodies may not always be available.
- Detailed connection timings depend on URLSessionTaskMetrics availability.
- Multipart file contents are not captured by default.

## License

See the [LICENSE](LICENSE) file for licensing information.