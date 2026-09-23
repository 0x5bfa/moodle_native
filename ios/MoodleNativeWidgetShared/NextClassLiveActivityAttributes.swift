#if !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation

struct NextClassLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let title: String
        let room: String?
        let periodTitle: String
        let timeRangeText: String?
        let startDate: Date
        let endDate: Date?
    }

    let activityID: String
}

extension NextClassLiveActivityAttributes {
    static let nextClassActivityID = "next-class"
}
#endif
