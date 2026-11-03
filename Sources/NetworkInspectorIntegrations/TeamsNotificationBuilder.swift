import Foundation
import NetworkInspectorCore
import NetworkInspectorPrivacy
import NetworkInspectorAnalytics

public enum TeamsNotificationBuilder {

    public static func buildAdaptiveCard(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        aiSuggestionReport: APISuggestionReport? = nil,
        requestAnalytics: RequestAnalytics? = nil
    ) -> [String: Any] {
        let note = developerNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let multiLineCurl = String(transaction.generateCurl(maskTokens: maskTokens, singleLine: false).prefix(4000))
        let singleLineCurl = String(transaction.generateCurl(maskTokens: maskTokens, singleLine: true).prefix(4000))
        let statusCode = transaction.response?.statusCode ?? 0
        let statusText = transaction.response?.statusDescription ?? (transaction.error != nil ? "Failed" : "Pending")
        let formattedDuration = transaction.formattedDuration

        // Extract User Details from custom, transaction, or headers
        let userDetails = customUser
            ?? transaction.userDetails
            ?? JWTDecoder.extractFromHeaders(transaction.request.rawHeaders)
            ?? JWTDecoder.extractFromHeaders(transaction.request.headers)
        let device = DeviceDiagnosticInfo.current()

        // Status styling
        let statusEmoji: String
        if statusCode >= 500 {
            statusEmoji = "🔴"
        } else if statusCode >= 400 {
            statusEmoji = "🟠"
        } else if statusCode >= 200 && statusCode < 300 {
            statusEmoji = "🟢"
        } else if transaction.error != nil {
            statusEmoji = "❌"
        } else {
            statusEmoji = "🔵"
        }

        let statusSummary = "\(statusEmoji) \(statusCode > 0 ? "\(statusCode) \(statusText)" : (transaction.error != nil ? "Network Error" : "Pending")) • \(formattedDuration)"

        var bodyItems: [[String: Any]] = []

        // 1. HERO HEADER CONTAINER
        bodyItems.append([
            "type": "Container",
            "style": "emphasis",
            "items": [
                [
                    "type": "TextBlock",
                    "text": statusSummary,
                    "weight": "Bolder",
                    "size": "Medium",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": "\(transaction.request.rawMethod) \(transaction.request.path)",
                    "weight": "Bolder",
                    "size": "Large",
                    "spacing": "None",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": "Host: \(transaction.request.host) • Env: \(environmentName) • Source: \(transaction.clientSource)",
                    "isSubtle": true,
                    "spacing": "None",
                    "wrap": true
                ]
            ]
        ])

        // 2. 🤖 AI SUGGESTIONS & API STANDARDS AUDIT (if enabled)
        if let ai = aiSuggestionReport {
            var aiItems: [[String: Any]] = [
                [
                    "type": "TextBlock",
                    "text": "🤖 AI Suggestions & API Standards Audit",
                    "weight": "Bolder",
                    "size": "Medium",
                    "wrap": true
                ],
                [
                    "type": "FactSet",
                    "spacing": "Small",
                    "facts": [
                        ["title": "Standards Score:", "value": "\(ai.overallScore) / 100 (Grade \(ai.grade))"],
                        ["title": "Status:", "value": ai.statusSummary]
                    ]
                ],
                [
                    "type": "TextBlock",
                    "text": ai.summary,
                    "wrap": true,
                    "spacing": "Small"
                ]
            ]

            if !ai.spottedMistakes.isEmpty {
                aiItems.append([
                    "type": "TextBlock",
                    "text": "🔍 Spotted Mistakes & Standards Violations (\(ai.spottedMistakes.count)):",
                    "weight": "Bolder",
                    "spacing": "Medium"
                ])

                for mistake in ai.spottedMistakes.prefix(4) {
                    let text = "**\(mistake.severity.emoji) \(mistake.title)**\n• *Why:* \(mistake.explanation)\n• *Suggested Fix:* `\(mistake.suggestedFix)`"
                    aiItems.append([
                        "type": "TextBlock",
                        "text": text,
                        "wrap": true,
                        "spacing": "Small"
                    ])
                }
            }

            // Correct Request Syntax Box
            aiItems.append(contentsOf: [
                [
                    "type": "TextBlock",
                    "text": "✨ Corrected API Request Syntax",
                    "weight": "Bolder",
                    "spacing": "Medium"
                ],
                [
                    "type": "CodeBlock",
                    "language": "bash",
                    "codeSnippet": ai.suggestedRequest.curl,
                    "fallback": [
                        "type": "TextBlock",
                        "text": "```\n\(ai.suggestedRequest.curl)\n```",
                        "fontType": "Monospace",
                        "wrap": false
                    ]
                ]
            ])

            // Recommended Response Schema
            if let resBody = ai.suggestedResponse.body, !resBody.isEmpty {
                aiItems.append(contentsOf: [
                    [
                        "type": "TextBlock",
                        "text": "✨ Recommended Response Schema (\(ai.suggestedResponse.schemaDescription))",
                        "weight": "Bolder",
                        "spacing": "Small"
                    ],
                    [
                        "type": "CodeBlock",
                        "language": "json",
                        "codeSnippet": String(resBody.prefix(800)),
                        "fallback": [
                            "type": "TextBlock",
                            "text": "```\n\(String(resBody.prefix(800)))\n```",
                            "fontType": "Monospace",
                            "wrap": false
                        ]
                    ]
                ])
            }

            bodyItems.append([
                "type": "Container",
                "style": "emphasis",
                "spacing": "Medium",
                "items": aiItems
            ])
        }

        // 3. 📊 REQUEST PERFORMANCE & TIMINGS ANALYTICS (if enabled)
        if let analytics = requestAnalytics {
            var timingFacts: [[String: String]] = [
                ["title": "Total Duration:", "value": String(format: "%.1f ms", analytics.totalDuration * 1000)],
                ["title": "Performance Tier:", "value": analytics.performanceTier.rawValue]
            ]
            if let wait = analytics.waitDuration {
                timingFacts.append(["title": "Server Wait (TTFB):", "value": String(format: "%.1f ms", wait * 1000)])
            }
            if let dns = analytics.dnsDuration {
                timingFacts.append(["title": "DNS Lookup:", "value": String(format: "%.1f ms", dns * 1000)])
            }
            if let conn = analytics.connectDuration {
                timingFacts.append(["title": "TCP / TLS Connect:", "value": String(format: "%.1f ms", conn * 1000)])
            }

            var dataFacts: [[String: String]] = [
                ["title": "Total Transferred:", "value": ByteCountFormatter.string(fromByteCount: analytics.totalDataTransferred, countStyle: .file)],
                ["title": "Data Sent:", "value": ByteCountFormatter.string(fromByteCount: Int64(analytics.totalBytesSent), countStyle: .file)],
                ["title": "Data Received:", "value": ByteCountFormatter.string(fromByteCount: analytics.totalBytesReceived, countStyle: .file)],
                ["title": "Protocol:", "value": analytics.networkProtocol],
                ["title": "Connection:", "value": analytics.isReusedConnection ? "Reused (Keep-Alive)" : "New Handshake"]
            ]
            if let throughput = analytics.formattedThroughput {
                dataFacts.append(["title": "Throughput:", "value": throughput])
            }

            bodyItems.append([
                "type": "Container",
                "spacing": "Medium",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": "📊 Request Analytics & Waterfall Timings",
                        "weight": "Bolder",
                        "size": "Medium"
                    ],
                    [
                        "type": "FactSet",
                        "spacing": "Small",
                        "facts": timingFacts + dataFacts
                    ]
                ]
            ])
        }

        // 4. 📋 1-CLICK EXECUTABLE cURL
        let singleLineCodeBlock: [String: Any] = [
            "type": "CodeBlock",
            "language": "bash",
            "codeSnippet": singleLineCurl,
            "fallback": [
                "type": "TextBlock",
                "text": "```\n\(singleLineCurl)\n```",
                "fontType": "Monospace",
                "wrap": false
            ]
        ]

        let curlCardTitle = maskTokens ? "📋 Executable cURL (Masked)" : "📋 Executable cURL (1-Line Quick Copy • Direct Execution)"
        let curlCardSubtitle = maskTokens
            ? "⚠️ Tokens are masked for privacy. Replace [REDACTED] before executing."
            : "⚡️ Active live token included. Ready for direct execution in Terminal or API clients."

        let executionGuide = """
        👉 **Instant Execution:**
        1. Click **'Copy code'** on the top-right of the box above.
        2. Paste directly into your **Terminal shell** or any API client (`Cmd+V` / `Ctrl+V`).
        3. Method, URL, query params, headers, and authorization are 100% pre-configured.
        """

        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": curlCardTitle,
                    "weight": "Bolder",
                    "size": "Medium",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": curlCardSubtitle,
                    "isSubtle": true,
                    "spacing": "None",
                    "wrap": true
                ],
                singleLineCodeBlock,
                [
                    "type": "TextBlock",
                    "text": executionGuide,
                    "isSubtle": true,
                    "spacing": "Small",
                    "wrap": true
                ]
            ]
        ])

        // 5. 🔍 FORMATTED MULTI-LINE cURL
        let multiLineCodeBlock: [String: Any] = [
            "type": "CodeBlock",
            "language": "bash",
            "codeSnippet": multiLineCurl,
            "fallback": [
                "type": "TextBlock",
                "text": "```\n\(multiLineCurl)\n```",
                "fontType": "Monospace",
                "wrap": false
            ]
        ]

        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "🔍 Formatted Multi-Line cURL (Terminal / Code Review)",
                    "weight": "Bolder",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": "Formatted with line breaks (\\) for easy inspection and debugging.",
                    "isSubtle": true,
                    "spacing": "None",
                    "wrap": true
                ],
                multiLineCodeBlock
            ]
        ])

        // 6. 📦 REQUEST PAYLOAD PEEK
        if let bodyData = transaction.request.rawBody ?? transaction.request.body, !bodyData.isEmpty,
           let bodyStr = String(data: bodyData, encoding: .utf8) ?? String(data: bodyData, encoding: .ascii),
           !bodyStr.isEmpty {
            let formattedReqBody = formatJSONString(bodyStr) ?? String(bodyStr.prefix(2000))
            let isJSON = transaction.request.isJSON || bodyStr.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
            bodyItems.append([
                "type": "Container",
                "spacing": "Medium",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": "📦 Request Body (\(transaction.request.contentType ?? "Payload"))",
                        "weight": "Bolder",
                        "wrap": true
                    ],
                    [
                        "type": "CodeBlock",
                        "language": isJSON ? "json" : "PlainText",
                        "codeSnippet": formattedReqBody,
                        "fallback": [
                            "type": "TextBlock",
                            "text": "```\n\(formattedReqBody)\n```",
                            "fontType": "Monospace",
                            "wrap": false
                        ]
                    ]
                ]
            ])
        }

        // 7. 📥 SERVER RESPONSE PEEK
        if let res = transaction.response,
           let resBody = res.bodyString, !resBody.isEmpty {
            let isErrorRes = res.statusCode >= 400
            let resTitle = isErrorRes
                ? "🚨 Server Error Response (\(res.statusCode) \(res.statusDescription))"
                : "📥 Server Response (\(res.statusCode) \(res.statusDescription))"
            let formattedResBody = formatJSONString(resBody) ?? String(resBody.prefix(2000))
            let isJSON = res.mimeType?.contains("json") == true
                || resBody.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
                || resBody.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[")

            bodyItems.append([
                "type": "Container",
                "spacing": "Medium",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": resTitle,
                        "weight": "Bolder",
                        "wrap": true
                    ],
                    [
                        "type": "CodeBlock",
                        "language": isJSON ? "json" : "PlainText",
                        "codeSnippet": formattedResBody,
                        "fallback": [
                            "type": "TextBlock",
                            "text": "```\n\(formattedResBody)\n```",
                            "fontType": "Monospace",
                            "wrap": false
                        ]
                    ]
                ]
            ])
        } else if let err = transaction.error {
            bodyItems.append([
                "type": "Container",
                "spacing": "Medium",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": "❌ Transport Error",
                        "weight": "Bolder",
                        "wrap": true
                    ],
                    [
                        "type": "TextBlock",
                        "text": err.localizedDescription,
                        "wrap": true
                    ]
                ]
            ])
        }

        // 8. 👤 AUTHENTICATED USER DETAILS
        if let user = userDetails {
            var userFacts: [[String: String]] = []
            if let name = user.name, !name.isEmpty {
                userFacts.append(["title": "Name:", "value": name])
            }
            if let email = user.email, !email.isEmpty {
                userFacts.append(["title": "Email:", "value": email])
            }
            if let uid = user.userId, !uid.isEmpty {
                userFacts.append(["title": "User ID:", "value": uid])
            }
            if let role = user.role, !role.isEmpty {
                userFacts.append(["title": "Role:", "value": role])
            }
            if let org = user.organizerId, !org.isEmpty {
                userFacts.append(["title": "Organizer ID:", "value": org])
            } else if let orgParam = transaction.request.queryItems["organizer_id"], !orgParam.isEmpty {
                userFacts.append(["title": "Organizer ID:", "value": orgParam])
            }
            if let exp = user.expirationDate {
                let status = user.isExpired ? "⚠️ Expired" : "Active"
                userFacts.append(["title": "Token Status:", "value": "\(status) (Expires: \(exp.formatted(date: .abbreviated, time: .shortened)))"])
            } else {
                userFacts.append(["title": "Token Status:", "value": "Active"])
            }
            if let iat = user.issuedAt {
                userFacts.append(["title": "Issued At:", "value": iat.formatted(date: .abbreviated, time: .shortened)])
            }

            if userFacts.isEmpty {
                for (k, v) in user.rawPayload.prefix(5) where !["exp", "iat", "nbf", "jti"].contains(k) {
                    userFacts.append(["title": "\(k):", "value": v])
                }
            }

            if !userFacts.isEmpty {
                bodyItems.append([
                    "type": "Container",
                    "spacing": "Medium",
                    "items": [
                        [
                            "type": "TextBlock",
                            "text": "👤 Authenticated User & Token Claims",
                            "weight": "Bolder",
                            "wrap": true
                        ],
                        [
                            "type": "FactSet",
                            "spacing": "Small",
                            "facts": userFacts
                        ]
                    ]
                ])
            }
        }

        // 9. 📱 DEVICE & DIAGNOSTIC DETAILS
        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "📱 Client & Device Diagnostics",
                    "weight": "Bolder",
                    "wrap": true
                ],
                [
                    "type": "FactSet",
                    "spacing": "Small",
                    "facts": [
                        ["title": "Device Model:", "value": device.deviceModel],
                        ["title": "OS Version:", "value": "\(device.systemName) \(device.systemVersion)"],
                        ["title": "App Version:", "value": "\(device.appName) v\(device.appVersion) (\(device.buildNumber))"],
                        ["title": "Timezone:", "value": device.timeZone],
                        ["title": "Locale:", "value": device.locale]
                    ]
                ]
            ]
        ])

        // 10. DEVELOPER / QA NOTE
        if !note.isEmpty {
            bodyItems.append([
                "type": "Container",
                "spacing": "Medium",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": "🧾 Developer / QA Note",
                        "weight": "Bolder",
                        "wrap": true
                    ],
                    [
                        "type": "TextBlock",
                        "text": note,
                        "wrap": true
                    ]
                ]
            ])
        }

        // 11. FOOTER
        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "Generated via NetworkInspector SDK • AI Standards & Diagnostics",
                    "isSubtle": true,
                    "wrap": true
                ]
            ]
        ])

        return [
            "type": "AdaptiveCard",
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.5",
            "body": bodyItems
        ]
    }

    /// Wraps the Adaptive Card in a Teams Webhook message envelope.
    public static func buildMessagePayload(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        includeAISuggestions: Bool = true,
        includeAnalytics: Bool = true
    ) -> [String: Any] {
        let aiReport = includeAISuggestions ? APISuggestionEngine.analyze(transaction: transaction) : nil
        let analytics = includeAnalytics ? RequestAnalyticsBuilder.build(for: transaction) : nil

        let card = buildAdaptiveCard(
            transaction: transaction,
            developerNote: developerNote,
            environmentName: environmentName,
            customUser: customUser,
            maskTokens: maskTokens,
            aiSuggestionReport: aiReport,
            requestAnalytics: analytics
        )
        return [
            "type": "message",
            "attachments": [
                [
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": card
                ]
            ]
        ]
    }

    /// Backward compatibility overload ignoring postmanDeepLink
    public static func buildAdaptiveCard(
        transaction: NetworkTransaction,
        postmanDeepLink: String?,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        buildAdaptiveCard(
            transaction: transaction,
            developerNote: developerNote,
            environmentName: environmentName,
            customUser: customUser,
            maskTokens: maskTokens,
            aiSuggestionReport: nil,
            requestAnalytics: nil
        )
    }

    /// Backward compatibility overload ignoring postmanDeepLink
    public static func buildMessagePayload(
        transaction: NetworkTransaction,
        postmanDeepLink: String?,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        buildMessagePayload(
            transaction: transaction,
            developerNote: developerNote,
            environmentName: environmentName,
            customUser: customUser,
            maskTokens: maskTokens,
            includeAISuggestions: true,
            includeAnalytics: true
        )
    }

    private static func formatJSONString(_ string: String, maxCount: Int = 1800) -> String? {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        if prettyString.count > maxCount {
            return String(prettyString.prefix(maxCount)) + "\n... (truncated)"
        }
        return prettyString
    }
}
