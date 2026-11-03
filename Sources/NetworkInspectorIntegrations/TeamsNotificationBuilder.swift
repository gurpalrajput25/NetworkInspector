import Foundation
import NetworkInspectorCore
import NetworkInspectorPrivacy

public enum TeamsNotificationBuilder {

    public static func buildAdaptiveCard(
        transaction: NetworkTransaction,
        postmanDeepLink: String? = nil,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false
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

        // 1. 🚀 HERO HEADER CONTAINER (Immediate visual feedback)
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

        // 2. 📋 POSTMAN 1-CLICK cURL (Primary Action Box — zero editing needed)
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

        let postmanTitle = maskTokens ? "📋 Postman cURL (Masked)" : "📋 Postman cURL (1-Click Direct Import • Zero Editing)"
        let postmanSubtitle = maskTokens
            ? "⚠️ Tokens are masked for privacy. Replace [REDACTED] in Postman."
            : "⚡️ Active live token included. Ready for direct Postman execution with 0 manual adjustments."

        let postmanQuickGuide = """
        👉 **Instant Postman Import (2 Seconds):**
        1. Click **'Copy code'** on the top-right of the box above.
        2. In Postman: Paste directly into the **URL address bar** (`Cmd+V` / `Ctrl+V`) or click **Import → Raw text**.
        3. Method, URL, query params, headers, and authorization are 100% pre-configured. Just hit **Send**!
        """

        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": postmanTitle,
                    "weight": "Bolder",
                    "size": "Medium",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": postmanSubtitle,
                    "isSubtle": true,
                    "spacing": "None",
                    "wrap": true
                ],
                singleLineCodeBlock,
                [
                    "type": "TextBlock",
                    "text": postmanQuickGuide,
                    "isSubtle": true,
                    "spacing": "Small",
                    "wrap": true
                ]
            ]
        ])

        // 3. 🔍 FORMATTED MULTI-LINE cURL (For Terminal execution & code review)
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
                    "text": "Formatted with line breaks (\\) and --compressed for direct Terminal shell execution.",
                    "isSubtle": true,
                    "spacing": "None",
                    "wrap": true
                ],
                multiLineCodeBlock
            ]
        ])

        // 4. 📦 REQUEST PAYLOAD PEEK (if present)
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

        // 5. 📥 SERVER RESPONSE PEEK (Especially critical for 4xx/5xx debugging)
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

        // 6. 👤 AUTHENTICATED USER DETAILS SECTION (From live JWT)
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

        // 7. 📱 DEVICE & DIAGNOSTIC DETAILS
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

        // 8. 🧾 DEVELOPER / QA NOTE (if provided)
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

        // 9. FOOTER
        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "Generated via NetworkInspector SDK • Postman & Terminal Ready",
                    "isSubtle": true,
                    "wrap": true
                ]
            ]
        ])

        var card: [String: Any] = [
            "type": "AdaptiveCard",
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.5",
            "body": bodyItems
        ]

        if let link = postmanDeepLink, !link.isEmpty {
            card["actions"] = [
                [
                    "type": "Action.OpenUrl",
                    "title": "🚀 Open in Postman",
                    "url": link
                ]
            ]
        }

        return card
    }

    /// Wraps the Adaptive Card in a Teams Webhook message envelope.
    public static func buildMessagePayload(
        transaction: NetworkTransaction,
        postmanDeepLink: String? = nil,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        let card = buildAdaptiveCard(
            transaction: transaction,
            postmanDeepLink: postmanDeepLink,
            developerNote: developerNote,
            environmentName: environmentName,
            customUser: customUser,
            maskTokens: maskTokens
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
