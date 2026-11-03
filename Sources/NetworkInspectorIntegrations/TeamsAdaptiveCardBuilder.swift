import Foundation
import NetworkInspectorCore

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

    /// Constructs the reference Teams Adaptive Card payload adhering strictly to schema v1.4 with Action.OpenUrl.
    public static func buildPayload(
        curlString: String,
        diagnostics: DeviceDiagnostics,
        postmanDeepLink: String?,
        developerNote: String?,
        userDetails: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        var actions: [[String: Any]] = []

        let effectiveLink = (postmanDeepLink?.isEmpty == false)
            ? postmanDeepLink!
            : PostmanLinkBuilder.buildImportLink(curlString: curlString)

        actions.append([
            "type": "Action.OpenUrl",
            "title": "🚀 Open in Postman",
            "url": effectiveLink
        ])

        let helperLink = PostmanLinkBuilder.buildImportLink(curlString: curlString)
        if effectiveLink != helperLink {
            actions.append([
                "type": "Action.OpenUrl",
                "title": "📋 Copy cURL (Web)",
                "url": helperLink
            ])
        }

        let codeFenceBlock = "```bash\n\(curlString)\n```"

        let curlTitle = maskTokens ? "📡 cURL (Masked)" : "📡 cURL (Live Token - Ready for Postman)"
        let curlSubtitle = maskTokens
            ? "⚠️ Tokens are masked for security."
            : "⚡ Active session token attached. Click [🚀 Open in Postman] to auto-copy & launch, or copy from the box below."

        var bodyElements: [[String: Any]] = [
            [
                "type": "TextBlock",
                "text": curlTitle,
                "weight": "Bolder",
                "size": "Medium"
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
                        "text": "📋 Quick-Copy Field (Click inside & press Cmd+A / Cmd+C):",
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
            ],
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
        ]

        // Authenticated User Details Section (if active session / JWT / profile is present)
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

            // Fallback for custom JWT claims if standard profile was sparse
            if userFacts.count <= 2 {
                for (k, v) in user.rawPayload where !["exp", "iat", "nbf", "jti", "user_id", "sub", "email", "name", "role", "organizer_id"].contains(k) {
                    userFacts.append(["title": "\(k):", "value": v])
                }
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
            "text": "Generated via NetworkInspector SDK • Postman & Terminal Ready",
            "isSubtle": true,
            "size": "Small",
            "spacing": "Large"
        ])

        let cardContent: [String: Any] = [
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "type": "AdaptiveCard",
            "version": "1.4",
            "body": bodyElements,
            "actions": actions
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
        postmanDeepLink: String? = nil,
        developerNote: String? = nil,
        userDetails: JWTUserDetails? = nil,
        maskTokens: Bool = false
    ) -> [String: Any] {
        let curl = CurlFormatter.format(transaction: transaction, maskTokens: maskTokens)
        let diagnostics = DeviceDiagnostics.current()

        // Resolve user details from parameter, transaction, or headers
        var resolvedUser = userDetails
            ?? transaction.userDetails
            ?? JWTDecoder.extractFromHeaders(transaction.request.rawHeaders)
            ?? JWTDecoder.extractFromHeaders(transaction.request.headers)

        // If organizerId is missing in user, inherit from URL query items if present
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

        let effectiveDeepLink = (postmanDeepLink?.isEmpty == false)
            ? postmanDeepLink
            : PostmanLinkBuilder.buildImportLink(curlString: curl, transaction: transaction)

        return buildPayload(
            curlString: curl,
            diagnostics: diagnostics,
            postmanDeepLink: effectiveDeepLink,
            developerNote: developerNote,
            userDetails: resolvedUser,
            maskTokens: maskTokens
        )
    }
}
