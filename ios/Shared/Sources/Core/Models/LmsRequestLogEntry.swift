import Foundation

public struct LmsRequestLogContext: Codable, Equatable, Sendable {
    public let navigationPath: String
    public let pageTitle: String

    public init(navigationPath: String, pageTitle: String) {
        self.navigationPath = navigationPath
        self.pageTitle = pageTitle
    }
}

public struct LmsRequestLogEntry: Codable, Identifiable, Equatable, Sendable {
    public struct Parameter: Codable, Equatable, Sendable {
        public let name: String
        public let value: String?

        public init(name: String, value: String?) {
            self.name = name
            self.value = value
        }

        public var displayText: String {
            if let value {
                return "\(name)=\(value)"
            }

            return "\(name)=<nil>"
        }
    }

    public let id: UUID
    public let occurredAt: Date
    public let context: LmsRequestLogContext
    public let wsFunction: String
    public let parameters: [Parameter]
    public let statusCode: Int?
    public let errorMessage: String?
    public let responseBody: String

    public init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        context: LmsRequestLogContext,
        wsFunction: String,
        parameters: [Parameter],
        statusCode: Int?,
        errorMessage: String?,
        responseBody: String
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.context = context
        self.wsFunction = wsFunction
        self.parameters = parameters
        self.statusCode = statusCode
        self.errorMessage = errorMessage
        self.responseBody = responseBody
    }

    public var hasError: Bool {
        errorMessage != nil || statusCode.map { 200..<300 ~= $0 } == false
    }

    public var metadataText: String {
        var lines = [
            "path: \(context.navigationPath)",
            "title: \(context.pageTitle)",
            "wsfunction: \(wsFunction)",
        ]

        if parameters.isEmpty == false {
            lines.append("parameters:")
            lines.append(contentsOf: parameters.map { "  - \($0.displayText)" })
        }

        if let statusCode {
            lines.append("status: \(statusCode)")
        }

        if let errorMessage, errorMessage.isEmpty == false {
            lines.append("error: \(errorMessage)")
        }

        return lines.joined(separator: "\n")
    }

    public var displayText: String {
        if responseBody.isEmpty {
            return "\(metadataText)\n\n<empty response>"
        }

        return "\(metadataText)\n\n\(responseBody)"
    }
}
