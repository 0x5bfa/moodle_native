import Foundation

public enum LmsAuthenticationCallbackParser {
    public static func parse(
        callbackURL: URL,
        fallbackSiteURL: URL,
        authenticatedAt: Date = .now
    ) throws -> LmsAuthenticationSession {
        try parse(
            rawCallbackURLString: callbackURL.absoluteString,
            fallbackSiteURL: fallbackSiteURL,
            authenticatedAt: authenticatedAt
        )
    }

    public static func parse(
        rawCallbackURLString: String,
        fallbackSiteURL: URL,
        authenticatedAt: Date = .now
    ) throws -> LmsAuthenticationSession {
        let rawCustomURL = trimCustomURL(rawCallbackURLString)
        guard rawCustomURL.isEmpty == false else {
            throw LmsAuthenticationCallbackError.missingCallbackURL
        }

        if rawCustomURL.contains("://token=") {
            return try parseLegacy(
                rawCustomURL: rawCustomURL,
                fallbackSiteURL: fallbackSiteURL,
                authenticatedAt: authenticatedAt
            )
        }

        guard let callbackURL = URL(string: rawCustomURL) else {
            throw LmsAuthenticationCallbackError.invalidCallbackURL
        }

        return try parseDirect(
            callbackURL: callbackURL,
            rawCustomURL: rawCustomURL,
            fallbackSiteURL: fallbackSiteURL,
            authenticatedAt: authenticatedAt
        )
    }

    private static func parseLegacy(
        rawCustomURL: String,
        fallbackSiteURL: URL,
        authenticatedAt: Date
    ) throws -> LmsAuthenticationSession {
        let parts = rawCustomURL.components(separatedBy: "://token=")
        guard parts.count == 2, parts[1].isEmpty == false else {
            throw LmsAuthenticationCallbackError.invalidLegacyToken
        }

        var normalized = percentDecode(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        if normalized.count % 4 != 0 {
            normalized += String(repeating: "=", count: 4 - (normalized.count % 4))
        }

        guard
            let decodedData = Data(base64Encoded: normalized),
            let decodedPayload = String(data: decodedData, encoding: .utf8)
        else {
            throw LmsAuthenticationCallbackError.invalidLegacyToken
        }

        let payloadParts = decodedPayload.components(separatedBy: ":::")
        guard payloadParts.count >= 2 else {
            throw LmsAuthenticationCallbackError.invalidLegacyToken
        }

        let token = payloadParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.isEmpty == false else {
            throw LmsAuthenticationCallbackError.invalidLegacyToken
        }

        let privateToken =
            payloadParts.count >= 3
            ? optionalString(payloadParts[2])
            : nil

        return LmsAuthenticationSession(
            siteURL: normalizeSiteURL(fallbackSiteURL.absoluteString),
            token: token,
            privateToken: privateToken,
            rawCallbackURL: rawCustomURL,
            authenticatedAt: authenticatedAt
        )
    }

    private static func parseDirect(
        callbackURL: URL,
        rawCustomURL: String,
        fallbackSiteURL: URL,
        authenticatedAt: Date
    ) throws -> LmsAuthenticationSession {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw LmsAuthenticationCallbackError.invalidCallbackURL
        }

        let token = firstNonEmptyQueryValue(named: ["token"], in: components.queryItems)
        guard let token, token.isEmpty == false else {
            throw LmsAuthenticationCallbackError.missingToken
        }

        let privateToken = firstNonEmptyQueryValue(
            named: ["privatetoken", "privateToken"], in: components.queryItems)
        let siteURL = try deriveSiteURL(from: callbackURL, fallbackSiteURL: fallbackSiteURL)

        return LmsAuthenticationSession(
            siteURL: siteURL,
            token: token,
            privateToken: privateToken,
            rawCallbackURL: rawCustomURL,
            authenticatedAt: authenticatedAt
        )
    }

    private static func deriveSiteURL(from callbackURL: URL, fallbackSiteURL: URL) throws -> String {
        guard
            let fallbackComponents = URLComponents(url: fallbackSiteURL, resolvingAgainstBaseURL: false),
            let scheme = optionalString(fallbackComponents.scheme),
            let host = optionalString(callbackURL.host)
        else {
            throw LmsAuthenticationCallbackError.invalidCallbackURL
        }

        var value = "\(scheme)://\(host)"
        if let port = callbackURL.port {
            value += ":\(port)"
        }

        let trimmedPath = callbackURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.isEmpty == false {
            value += "/\(trimmedPath)"
        }

        return normalizeSiteURL(value)
    }

    private static func firstNonEmptyQueryValue(
        named names: [String],
        in items: [URLQueryItem]?
    ) -> String? {
        guard let items else {
            return nil
        }

        for name in names {
            if let value = items.first(where: { $0.name == name })?.value.flatMap(optionalString) {
                return value
            }
        }

        return nil
    }

    private static func optionalString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            trimmed.isEmpty == false
        else {
            return nil
        }

        return trimmed
    }

    private static func normalizeSiteURL(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    private static func percentDecode(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private static func trimCustomURL(_ rawValue: String) -> String {
        var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        while let lastCharacter = trimmed.last, lastCharacter == "/" || lastCharacter == "#" {
            trimmed.removeLast()
        }
        return trimmed
    }
}
