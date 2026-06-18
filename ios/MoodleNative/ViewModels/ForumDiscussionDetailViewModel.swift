import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking

@Observable
@MainActor
final class ForumDiscussionDetailViewModel: LoadableObject {
    private(set) var posts: [LmsWebServiceClient.ForumPost] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let discussionID: Int
    private let logContext: LmsRequestLogContext
    private var loadedSession: LmsAuthenticationSession?
    private var hasLoaded = false
    private var loadGeneration = 0
    private var hasMarkedViewedDiscussion = false

    init(discussionID: Int, pageTitle: String, navigationPath: String) {
        self.discussionID = discussionID
        self.logContext = LmsRequestLogContext(navigationPath: navigationPath, pageTitle: pageTitle)
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        if loadedSession != session {
            hasMarkedViewedDiscussion = false
        }

        guard hasLoaded == false || loadedSession != session else {
            return
        }

        await load(session: session)
    }

    func refresh(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        await load(session: session, forceRefresh: true)
    }

    var discussionURL: URL? {
        posts.first?.urls.discussURL
    }

    private func load(
        session: LmsAuthenticationSession,
        forceRefresh: Bool = false
    ) async {
        guard forceRefresh || hasLoaded == false || loadedSession != session else {
            return
        }

        let generation = loadGeneration + 1
        loadGeneration = generation
        isLoading = true
        errorMessage = nil

        do {
            let client = LmsWebServiceClient.logged(session: session, context: logContext)

            if hasMarkedViewedDiscussion == false {
                try await client.markForumDiscussionViewed(discussionID: discussionID)
            }

            let posts = try await client.fetchDiscussionPosts(discussionID: discussionID)
            guard generation == loadGeneration else {
                return
            }

            self.posts = posts
            loadedSession = session
            hasLoaded = true
            hasMarkedViewedDiscussion = true
            isLoading = false
        } catch {
            guard generation == loadGeneration else {
                return
            }

            if Self.isCancellation(error) {
                isLoading = false
                return
            }

            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    private func reset() {
        loadGeneration += 1
        posts = []
        isLoading = false
        errorMessage = nil
        loadedSession = nil
        hasLoaded = false
        hasMarkedViewedDiscussion = false
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty == false {
            return description
        }

        return String(localized: "forumDiscussionDetail.error.fetchFailed")
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
    }
}
