import Foundation
import MoodleNativeCore

@MainActor
protocol LoadableObject {
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func loadIfNeeded(session: LmsAuthenticationSession?) async
    func refresh(session: LmsAuthenticationSession?) async
}
