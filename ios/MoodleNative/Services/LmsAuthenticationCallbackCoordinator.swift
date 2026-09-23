import Foundation

@MainActor
final class LmsAuthenticationCallbackCoordinator {
    static let shared = LmsAuthenticationCallbackCoordinator()

    private var handler: ((URL) -> Void)?
    private weak var owner: AnyObject?

    private init() {}

    func register(handler: @escaping (URL) -> Void, owner: AnyObject) {
        self.handler = handler
        self.owner = owner
    }

    func unregister(owner: AnyObject) {
        guard self.owner === owner else {
            return
        }

        handler = nil
        self.owner = nil
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "moodleapp" else {
            return false
        }

        guard let handler else {
            return false
        }

        handler(url)
        return true
    }
}
