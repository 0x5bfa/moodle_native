import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeNetworking

@Observable
@MainActor
final class ForumDiscussionsViewModel: LoadableObject {
    private(set) var discussions: [LmsWebServiceClient.ForumDiscussion] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let forumID: Int
    private let logContext: LmsRequestLogContext
    private var loadedSession: LmsAuthenticationSession?
    private var hasLoaded = false
    private var loadGeneration = 0

    init(forumID: Int, pageTitle: String, navigationPath: String) {
        self.forumID = forumID
        self.logContext = LmsRequestLogContext(navigationPath: navigationPath, pageTitle: pageTitle)
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
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
            let discussions = try await LmsWebServiceClient.logged(session: session, context: logContext)
                .fetchForumDiscussions(forumID: forumID)

            guard generation == loadGeneration else {
                return
            }

            self.discussions = discussions
            loadedSession = session
            hasLoaded = true
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
        discussions = []
        isLoading = false
        errorMessage = nil
        loadedSession = nil
        hasLoaded = false
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

        return String(localized: "forumDiscussions.error.fetchFailed")
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
