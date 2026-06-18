import Foundation

extension LmsWebServiceClient {
    public struct DashboardSnapshot: Equatable, Sendable {
        public let siteURL: String
        public let userID: Int?
        public let courses: [Course]
        public let dashboardBlocks: [DashboardBlock]
    }
}
