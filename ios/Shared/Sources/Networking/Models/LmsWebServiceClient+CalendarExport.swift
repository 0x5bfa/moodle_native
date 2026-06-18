import Foundation

extension LmsWebServiceClient {
    public struct CalendarExportTokenResponse: Decodable, Equatable, Sendable {
        public let token: String
    }

    public struct CalendarSubscription: Equatable, Sendable {
        public enum EventPreset: String, CaseIterable, Sendable {
            case all
            case user
            case groups
            case courses
            case categories
        }

        public enum TimePreset: String, CaseIterable, Sendable {
            case weekNow = "weeknow"
            case weekNext = "weeknext"
            case monthNow = "monthnow"
            case monthNext = "monthnext"
            case recentUpcoming = "recentupcoming"
        }

        public let url: URL

        public var webcalURL: URL {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return url
            }

            components.scheme = "webcal"
            return components.url ?? url
        }
    }
}
