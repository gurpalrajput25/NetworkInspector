import Foundation
import NetworkInspectorCore
import NetworkInspectorPrivacy

public enum TeamsNotificationBuilder {

    public static func buildAdaptiveCard(
        transaction: NetworkTransaction,
        developerNote: String? = nil,
        environmentName: String = "Development",
        customUser: JWTUserDetails? = nil
    ) -> [String: Any] {
        let note = developerNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let curlText = String(transaction.generateCurl(maskTokens: true).prefix(3500))
        let statusCode = transaction.response?.statusCode ?? 0
        let statusText = transaction.response?.statusDescription ?? (transaction.error != nil ? "Failed" : "Pending")
        let formattedDuration = transaction.formattedDuration

        // Extract User Details from JWT or provided fallback
        let userDetails = customUser ?? JWTDecoder.extractFromHeaders(transaction.request.headers)
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

        // 👤 Authenticated User Details Section (If JWT or user is present)
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
            }

            bodyItems.append([
                "type": "Container",
                "spacing": "Medium",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": "👤 Authenticated User (JWT Decoded)",
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

        // cURL Section
        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "📡 cURL (Copy & Execute)",
                    "weight": "Bolder",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": curlText,
                    "wrap": true,
                    "fontType": "Monospace",
                    "spacing": "Small"
                ]
            ]
        ])

        // How to use
        bodyItems.append([
            "type": "Container",
            "spacing": "Medium",
            "items": [
                [
                    "type": "TextBlock",
                    "text": "💡 How to Test",
                    "weight": "Bolder",
                    "wrap": true
                ],
                [
                    "type": "TextBlock",
                    "text": "• Copy the cURL above\n• Paste into Terminal or Postman (Import → Raw text)",
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
