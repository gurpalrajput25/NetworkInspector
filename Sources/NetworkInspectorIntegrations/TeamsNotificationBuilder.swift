import Foundation
import NetworkInspectorCore
import NetworkInspectorPrivacy

public enum TeamsNotificationBuilder {

    public static func buildAdaptiveCard(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        let note = developerNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let multiLineCurl = String(transaction.generateCurl(maskTokens: maskTokens, singleLine: false).prefix(3500))
        let singleLineCurl = String(transaction.generateCurl(maskTokens: maskTokens, singleLine: true).prefix(3500))
        let statusCode = transaction.response?.statusCode ?? 0
        let statusText = transaction.response?.statusDescription ?? (transaction.error != nil ? "Failed" : "Pending")
        let formattedDuration = transaction.formattedDuration

        // Extract User Details from custom, transaction, or headers
        let userDetails = customUser
            ?? transaction.userDetails
            ?? JWTDecoder.extractFromHeaders(transaction.request.rawHeaders)
            ?? JWTDecoder.extractFromHeaders(transaction.request.headers)
        let device = DeviceDiagnosticInfo.current()

        var facts: [[String: String]] = [
            ["title": "Method & Path:", "value": "\(transaction.request.rawMethod) \(transaction.request.path)"],
            ["title": "Status:", "value": "\(statusCode) (\(statusText))"],
            ["title": "Duration:", "value": formattedDuration],
            ["title": "Host:", "value": transaction.request.host],
            ["title": "Environment:", "value": environmentName],
            ["title": "Client Source:", "value": transaction.clientSource]
        ]

        if let err = transaction.error {
            facts.append(["title": "Error:", "value": err.localizedDescription])
        }

        var bodyItems: [[String: Any]] = [
            // Header Container
            [
                "type": "Container",
                "style": "emphasis",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": "🚀 NetworkInspector • Trace Report",
                        "weight": "Bolder",
                        "size": "Large",
                        "wrap": true
                    ],
                    [
                        "type": "TextBlock",
                        "text": "Captured Network Diagnostic & cURL",
                        "isSubtle": true,
                        "spacing": "None",
                        "wrap": true
                    ]
                ]
            ],
            // Request Meta FactSet
            [
                "type": "FactSet",
                "spacing": "Medium",
                "facts": facts
            ]
        ]

        // 👤 Authenticated User Details Section
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

            // Fallback for custom fields if standard fields were empty
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
                            "text": "👤 Authenticated User Details",
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
        } else {
            bodyItems.append([
                "type": "Container",
                "spacing": "Medium",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": "👤 Authenticated User",
                        "weight": "Bolder",
                        "wrap": true
                    ],
                    [
                        "type": "TextBlock",
                        "text": "No authenticated user detected. Set via NetworkInspector.setLoggedInUser(...) or pass Bearer token in request headers.",
                        "isSubtle": true,
                        "wrap": true
                    ]
                ]
            ])
        }

        // 📱 Device Diagnostics Section
        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "📱 Device Diagnostics",
                    "weight": "Bolder",
                    "wrap": true
                ],
                [
                    "type": "FactSet",
                    "spacing": "Small",
                    "facts": [
                        ["title": "Device Model:", "value": device.deviceModel],
                        ["title": "OS Version:", "value": "\(device.systemName) \(device.systemVersion)"],
                        ["title": "App Version:", "value": "\(device.appName) \(device.appVersion) (\(device.buildNumber))"],
                        ["title": "Timezone:", "value": device.timeZone],
                        ["title": "Locale:", "value": device.locale]
                    ]
                ]
            ]
        ])

        // Developer Note Section
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

        // cURL Section (With Live Token / Masked state)
        let curlTitle = maskTokens ? "📡 cURL (Masked)" : "📡 cURL (Live Token - Ready for Postman)"
        let curlSubtitle = maskTokens
            ? "Sensitive tokens are masked for security."
            : "⚡️ Contains active unmasked token. Click 'Copy' on the code block to import directly into Postman or Terminal."

        let multiLineCode = "```bash\n\(multiLineCurl)\n```"
        let singleLineCode = "```bash\n\(singleLineCurl)\n```"

        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": curlTitle,
                    "weight": "Bolder",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": curlSubtitle,
                    "isSubtle": true,
                    "spacing": "None",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": multiLineCode,
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": "📋 1-Line cURL (Guaranteed 1-Click Import — no line breaks or shell escaping):",
                    "weight": "Bolder",
                    "spacing": "Small",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": singleLineCode,
                    "wrap": true
                ]
            ]
        ])

        // How to use in Postman
        let testInstructions = maskTokens
            ? "• Copy the 1-Line cURL above\n• Replace [REDACTED] tokens with active credentials\n• Run in Terminal or Postman"
            : "• Copy either cURL code box above\n• In Postman: File → Import → Raw text → Paste and Send\n• Tip: Use the 1-Line cURL if copying across devices to avoid accidental newline wrapping"

        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "💡 How to Test in Postman",
                    "weight": "Bolder",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": testInstructions,
                    "wrap": true
                ]
            ]
        ])

        // Footer
        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "Generated via NetworkInspector SDK",
                    "isSubtle": true,
                    "wrap": true
                ]
            ]
        ])

        let card: [String: Any] = [
            "type": "AdaptiveCard",
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.5",
            "body": bodyItems
        ]

        return card
    }
}
