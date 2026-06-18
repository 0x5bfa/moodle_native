import Foundation

struct CachedTimetableSnapshot: Codable, Equatable, Sendable {
    let siteURL: String
    let authenticatedAt: Date
    let lastUpdatedAt: Date
    let courses: [CachedCourseRecord]
}
