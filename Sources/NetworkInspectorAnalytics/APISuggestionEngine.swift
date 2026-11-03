import Foundation
import NetworkInspectorCore

// MARK: - Severity & Category Enums

public enum APISeverity: String, Codable, Sendable, Comparable {
    case error = "Error"
    case warning = "Warning"
    case suggestion = "Suggestion"
    case bestPractice = "Best Practice"

    public var sortOrder: Int {
        switch self {
        case .error: return 0
        case .warning: return 1
        case .suggestion: return 2
        case .bestPractice: return 3
        }
    }

    public static func < (lhs: APISeverity, rhs: APISeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    public var emoji: String {
        switch self {
        case .error: return "🚨"
        case .warning: return "⚠️"
        case .suggestion: return "💡"
        case .bestPractice: return "✨"
        }
    }
}

public enum APIMistakeCategory: String, Codable, Sendable, CaseIterable {
    case restDesign = "RESTful Design & URLs"
    case httpMethod = "HTTP Method Semantics"
    case headers = "Headers & Content Negotiation"
    case requestBody = "Request Body & Syntax"
    case responseStandards = "Response Standards & Status Codes"
    case security = "Security & Credentials"
    case performance = "Performance & Caching"

    public var icon: String {
        switch self {
        case .restDesign: return "link"
        case .httpMethod: return "arrow.triangle.swap"
        case .headers: return "list.bullet.rectangle"
        case .requestBody: return "doc.text"
        case .responseStandards: return "checkmark.seal"
        case .security: return "lock.shield"
        case .performance: return "gauge.with.dots.needle.bottom.50percent"
        }
    }
}

// MARK: - Mistake & Checklist Models

public struct APIMistake: Identifiable, Codable, Sendable {
    public let id: UUID
    public let category: APIMistakeCategory
    public let severity: APISeverity
    public let title: String
    public let explanation: String
    public let currentValue: String?
    public let suggestedFix: String
    public let rfcReference: String?

    public init(
        id: UUID = UUID(),
        category: APIMistakeCategory,
        severity: APISeverity,
        title: String,
        explanation: String,
        currentValue: String? = nil,
        suggestedFix: String,
        rfcReference: String? = nil
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.title = title
        self.explanation = explanation
        self.currentValue = currentValue
        self.suggestedFix = suggestedFix
        self.rfcReference = rfcReference
    }
}

public struct APIStandardsCheck: Identifiable, Codable, Sendable {
    public var id: String { title }
    public let title: String
    public let category: APIMistakeCategory
    public let isCompliant: Bool
    public let notes: String

    public init(title: String, category: APIMistakeCategory, isCompliant: Bool, notes: String) {
        self.title = title
        self.category = category
        self.isCompliant = isCompliant
        self.notes = notes
    }
}

// MARK: - Suggested Request & Response Models

public struct APISuggestedRequest: Codable, Sendable {
    public let method: String
    public let url: String
    public let headers: [String: String]
    public let body: String?
    public let curl: String

    public init(
        method: String,
        url: String,
        headers: [String: String],
        body: String?,
        curl: String
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.curl = curl
    }
}

public struct APISuggestedResponse: Codable, Sendable {
    public let statusCode: Int
    public let statusDescription: String
    public let headers: [String: String]
    public let body: String?
    public let schemaDescription: String

    public init(
        statusCode: Int,
        statusDescription: String,
        headers: [String: String],
        body: String?,
        schemaDescription: String
    ) {
        self.statusCode = statusCode
        self.statusDescription = statusDescription
        self.headers = headers
        self.body = body
        self.schemaDescription = schemaDescription
    }
}

// MARK: - Overall Suggestion Report

public struct APISuggestionReport: Codable, Sendable {
    public let overallScore: Int
    public let grade: String
    public let summary: String
    public let spottedMistakes: [APIMistake]
    public let standardsChecklist: [APIStandardsCheck]
    public let suggestedRequest: APISuggestedRequest
    public let suggestedResponse: APISuggestedResponse

    public init(
        overallScore: Int,
        grade: String,
        summary: String,
        spottedMistakes: [APIMistake],
        standardsChecklist: [APIStandardsCheck],
        suggestedRequest: APISuggestedRequest,
        suggestedResponse: APISuggestedResponse
    ) {
        self.overallScore = overallScore
        self.grade = grade
        self.summary = summary
        self.spottedMistakes = spottedMistakes
        self.standardsChecklist = standardsChecklist
        self.suggestedRequest = suggestedRequest
        self.suggestedResponse = suggestedResponse
    }

    public var errorCount: Int {
        spottedMistakes.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        spottedMistakes.filter { $0.severity == .warning }.count
    }

    public var suggestionCount: Int {
        spottedMistakes.filter { $0.severity == .suggestion || $0.severity == .bestPractice }.count
    }

    public var statusSummary: String {
        if errorCount > 0 {
            return "🚨 \(errorCount) Standard Violation\(errorCount > 1 ? "s" : "") Found"
        } else if warningCount > 0 {
            return "⚠️ \(warningCount) Design Warning\(warningCount > 1 ? "s" : "")"
        } else if suggestionCount > 0 {
            return "💡 \(suggestionCount) Recommended Improvement\(suggestionCount > 1 ? "s" : "")"
        } else {
            return "✅ Fully Compliant with API Standards"
        }
    }
}

// MARK: - Engine Implementation

public enum APISuggestionEngine {

    public static func analyze(transaction: NetworkTransaction) -> APISuggestionReport {
        var mistakes: [APIMistake] = []
        var checks: [APIStandardsCheck] = []

        let req = transaction.request
        let res = transaction.response
        let method = req.rawMethod.uppercased()

        // 1. Analyze RESTful URL Design & Path
        analyzeUrlDesign(req: req, mistakes: &mistakes, checks: &checks)

        // 2. Analyze HTTP Method Semantics
        analyzeHttpMethod(method: method, req: req, mistakes: &mistakes, checks: &checks)

        // 3. Analyze Request Headers & Content Negotiation
        analyzeHeaders(req: req, res: res, mistakes: &mistakes, checks: &checks)

        // 4. Analyze Request Body & Syntax
        analyzeRequestBody(req: req, method: method, mistakes: &mistakes, checks: &checks)

        // 5. Analyze Response Standards & Status Codes
        analyzeResponse(transaction: transaction, mistakes: &mistakes, checks: &checks)

        // 6. Analyze Security & Credentials
        analyzeSecurity(req: req, mistakes: &mistakes, checks: &checks)

        // 7. Analyze Performance & Caching
        analyzePerformance(transaction: transaction, mistakes: &mistakes, checks: &checks)

        // Sort mistakes by severity
        mistakes.sort { $0.severity < $1.severity }

        // Compute Score (100 base)
        var score = 100
        for m in mistakes {
            switch m.severity {
            case .error: score -= 20
            case .warning: score -= 10
            case .suggestion: score -= 5
            case .bestPractice: score -= 2
            }
        }
        score = max(0, min(100, score))

        let grade: String
        switch score {
        case 95...100: grade = "A+"
        case 90...94:  grade = "A"
        case 80...89:  grade = "B"
        case 70...79:  grade = "C"
        case 60...69:  grade = "D"
        default:       grade = "F"
        }

        let summaryText: String
        if mistakes.isEmpty {
            summaryText = "The API request and response fully comply with modern REST, HTTP/1.1 & HTTP/2 standards and conventions."
        } else {
            let topIssue = mistakes.first?.title ?? "API standard violation"
            summaryText = "Score: \(score)/100 (\(grade)). Spotted \(mistakes.count) potential issues. Primary concern: \(topIssue)."
        }

        // Generate Suggested Correct Request & Response
        let suggestedRequest = buildSuggestedRequest(transaction: transaction, mistakes: mistakes)
        let suggestedResponse = buildSuggestedResponse(transaction: transaction, mistakes: mistakes)

        return APISuggestionReport(
            overallScore: score,
            grade: grade,
            summary: summaryText,
            spottedMistakes: mistakes,
            standardsChecklist: checks,
            suggestedRequest: suggestedRequest,
            suggestedResponse: suggestedResponse
        )
    }

    // MARK: - Private Analysis Functions

    private static func analyzeUrlDesign(req: NetworkRequest, mistakes: inout [APIMistake], checks: inout [APIStandardsCheck]) {
        let rawPath = URLComponents(url: req.url, resolvingAgainstBaseURL: false)?.path ?? req.path
        let path = rawPath.isEmpty ? req.path : rawPath
        let segments = path.split(separator: "/").map(String.init)

        // 1. Action Verbs in Path (Anti-pattern in REST)
        let verbs = ["get", "create", "delete", "remove", "update", "edit", "fetch", "list", "save", "post"]
        var foundVerbSegment: String? = nil
        for s in segments {
            let lower = s.lowercased()
            for v in verbs {
                if lower == v || lower.hasPrefix("\(v)_") || lower.hasPrefix("\(v)-") || (lower.count > v.count && lower.hasPrefix(v) && s[s.index(s.startIndex, offsetBy: v.count)].isUppercase) {
                    foundVerbSegment = s
                    break
                }
            }
            if foundVerbSegment != nil { break }
        }

        if let verb = foundVerbSegment {
            mistakes.append(APIMistake(
                category: .restDesign,
                severity: .warning,
                title: "Action Verb in REST Path (`/\(verb)`)",
                explanation: "REST URIs should represent resources (nouns), not actions (verbs). The HTTP verb (GET, POST, PUT, DELETE, PATCH) conveys the action.",
                currentValue: path,
                suggestedFix: "Use a resource noun with the appropriate HTTP verb (e.g. use `POST /orders` instead of `POST /createOrder` or `DELETE /users/{id}` instead of `POST /deleteUser`).",
                rfcReference: "RFC 9110 §9.3 & RESTful API Guidelines"
            ))
            checks.append(APIStandardsCheck(title: "Resource-Oriented URIs (No Verbs)", category: .restDesign, isCompliant: false, notes: "Contains verb '\(verb)' in path"))
        } else {
            checks.append(APIStandardsCheck(title: "Resource-Oriented URIs (No Verbs)", category: .restDesign, isCompliant: true, notes: "URIs cleanly identify resources"))
        }

        // 2. Trailing slash check
        if path.count > 1 && path.hasSuffix("/") {
            mistakes.append(APIMistake(
                category: .restDesign,
                severity: .suggestion,
                title: "Redundant Trailing Slash in Path",
                explanation: "Trailing slashes can cause duplicate cache entries or trigger redundant 301/308 redirects from reverse proxies and API gateways.",
                currentValue: path,
                suggestedFix: "Omit the trailing slash: `\(path.dropLast())`.",
                rfcReference: "RFC 3986 §3.3"
            ))
            checks.append(APIStandardsCheck(title: "No Trailing Slashes", category: .restDesign, isCompliant: false, notes: "Ends with '/'"))
        } else {
            checks.append(APIStandardsCheck(title: "No Trailing Slashes", category: .restDesign, isCompliant: true, notes: "No trailing slash"))
        }

        // 3. Path casing (kebab-case vs snake_case or camelCase)
        let nonKebab = segments.first { segment in
            // Skip ID segments (UUIDs, numbers, hashes)
            if segment.count > 20 || segment.allSatisfy({ $0.isNumber }) || UUID(uuidString: segment) != nil {
                return false
            }
            return segment.contains("_") || segment.contains { $0.isUppercase }
        }

        if let badSegment = nonKebab {
            let suggestedKebab = badSegment
                .replacingOccurrences(of: "_", with: "-")
                .reduce("") { result, char in
                    char.isUppercase ? "\(result)-\(char.lowercased())" : "\(result)\(char)"
                }
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

            mistakes.append(APIMistake(
                category: .restDesign,
                severity: .suggestion,
                title: "Non-Standard Path Casing (`\(badSegment)`)",
                explanation: "Industry standards and RFC 3986 recommend lowercase kebab-case for URL path segments to prevent case-sensitivity ambiguities across operating systems and proxies.",
                currentValue: badSegment,
                suggestedFix: "Use lowercase kebab-case: `\(suggestedKebab)`.",
                rfcReference: "RFC 3986 §6.2.2.1"
            ))
            checks.append(APIStandardsCheck(title: "Lowercase kebab-case Paths", category: .restDesign, isCompliant: false, notes: "Segment '\(badSegment)' uses snake_case or camelCase"))
        } else {
            checks.append(APIStandardsCheck(title: "Lowercase kebab-case Paths", category: .restDesign, isCompliant: true, notes: "All path segments follow standard casing"))
        }
    }

    private static func analyzeHttpMethod(method: String, req: NetworkRequest, mistakes: inout [APIMistake], checks: inout [APIStandardsCheck]) {
        let hasBody = (req.bodySize > 0)

        // 1. GET with Body
        if method == "GET" && hasBody {
            mistakes.append(APIMistake(
                category: .httpMethod,
                severity: .error,
                title: "GET Request Contains Payload Body",
                explanation: "RFC 9110 specifies that a GET request message has no defined semantics for a payload body. Many CDNs, proxies, caches, and load balancers silently strip the body or reject the request with HTTP 400.",
                currentValue: "\(req.bodySize) bytes attached",
                suggestedFix: "Pass query parameters in the URL for GET queries, or switch to POST if a complex search filter query is required.",
                rfcReference: "RFC 9110 §9.3.1"
            ))
            checks.append(APIStandardsCheck(title: "GET Method Semantics", category: .httpMethod, isCompliant: false, notes: "GET with body is an anti-pattern"))
        } else {
            checks.append(APIStandardsCheck(title: "GET Method Semantics", category: .httpMethod, isCompliant: true, notes: "GET conforms to RFC 9110"))
        }

        // 2. DELETE with large body
        if method == "DELETE" && req.bodySize > 1024 {
            mistakes.append(APIMistake(
                category: .httpMethod,
                severity: .warning,
                title: "DELETE Request Contains Large Payload Body",
                explanation: "While RFC 9110 does not strictly forbid bodies on DELETE, servers are not required to inspect it, and some firewalls block it.",
                currentValue: "\(req.bodySize) bytes",
                suggestedFix: "Identify resources to delete via URI path or query parameters, or use a POST /batch-delete endpoint.",
                rfcReference: "RFC 9110 §9.3.5"
            ))
        }

        // 3. POST without body
        if ["POST", "PUT", "PATCH"].contains(method) && !hasBody && req.queryItems.count > 2 {
            mistakes.append(APIMistake(
                category: .httpMethod,
                severity: .suggestion,
                title: "\(method) Using Query String Instead of Request Body",
                explanation: "State-modifying requests (POST/PUT/PATCH) should deliver their resource representation in the request body as JSON, rather than overloading URL query strings.",
                currentValue: "\(req.queryItems.count) query parameters",
                suggestedFix: "Serialize payload as a JSON object inside the HTTP body and set `Content-Type: application/json`.",
                rfcReference: "RFC 9110 §9.3.3"
            ))
        }
    }

    private static func analyzeHeaders(req: NetworkRequest, res: NetworkResponse?, mistakes: inout [APIMistake], checks: inout [APIStandardsCheck]) {
        let headers = req.rawHeaders.isEmpty ? req.headers : req.rawHeaders
        let lowerKeys = Set(headers.keys.map { $0.lowercased() })

        // 1. Missing Accept Header
        if !lowerKeys.contains("accept") {
            mistakes.append(APIMistake(
                category: .headers,
                severity: .suggestion,
                title: "Missing `Accept` Header",
                explanation: "Explicit content negotiation via `Accept: application/json` guarantees that API error pages and representations are serialized as JSON rather than fallback HTML or XML.",
                currentValue: "(None provided)",
                suggestedFix: "Include `Accept: application/json` header.",
                rfcReference: "RFC 9110 §12.5.1"
            ))
            checks.append(APIStandardsCheck(title: "Content Negotiation (`Accept`)", category: .headers, isCompliant: false, notes: "Missing `Accept: application/json`"))
        } else {
            checks.append(APIStandardsCheck(title: "Content Negotiation (`Accept`)", category: .headers, isCompliant: true, notes: "`Accept` header provided"))
        }

        // 2. Missing Content-Type with Body
        if req.bodySize > 0 && !lowerKeys.contains("content-type") {
            mistakes.append(APIMistake(
                category: .headers,
                severity: .error,
                title: "Missing `Content-Type` Header",
                explanation: "When sending a payload body, the client MUST specify the media type (e.g., `application/json`) so the server knows how to deserialize the payload bytes.",
                currentValue: "(Missing)",
                suggestedFix: "Add `Content-Type: application/json` header.",
                rfcReference: "RFC 9110 §8.3"
            ))
            checks.append(APIStandardsCheck(title: "Payload `Content-Type`", category: .headers, isCompliant: false, notes: "Body present without `Content-Type`"))
        } else {
            checks.append(APIStandardsCheck(title: "Payload `Content-Type`", category: .headers, isCompliant: true, notes: "`Content-Type` properly configured"))
        }

        // 3. Missing User-Agent
        if !lowerKeys.contains("user-agent") {
            mistakes.append(APIMistake(
                category: .headers,
                severity: .bestPractice,
                title: "Missing `User-Agent` Header",
                explanation: "Supplying an app-specific User-Agent (e.g. `AppName/1.0 (iOS 17.0; arm64)`) helps backend analytics, debugging, and prevents Cloudflare/AWS WAF automated bot challenge blocks.",
                currentValue: "(None)",
                suggestedFix: "Set `User-Agent: <AppName>/<Version> (<OSVersion>; <DeviceModel>)`.",
                rfcReference: "RFC 9110 §10.1.5"
            ))
        }

        // 4. Missing Idempotency-Key on critical POST
        let isFinancialOrOrder = req.path.lowercased().contains("pay") || req.path.lowercased().contains("checkout") || req.path.lowercased().contains("order")
        if req.rawMethod.uppercased() == "POST" && isFinancialOrOrder && !lowerKeys.contains("idempotency-key") && !lowerKeys.contains("x-idempotency-key") {
            mistakes.append(APIMistake(
                category: .headers,
                severity: .warning,
                title: "Missing `Idempotency-Key` for Mutative Endpoint",
                explanation: "Network retries on order creation or payments can cause duplicate charges without an `Idempotency-Key` header.",
                currentValue: "(Missing)",
                suggestedFix: "Add `Idempotency-Key: <UUID>` on non-idempotent transactional operations.",
                rfcReference: "IETF Draft Idempotency-Key-Header"
            ))
        }
    }

    private static func analyzeRequestBody(req: NetworkRequest, method: String, mistakes: inout [APIMistake], checks: inout [APIStandardsCheck]) {
        guard let bodyData = req.rawBody ?? req.body, !bodyData.isEmpty else {
            checks.append(APIStandardsCheck(title: "JSON Body Syntax", category: .requestBody, isCompliant: true, notes: "No payload body"))
            return
        }

        // 1. JSON Syntax Check
        do {
            let json = try JSONSerialization.jsonObject(with: bodyData, options: [])
            checks.append(APIStandardsCheck(title: "JSON Body Syntax", category: .requestBody, isCompliant: true, notes: "Syntactically valid JSON"))

            // Check key casing consistency if it's a dictionary
            if let dict = json as? [String: Any] {
                var hasCamel = false
                var hasSnake = false
                for k in dict.keys {
                    if k.contains("_") { hasSnake = true }
                    if k.contains(where: { $0.isUppercase }) { hasCamel = true }
                }
                if hasCamel && hasSnake {
                    mistakes.append(APIMistake(
                        category: .requestBody,
                        severity: .suggestion,
                        title: "Inconsistent JSON Key Naming (Mixed camelCase & snake_case)",
                        explanation: "The request body mixes `camelCase` and `snake_case` field names. Consistent naming conventions make client SDK serialization predictable.",
                        currentValue: "Keys: \(dict.keys.joined(separator: ", "))",
                        suggestedFix: "Standardize on either `snake_case` (e.g. `user_id`, `created_at`) or `camelCase` (e.g. `userId`, `createdAt`) across all payloads.",
                        rfcReference: "JSON API / Google API Style Guide"
                    ))
                }
            }
        } catch {
            let errDesc = (error as NSError).localizedDescription
            mistakes.append(APIMistake(
                category: .requestBody,
                severity: .error,
                title: "Malformed JSON Request Body",
                explanation: "The request body contains invalid JSON syntax: \(errDesc). The server will likely respond with HTTP 400 Bad Request.",
                currentValue: String(data: bodyData.prefix(200), encoding: .utf8),
                suggestedFix: "Ensure all string keys and values use double quotes, eliminate dangling commas, and escape special characters.",
                rfcReference: "RFC 8259 (JSON Specification)"
            ))
            checks.append(APIStandardsCheck(title: "JSON Body Syntax", category: .requestBody, isCompliant: false, notes: "Malformed JSON: \(errDesc)"))
        }
    }

    private static func analyzeResponse(transaction: NetworkTransaction, mistakes: inout [APIMistake], checks: inout [APIStandardsCheck]) {
        guard let res = transaction.response else {
            if let err = transaction.error {
                checks.append(APIStandardsCheck(title: "Response Status Code", category: .responseStandards, isCompliant: false, notes: "Transport error: \(err.localizedDescription)"))
            }
            return
        }

        let code = res.statusCode
        let bodyStr = res.bodyString ?? ""
        let lowerBody = bodyStr.lowercased()

        // 1. Anti-Pattern: HTTP 200 with Error Payload
        let hasErrorKeyword = lowerBody.contains("\"error\":")
            || lowerBody.contains("\"errors\":")
            || lowerBody.contains("\"success\":false")
            || lowerBody.contains("\"success\": false")
            || lowerBody.contains("\"status\":\"error\"")
            || lowerBody.contains("\"status\": \"error\"")
            || lowerBody.contains("\"status\":\"fail\"")
            || lowerBody.contains("\"status\": \"fail\"")

        if (200...299).contains(code) && hasErrorKeyword {
            mistakes.append(APIMistake(
                category: .responseStandards,
                severity: .error,
                title: "Anti-Pattern: HTTP 200 OK with Error Payload",
                explanation: "Returning HTTP 200 OK for an error payload breaks HTTP semantics. It causes client-side HTTP libraries, reverse-proxy circuit breakers, and APM tools (Datadog, New Relic) to falsely treat failures as successful operations.",
                currentValue: "HTTP \(code) with payload: \(String(bodyStr.prefix(120)))",
                suggestedFix: "Return an appropriate 4xx status code (e.g., 400 Bad Request, 422 Unprocessable Entity, or 404 Not Found) or 5xx for server errors.",
                rfcReference: "RFC 9110 §15 (Status Codes)"
            ))
            checks.append(APIStandardsCheck(title: "Accurate HTTP Status Codes", category: .responseStandards, isCompliant: false, notes: "HTTP 200 returned with error payload"))
        } else {
            checks.append(APIStandardsCheck(title: "Accurate HTTP Status Codes", category: .responseStandards, isCompliant: true, notes: "Status code matches response content"))
        }

        // 2. 204 No Content returning a body
        if code == 204 && (res.contentLength > 0 || !bodyStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            mistakes.append(APIMistake(
                category: .responseStandards,
                severity: .error,
                title: "HTTP 204 No Content with Message Body",
                explanation: "RFC 9110 §15.3.5 strictly forbids a response with status code 204 from containing any message body.",
                currentValue: "\(res.contentLength) bytes attached to 204 response",
                suggestedFix: "Either return an empty body with 204 No Content, or change the status code to 200 OK if returning data.",
                rfcReference: "RFC 9110 §15.3.5"
            ))
        }

        // 3. 201 Created without Location header
        if code == 201 && res.headers["Location"] == nil && res.headers["location"] == nil {
            mistakes.append(APIMistake(
                category: .responseStandards,
                severity: .suggestion,
                title: "HTTP 201 Created Missing `Location` Header",
                explanation: "When a new resource is created with HTTP 201, RFC 9110 §15.3.2 recommends providing a `Location` header containing the URI of the newly created resource.",
                currentValue: "HTTP 201 without Location",
                suggestedFix: "Set `Location: /api/v1/resources/{newId}` in the response headers.",
                rfcReference: "RFC 9110 §15.3.2"
            ))
        }

        // 4. Non-Standard Error Response Schema (RFC 7807 / RFC 9457)
        if code >= 400 {
            let isRFC7807 = lowerBody.contains("\"type\"") && lowerBody.contains("\"title\"") && lowerBody.contains("\"status\"")
            if !isRFC7807 && !bodyStr.isEmpty {
                mistakes.append(APIMistake(
                    category: .responseStandards,
                    severity: .suggestion,
                    title: "Non-Standard Error Schema (Consider RFC 7807 / RFC 9457)",
                    explanation: "Adopting RFC 7807 / RFC 9457 Problem Details (`application/problem+json`) provides a standard machine-readable format: `{ type, title, status, detail, instance }`.",
                    currentValue: String(bodyStr.prefix(100)),
                    suggestedFix: "Format error responses adhering to RFC 7807 Problem Details schema.",
                    rfcReference: "RFC 7807 / RFC 9457"
                ))
            }
        }
    }

    private static func analyzeSecurity(req: NetworkRequest, mistakes: inout [APIMistake], checks: inout [APIStandardsCheck]) {
        // 1. Credentials in Query Parameters
        let sensitiveKeys = ["apikey", "api_key", "token", "accesstoken", "access_token", "secret", "password", "auth", "bearer"]
        var leakedParam: String? = nil
        for (k, _) in req.queryItems {
            if sensitiveKeys.contains(k.lowercased()) {
                leakedParam = k
                break
            }
        }

        if let param = leakedParam {
            mistakes.append(APIMistake(
                category: .security,
                severity: .error,
                title: "Credential Passed in Query Parameter (`?\(param)=...`)",
                explanation: "Passing API keys or auth tokens in query parameters is a critical security vulnerability. Query strings are recorded in plaintext in server logs, browser histories, proxy caches, and HTTP Referer headers.",
                currentValue: "?\(param)=[REDACTED]",
                suggestedFix: "Pass credentials in the HTTP `Authorization: Bearer <token>` header or `X-Api-Key` header.",
                rfcReference: "OWASP API Security Top 10 (API2:2023 Broken Authentication)"
            ))
            checks.append(APIStandardsCheck(title: "Secure Credential Transport", category: .security, isCompliant: false, notes: "Credential leaked in query param: \(param)"))
        } else {
            checks.append(APIStandardsCheck(title: "Secure Credential Transport", category: .security, isCompliant: true, notes: "No credentials detected in query string"))
        }

        // 2. Insecure HTTP Scheme
        if req.scheme.lowercased() == "http" && !req.host.contains("localhost") && !req.host.contains("127.0.0.1") {
            mistakes.append(APIMistake(
                category: .security,
                severity: .error,
                title: "Insecure Plaintext HTTP Protocol",
                explanation: "The request uses unencrypted plaintext HTTP. All payloads, authentication headers, and cookies can be intercepted or tampered with on public networks.",
                currentValue: req.url.absoluteString,
                suggestedFix: "Upgrade the endpoint scheme to HTTPS (TLS 1.3).",
                rfcReference: "RFC 9110 §2.4 & OWASP Top 10"
            ))
            checks.append(APIStandardsCheck(title: "TLS / HTTPS Encryption", category: .security, isCompliant: false, notes: "Plaintext HTTP used"))
        } else {
            checks.append(APIStandardsCheck(title: "TLS / HTTPS Encryption", category: .security, isCompliant: true, notes: "HTTPS or local testing"))
        }
    }

    private static func analyzePerformance(transaction: NetworkTransaction, mistakes: inout [APIMistake], checks: inout [APIStandardsCheck]) {
        // 1. Latency check
        if let d = transaction.duration {
            if d > 2.5 {
                mistakes.append(APIMistake(
                    category: .performance,
                    severity: .warning,
                    title: "High API Latency (\(String(format: "%.2f s", d)))",
                    explanation: "Requests exceeding 2 seconds noticeably degrade mobile and frontend user experience. High latency indicates heavy database queries, unindexed searches, or synchronous third-party dependencies.",
                    currentValue: "\(String(format: "%.2f s", d))",
                    suggestedFix: "Implement server-side caching (Redis), optimize SQL indexes, or use asynchronous processing for long-running tasks.",
                    rfcReference: "Web Performance Best Practices"
                ))
            }
        }

        // 2. Large uncompressed response
        if let res = transaction.response {
            if res.contentLength > 500_000 {
                let encoding = res.headers["Content-Encoding"] ?? res.headers["content-encoding"] ?? "none"
                if encoding == "none" || !["gzip", "br", "deflate"].contains(encoding.lowercased()) {
                    mistakes.append(APIMistake(
                        category: .performance,
                        severity: .warning,
                        title: "Large Uncompressed Payload (\(ByteCountFormatter.string(fromByteCount: res.contentLength, countStyle: .file)))",
                        explanation: "The response exceeds 500 KB and is transferred without compression. Gzip or Brotli compression typically reduces JSON payloads by 70% to 85%.",
                        currentValue: "\(res.contentLength) bytes, encoding: \(encoding)",
                        suggestedFix: "Enable Gzip or Brotli (`Content-Encoding: br`) compression on the API server/CDN.",
                        rfcReference: "RFC 9110 §8.4"
                    ))
                }
            }
        }
    }

    // MARK: - Suggested Fixes Generation

    private static func buildSuggestedRequest(transaction: NetworkTransaction, mistakes: [APIMistake]) -> APISuggestedRequest {
        let req = transaction.request
        var suggestedMethod = req.rawMethod.uppercased()

        // If GET had body, suggest POST or query params
        if suggestedMethod == "GET" && req.bodySize > 0 {
            suggestedMethod = "POST"
        }

        // Clean URL path: remove verbs if found, fix casing
        var cleanedPath = req.path
        let verbs = ["getUser": "users", "getUsers": "users", "createOrder": "orders", "deleteItem": "items", "updateProfile": "profiles"]
        for (verb, replacement) in verbs {
            if cleanedPath.contains(verb) {
                cleanedPath = cleanedPath.replacingOccurrences(of: verb, with: replacement)
            }
        }
        if cleanedPath.hasSuffix("/") && cleanedPath.count > 1 {
            cleanedPath = String(cleanedPath.dropLast())
        }

        // Clean query: remove credentials
        var cleanQueryItems: [String: String] = [:]
        var extractedToken: String? = nil
        let sensitiveKeys = ["apikey", "api_key", "token", "accesstoken", "access_token", "secret", "password", "auth", "bearer"]
        for (k, v) in req.queryItems {
            if sensitiveKeys.contains(k.lowercased()) {
                extractedToken = v
            } else {
                cleanQueryItems[k] = v
            }
        }

        // Reconstruct URL
        var components = URLComponents(url: req.url, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.path = cleanedPath
        if cleanQueryItems.isEmpty {
            components.queryItems = nil
        } else {
            components.queryItems = cleanQueryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let suggestedURL = components.url?.absoluteString ?? req.url.absoluteString

        // Standardize headers
        var headers = req.rawHeaders.isEmpty ? req.headers : req.rawHeaders
        if headers["Accept"] == nil && headers["accept"] == nil {
            headers["Accept"] = "application/json"
        }
        if req.bodySize > 0 && headers["Content-Type"] == nil && headers["content-type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        if let token = extractedToken, headers["Authorization"] == nil && headers["authorization"] == nil {
            headers["Authorization"] = "Bearer \(token)"
        }

        // Body formatting
        var cleanBody: String? = nil
        if let bodyData = req.rawBody ?? req.body, !bodyData.isEmpty {
            if let json = try? JSONSerialization.jsonObject(with: bodyData, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let pretty = String(data: prettyData, encoding: .utf8) {
                cleanBody = pretty
            } else {
                cleanBody = String(data: bodyData, encoding: .utf8)
            }
        }

        // Build corrected cURL
        var curl = "curl --location '\(suggestedURL)'"
        if suggestedMethod != "GET" {
            curl = "curl --location --request \(suggestedMethod) '\(suggestedURL)'"
        }
        for (k, v) in headers.sorted(by: { $0.key < $1.key }) {
            let lower = k.lowercased()
            if ["content-length", "host", "connection"].contains(lower) { continue }
            curl += " \\\n  --header '\(k): \(v)'"
        }
        if let body = cleanBody, !body.isEmpty, suggestedMethod != "GET" {
            let escaped = body.replacingOccurrences(of: "'", with: "'\\''")
            curl += " \\\n  --data '\(escaped)'"
        }

        return APISuggestedRequest(
            method: suggestedMethod,
            url: suggestedURL,
            headers: headers,
            body: cleanBody,
            curl: curl
        )
    }

    private static func buildSuggestedResponse(transaction: NetworkTransaction, mistakes: [APIMistake]) -> APISuggestedResponse {
        guard let res = transaction.response else {
            return APISuggestedResponse(
                statusCode: 500,
                statusDescription: "Internal Server Error",
                headers: ["Content-Type": "application/problem+json"],
                body: """
                {
                  "type": "https://errors.api.io/internal-error",
                  "title": "Internal Server Error",
                  "status": 500,
                  "detail": "\(transaction.error?.localizedDescription ?? "Transport failure")"
                }
                """,
                schemaDescription: "RFC 7807 Problem Details"
            )
        }

        var suggestedStatus = res.statusCode
        var suggestedHeaders = res.headers
        suggestedHeaders["Content-Type"] = "application/json; charset=utf-8"

        // Check if 200 with error
        let is200WithError = (res.statusCode == 200) && mistakes.contains { $0.title.contains("HTTP 200 OK with Error Payload") }
        if is200WithError {
            suggestedStatus = 400
        }

        if suggestedStatus == 204 {
            return APISuggestedResponse(
                statusCode: 204,
                statusDescription: "No Content",
                headers: [:],
                body: nil,
                schemaDescription: "RFC 9110 §15.3.5 (Empty body)"
            )
        }

        if suggestedStatus >= 400 {
            suggestedHeaders["Content-Type"] = "application/problem+json"
            let problemBody = """
            {
              "type": "https://api.example.com/errors/\(suggestedStatus)",
              "title": "\(HTTPURLResponse.localizedString(forStatusCode: suggestedStatus).capitalized)",
              "status": \(suggestedStatus),
              "detail": "Detailed RFC 7807 problem description explaining the mistake.",
              "instance": "\(transaction.request.path)"
            }
            """
            return APISuggestedResponse(
                statusCode: suggestedStatus,
                statusDescription: HTTPURLResponse.localizedString(forStatusCode: suggestedStatus).capitalized,
                headers: suggestedHeaders,
                body: problemBody,
                schemaDescription: "RFC 7807 Problem Details (Industry Standard)"
            )
        }

        // Successful standardized response
        let resBody = res.bodyString
        let formattedBody: String
        if let raw = resBody,
           let data = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let prettyStr = String(data: prettyData, encoding: .utf8) {
            formattedBody = prettyStr
        } else {
            formattedBody = resBody ?? "{}"
        }

        return APISuggestedResponse(
            statusCode: suggestedStatus,
            statusDescription: res.statusDescription,
            headers: suggestedHeaders,
            body: formattedBody,
            schemaDescription: "RESTful JSON Resource Representation"
        )
    }
}
