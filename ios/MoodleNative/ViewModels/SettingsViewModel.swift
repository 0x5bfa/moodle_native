import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private(set) var activeAlert: SettingsAlert?
    private(set) var hasHiddenAssignments: Bool

    private let assignmentsCacheStore: AssignmentsCacheStore
    private let timetableCacheStore: TimetableCacheStore
    private let notificationsCacheStore: LmsNotificationsCacheStore
    private let hiddenAssignmentsStore: HiddenAssignmentsStore
    private let bundle: Bundle

    var isShowingAlert: Bool {
        get { activeAlert != nil }
        set {
            if newValue == false {
                dismissAlert()
            }
        }
    }

    convenience init() {
        self.init(
            assignmentsCacheStore: AssignmentsCacheStore(),
            timetableCacheStore: TimetableCacheStore(),
            notificationsCacheStore: LmsNotificationsCacheStore(),
            hiddenAssignmentsStore: HiddenAssignmentsStore(),
            bundle: .main
        )
    }

    init(
        assignmentsCacheStore: AssignmentsCacheStore,
        timetableCacheStore: TimetableCacheStore,
        notificationsCacheStore: LmsNotificationsCacheStore,
        hiddenAssignmentsStore: HiddenAssignmentsStore,
        bundle: Bundle
    ) {
        self.assignmentsCacheStore = assignmentsCacheStore
        self.timetableCacheStore = timetableCacheStore
        self.notificationsCacheStore = notificationsCacheStore
        self.hiddenAssignmentsStore = hiddenAssignmentsStore
        self.bundle = bundle
        hasHiddenAssignments = hiddenAssignmentsStore.load().isEmpty == false
    }

    var appVersionDescription: String {
        let info = bundle.infoDictionary ?? [:]
        let appName =
            (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? AppSettings.AppIdentity.displayName
        let version = (info["CFBundleShortVersionString"] as? String) ?? "-"
        let build = (info["CFBundleVersion"] as? String) ?? "-"
        return "\(appName) \(version) (\(build))"
    }

    func refreshHiddenAssignmentsState() {
        hasHiddenAssignments = hiddenAssignmentsStore.load().isEmpty == false
    }

    func dismissAlert() {
        activeAlert = nil
    }

    func presentCacheDeletionConfirmation() {
        activeAlert = .cacheDeletionConfirmation
    }

    func clearCaches() {
        do {
            try assignmentsCacheStore.delete()
            try timetableCacheStore.delete()
            try notificationsCacheStore.delete()
            activeAlert = .result(
                SettingsActionResult(
                    title: String(localized: "settings.alert.cacheDeletionSucceeded.title"),
                    message: String(localized: "settings.alert.cacheDeletionSucceeded.message")
                )
            )
        } catch {
            activeAlert = .result(
                SettingsActionResult(
                    title: String(localized: "settings.alert.cacheDeletionFailed.title"),
                    message: error.localizedDescription
                )
            )
        }
    }

    func unhideAllAssignments() {
        hiddenAssignmentsStore.delete()
        hasHiddenAssignments = false
        activeAlert = .result(
            SettingsActionResult(
                title: String(localized: "settings.alert.unhideAssignmentsSucceeded.title"),
                message: String(localized: "settings.alert.unhideAssignmentsSucceeded.message")
            )
        )
    }
}

struct SettingsActionResult: Identifiable {
    let title: String
    let message: String

    var id: String {
        title + message
    }
}

enum SettingsAlert: Identifiable {
    case cacheDeletionConfirmation
    case result(SettingsActionResult)

    var id: String {
        switch self {
        case .cacheDeletionConfirmation:
            return "cacheDeletionConfirmation"
        case .result(let result):
            return result.id
        }
    }

    var title: String {
        switch self {
        case .cacheDeletionConfirmation:
            return String(localized: "settings.alert.cacheDeletionConfirmation.title")
        case .result(let result):
            return result.title
        }
    }

    var message: String {
        switch self {
        case .cacheDeletionConfirmation:
            return String(localized: "settings.alert.cacheDeletionConfirmation.message")
        case .result(let result):
            return result.message
        }
    }
}
