import Foundation
import NetworkInspectorCore
import NetworkInspectorAnalytics

public struct TeamsAdaptiveCardBuilder {

    public struct DeviceDiagnostics {
        public let model: String
        public let osVersion: String
        public let appVersion: String
        public let timezone: String
        public let locale: String

        public init(
            model: String,
            osVersion: String,
            appVersion: String,
            timezone: String,
            locale: String
        ) {
            self.model = model
            self.osVersion = osVersion
            self.appVersion = appVersion
            self.timezone = timezone
            self.locale = locale
        }

        public static func current() -> DeviceDiagnostics {
            let info = DeviceDiagnosticInfo.current()
            return DeviceDiagnostics(
                model: info.deviceModel,
                osVersion: "\(info.systemName) \(info.systemVersion)",
                appVersion: "\(info.appName) v\(info.appVersion) (\(info.buildNumber))",
                timezone: info.timeZone,
                locale: info.locale
            )
        }
    }

    /// Constructs the reference Teams Adaptive Card payload adhering strictly to schema v1.4/1.5.
    public static func buildPayload(
        curlString: String,
        diagnostics: DeviceDiagnostics,
        developerNote: String?,
        userDetails: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        aiSuggestionReport: APISuggestionReport? = nil,
        requestAnalytics: RequestAnalytics? = nil
    ) -> [String: Any] {
        let codeFenceBlock = "```bash\n\(curlString)\n```"

        let curlTitle = maskTokens ? "📡 cURL (Masked)" : "📡 cURL (Live Token - Ready for Execution)"
        let curlSubtitle = maskTokens
            ? "⚠️ Tokens are masked for security."
            : "⚡ Active session token attached. Copy from the box below for direct Terminal or API client execution."

        var bodyElements: [[String: Any]] = []

        // 1. AI Suggestions & Standards Section (if available)
        if let ai = aiSuggestionReport {
            var aiContainerItems: [[String: Any]] = [
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
                        ["title": "Assessment:", "value": ai.statusSummary]
                    ]
                ],
                [
                    "type": "TextBlock",
                    "text": ai.summary,
                    "wrap": true,
                    "spacing": "Small"
                ]
            ]

            // Highlight top spotted mistakes
            if !ai.spottedMistakes.isEmpty {
                aiContainerItems.append([
                    "type": "TextBlock",
                    "text": "🔍 Spotted Mistakes & API Best Practice Violations:",
                    "weight": "Bolder",
                    "spacing": "Medium"
                ])

                for mistake in ai.spottedMistakes.prefix(4) {
                    let mistakeText = "**\(mistake.severity.emoji) \(mistake.title)**\n• *Why:* \(mistake.explanation)\n• *Fix:* `\(mistake.suggestedFix)`"
                    aiContainerItems.append([
                        "type": "TextBlock",
                        "text": mistakeText,
                        "wrap": true,
                        "spacing": "Small"
                    ])
                }
            }

            // Correct Request Syntax Box
            aiContainerItems.append(contentsOf: [
                [
                    "type": "TextBlock",
                    "text": "✨ Recommended Correct Request Syntax",
                    "weight": "Bolder",
                    "spacing": "Medium"
                ],
                [
                    "type": "TextBlock",
                    "text": "```bash\n\(ai.suggestedRequest.curl)\n```",
                    "wrap": true,
                    "fontType": "Monospace",
                    "spacing": "Small"
                ]
            ])

            // Correct Response Schema Box
            if let resBody = ai.suggestedResponse.body, !resBody.isEmpty {
                aiContainerItems.append(contentsOf: [
                    [
                        "type": "TextBlock",
                        "text": "✨ Recommended Response Schema (\(ai.suggestedResponse.schemaDescription))",
                        "weight": "Bolder",
                        "spacing": "Small"
                    ],
                    [
                        "type": "TextBlock",
                        "text": "```json\n\(String(resBody.prefix(800)))\n```",
                        "wrap": true,
                        "fontType": "Monospace",
                        "spacing": "None"
                    ]
                ])
            }

            bodyElements.append([
                "type": "Container",
                "style": "emphasis",
                "bleed": true,
                "spacing": "Medium",
                "items": aiContainerItems
            ])
        }

        // 2. Request Performance & Analytics Section (if available)
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

            bodyElements.append([
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

        // 3. Executable cURL Command
        bodyElements.append(contentsOf: [
            [
                "type": "TextBlock",
                "text": curlTitle,
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ],
            [
                "type": "TextBlock",
                "text": curlSubtitle,
                "isSubtle": true,
                "wrap": true,
                "spacing": "None"
            ],
            [
                "type": "Container",
                "style": "emphasis",
                "bleed": true,
                "items": [
                    [
                        "type": "TextBlock",
                        "text": codeFenceBlock,
                        "wrap": true,
                        "fontType": "Monospace"
                    ],
                    [
                        "type": "TextBlock",
                        "text": "📋 Quick-Copy Field (Cmd+A / Cmd+C):",
                        "isSubtle": true,
                        "size": "Small",
                        "spacing": "Small"
                    ],
                    [
                        "type": "Input.Text",
                        "id": "curlQuickCopy",
                        "isMultiline": true,
                        "value": curlString,
                        "spacing": "None"
                    ]
                ]
            ]
        ])

        // 4. Device Diagnostics
        bodyElements.append(contentsOf: [
            [
                "type": "TextBlock",
                "text": "📱 Client & Device Diagnostics",
                "weight": "Bolder",
                "size": "Default",
                "spacing": "Medium"
            ],
            [
                "type": "FactSet",
                "facts": [
                    ["title": "Device Model:", "value": diagnostics.model],
                    ["title": "OS Version:", "value": diagnostics.osVersion],
                    ["title": "App Version:", "value": diagnostics.appVersion],
                    ["title": "Timezone:", "value": diagnostics.timezone],
                    ["title": "Locale:", "value": diagnostics.locale]
                ]
            ]
        ])

        // 5. Authenticated User Details Section
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

            if !userFacts.isEmpty {
                bodyElements.append(contentsOf: [
                    [
                        "type": "TextBlock",
                        "text": "👤 Authenticated User Details",
                        "weight": "Bolder",
                        "size": "Default",
                        "spacing": "Medium"
                    ],
                    [
                        "type": "FactSet",
                        "facts": userFacts
                    ]
                ])
            }
        }

        // 6. Developer Note
        if let note = developerNote, !note.isEmpty {
            bodyElements.append(contentsOf: [
                [
                    "type": "TextBlock",
                    "text": "📝 Developer / QA Note",
                    "weight": "Bolder",
                    "spacing": "Medium"
                ],
                [
                    "type": "TextBlock",
                    "text": note,
                    "wrap": true
                ]
            ])
        }

        bodyElements.append([
            "type": "TextBlock",
            "text": "Generated via NetworkInspector SDK • AI Standards & Diagnostics",
            "isSubtle": true,
            "size": "Small",
            "spacing": "Large"
        ])

        let cardContent: [String: Any] = [
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": bodyElements
        ]

        return [
            "type": "message",
            "attachments": [
                [
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": cardContent
                ]
            ]
        ]
    }

    /// Convenience overload to construct the payload directly from a `NetworkTransaction`.
    public static func buildPayload(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        userDetails: JWTUserDetails? = nil,
        maskTokens: Bool = false,
        includeAISuggestions: Bool = true,
        includeAnalytics: Bool = true
    ) -> [String: Any] {
        let curl = CurlFormatter.format(transaction: transaction, maskTokens: maskTokens)
        let diagnostics = DeviceDiagnostics.current()

        var resolvedUser = userDetails
            ?? transaction.userDetails
            ?? JWTDecoder.extractFromHeaders(transaction.request.rawHeaders)
            ?? JWTDecoder.extractFromHeaders(transaction.request.headers)

        if let queryOrg = transaction.request.queryItems["organizer_id"], !queryOrg.isEmpty {
            if let user = resolvedUser {
                if user.organizerId == nil {
                    resolvedUser = JWTUserDetails(
                        userId: user.userId,
                        email: user.email,
                        name: user.name,
                        role: user.role,
                        organizerId: queryOrg,
                        expirationDate: user.expirationDate,
                        issuedAt: user.issuedAt,
                        rawPayload: user.rawPayload
                    )
                }
            } else {
                resolvedUser = JWTUserDetails(organizerId: queryOrg)
            }
        }

        let aiReport = includeAISuggestions ? APISuggestionEngine.analyze(transaction: transaction) : nil
        let analytics = includeAnalytics ? RequestAnalyticsBuilder.build(for: transaction) : nil

        return buildPayload(
            curlString: curl,
            diagnostics: diagnostics,
            developerNote: developerNote,
            userDetails: resolvedUser,
            maskTokens: maskTokens,
            aiSuggestionReport: aiReport,
            requestAnalytics: analytics
        )
    }

    /// Backward compatibility overload
    public static func buildPayload(
        curlString: String,
        diagnostics: DeviceDiagnostics,
        postmanDeepLink: String?,
        developerNote: String?,
        userDetails: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        buildPayload(
            curlString: curlString,
            diagnostics: diagnostics,
            developerNote: developerNote,
            userDetails: userDetails,
            maskTokens: maskTokens,
            aiSuggestionReport: nil,
            requestAnalytics: nil
        )
    }

    /// Backward compatibility overload with postmanDeepLink ignored
    public static func buildPayload(
        transaction: NetworkTransaction,
        postmanDeepLink: String?,
        developerNote: String? = nil,
        userDetails: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        buildPayload(
            transaction: transaction,
            developerNote: developerNote,
            userDetails: userDetails,
            maskTokens: maskTokens,
            includeAISuggestions: true,
            includeAnalytics: true
        )
    }
}
