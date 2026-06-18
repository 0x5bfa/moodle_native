import Foundation

public struct LmsAuthenticationSession: Codable, Equatable, Sendable {
    public let siteURL: String
    public let token: String
    public let privateToken: String?
    public let rawCallbackURL: String
    public let authenticatedAt: Date
    public let userID: Int?

    public init(
        siteURL: String,
        token: String,
        privateToken: String?,
        rawCallbackURL: String,
        authenticatedAt: Date,
        userID: Int? = nil
    ) {
        self.siteURL = siteURL
        self.token = token
        self.privateToken = privateToken
        self.rawCallbackURL = rawCallbackURL
        self.authenticatedAt = authenticatedAt
        self.userID = userID
    }

    public func withUserID(_ userID: Int) -> LmsAuthenticationSession {
        LmsAuthenticationSession(
            siteURL: siteURL,
            token: token,
            privateToken: privateToken,
            rawCallbackURL: rawCallbackURL,
            authenticatedAt: authenticatedAt,
            userID: userID
        )
    }
}
