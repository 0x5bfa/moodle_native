import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking

@Observable
@MainActor
final class NotificationsViewModel: LoadableObject {
    private let logContext = LmsRequestLogContext(
        navigationPath: String(localized: "navigationPath.notifications"),
        pageTitle: String(localized: "tab.notifications")
    )
    private(set) var notifications: [NotificationListItem] = []
    private(set) var unreadCount = 0
    private(set) var isLoading = false
    private(set) var isMarkingNotificationsRead = false
    private(set) var errorMessage: String?
    private(set) var lmsErrorMessage: String?
    private(set) var lastUpdatedAt: Date?

    private var loadedSession: LmsAuthenticationSession?
    private var hasLoaded = false
    private var loadGeneration = 0
    private var inFlightReadNotificationIDs = Set<Int>()
    private var isLoadingLiveData = false
    private let cacheStore: LmsNotificationsCacheStore
    private var lmsNotifications: [LmsNotificationItem] = []

    init(cacheStore: LmsNotificationsCacheStore? = nil) {
        self.cacheStore = cacheStore ?? LmsNotificationsCacheStore()
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        await loadCachedDataIfNeeded(session: session)
        await load(session: session, forceRefresh: true)
    }

    func refresh(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        await load(session: session, forceRefresh: true)
    }

    func markAsRead(_ notification: NotificationListItem, session: LmsAuthenticationSession?) async {
        guard notification.isUnread,
            let session,
            let notificationID = notification.lmsNotificationID
        else {
            return
        }

        await markLmsNotificationAsRead(notificationID: notificationID, session: session)
    }

    private func markLmsNotificationAsRead(notificationID: Int, session: LmsAuthenticationSession) async {
        guard inFlightReadNotificationIDs.insert(notificationID).inserted else {
            return
        }
        defer {
            inFlightReadNotificationIDs.remove(notificationID)
        }

        do {
            let client = LmsWebServiceClient.logged(session: session, context: logContext)
            try await client.markNotificationRead(notificationID: notificationID)
            applyMarkedAsRead(notificationID: notificationID)
            unreadCount = try await client.fetchUnreadNotificationCount()
            saveCacheIfPossible(for: session)
        } catch {
            if Self.isCancellation(error) {
                return
            }

            errorMessage = Self.message(for: error)
        }
    }

    func markAsRead(_ selectedNotifications: [NotificationListItem], session: LmsAuthenticationSession?) async {
        let notificationIDs = selectedNotifications.compactMap { notification -> Int? in
            guard notification.isUnread, let notificationID = notification.lmsNotificationID else {
                return nil
            }

            return notificationID
        }

        guard let session, notificationIDs.isEmpty == false else {
            return
        }

        isMarkingNotificationsRead = true
        defer {
            isMarkingNotificationsRead = false
        }

        var lastError: Error?
        let client = LmsWebServiceClient.logged(session: session, context: logContext)
        for notificationID in notificationIDs {
            guard inFlightReadNotificationIDs.insert(notificationID).inserted else {
                continue
            }

            do {
                try await client.markNotificationRead(notificationID: notificationID)
                applyMarkedAsRead(notificationID: notificationID)
            } catch {
                if Self.isCancellation(error) {
                    inFlightReadNotificationIDs.remove(notificationID)
                    return
                }

                lastError = error
            }

            inFlightReadNotificationIDs.remove(notificationID)
        }

        do {
            unreadCount = try await client.fetchUnreadNotificationCount()
            saveCacheIfPossible(for: session)
        } catch {
            if Self.isCancellation(error) {
                return
            }

            lastError = error
        }

        if let lastError {
            errorMessage = Self.message(for: lastError)
        }
    }

    func markAllLmsNotificationsAsRead(session: LmsAuthenticationSession?) async {
        guard let session, unreadCount > 0 else {
            return
        }

        isMarkingNotificationsRead = true
        defer {
            isMarkingNotificationsRead = false
        }

        do {
            let client = LmsWebServiceClient.logged(session: session, context: logContext)
            try await client.markAllNotificationsRead()
            applyAllLmsNotificationsAsRead()
            unreadCount = try await client.fetchUnreadNotificationCount()
            saveCacheIfPossible(for: session)
        } catch {
            if Self.isCancellation(error) {
                return
            }

            errorMessage = Self.message(for: error)
        }
    }

    private func loadCachedDataIfNeeded(session: LmsAuthenticationSession) async {
        if loadedSession == session, hasLoaded {
            return
        }

        do {
            guard let cachedSnapshot = try cacheStore.load(for: session) else {
                return
            }

            applyCachedSnapshot(cachedSnapshot, session: session)
        } catch {
            try? cacheStore.delete()
        }
    }

    private func load(
        session: LmsAuthenticationSession,
        forceRefresh: Bool = false
    ) async {
        guard forceRefresh || hasLoaded == false || loadedSession != session else {
            return
        }
        guard isLoadingLiveData == false else {
            return
        }
        isLoadingLiveData = true
        defer {
            isLoadingLiveData = false
        }

        let generation = loadGeneration + 1
        loadGeneration = generation
        if notifications.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            let client = LmsWebServiceClient.logged(session: session, context: logContext)
            async let notificationResponse = client.fetchPopupNotifications()
            async let unreadNotificationCount = client.fetchUnreadNotificationCount()
            let (response, unreadCount) = try await (notificationResponse, unreadNotificationCount)
            let updatedAt = Date.now
            let nextNotifications = response.notifications
                .filter { $0.deleted == false }
                .map(LmsNotificationItem.lms)

            guard generation == loadGeneration else {
                return
            }

            lmsNotifications = nextNotifications
            rebuildNotifications()
            self.unreadCount = unreadCount
            loadedSession = session
            hasLoaded = true
            lastUpdatedAt = updatedAt
            isLoading = false
            lmsErrorMessage = nil
            try? cacheStore.save(
                notifications: nextNotifications,
                unreadCount: unreadCount,
                lastUpdatedAt: updatedAt,
                for: session
            )
        } catch {
            guard generation == loadGeneration else {
                return
            }

            if Self.isCancellation(error) {
                isLoading = false
                return
            }

            if loadedSession != session {
                lmsNotifications = []
                rebuildNotifications()
            }
            isLoading = false
            lmsErrorMessage = Self.message(for: error)
            errorMessage = Self.message(for: error)
        }
    }

    private func reset() {
        loadGeneration += 1
        lmsNotifications = []
        notifications = []
        unreadCount = 0
        isLoading = false
        isMarkingNotificationsRead = false
        errorMessage = nil
        lmsErrorMessage = nil
        loadedSession = nil
        hasLoaded = false
        lastUpdatedAt = nil
        inFlightReadNotificationIDs = []
        isLoadingLiveData = false
    }

    private func applyCachedSnapshot(
        _ snapshot: CachedNotificationsSnapshot,
        session: LmsAuthenticationSession
    ) {
        lmsNotifications = snapshot.notifications.map(\.notification)
        rebuildNotifications()
        unreadCount = snapshot.unreadCount
        loadedSession = session
        hasLoaded = true
        lastUpdatedAt = snapshot.lastUpdatedAt
        isLoading = false
        errorMessage = nil
        lmsErrorMessage = nil
    }

    private func saveCacheIfPossible(for session: LmsAuthenticationSession) {
        try? cacheStore.save(
            notifications: lmsNotifications,
            unreadCount: unreadCount,
            lastUpdatedAt: lastUpdatedAt ?? .now,
            for: session
        )
    }

    private func applyMarkedAsRead(notificationID: Int) {
        var didUpdateNotification = false

        lmsNotifications = lmsNotifications.map { notification in
            guard notification.lmsNotificationID == notificationID, notification.isUnread else {
                return notification
            }

            didUpdateNotification = true

            return copy(notification, isUnread: false)
        }

        if didUpdateNotification {
            rebuildNotifications()
        }
    }

    private func applyAllLmsNotificationsAsRead() {
        guard lmsNotifications.contains(where: \.isUnread) else {
            return
        }

        lmsNotifications = lmsNotifications.map { notification in
            copy(notification, isUnread: false)
        }
        rebuildNotifications()
    }

    private func copy(_ notification: LmsNotificationItem, isUnread: Bool) -> LmsNotificationItem {
        LmsNotificationItem(
            id: notification.id,
            lmsNotificationID: notification.lmsNotificationID,
            source: notification.source,
            title: notification.title,
            preview: notification.preview,
            plainBody: notification.plainBody,
            fullMessage: notification.fullMessage,
            htmlBody: notification.htmlBody,
            receivedAt: notification.receivedAt,
            isUnread: isUnread,
            isImportant: notification.isImportant,
            externalURL: notification.externalURL,
            component: notification.component,
            eventType: notification.eventType,
            contextName: notification.contextName
        )
    }

    private func rebuildNotifications() {
        notifications = lmsNotifications
            .map(NotificationListItem.init(lms:))
            .sorted { $0.receivedAt > $1.receivedAt }
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

        return String(localized: "notifications.error.fetchFailed")
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
