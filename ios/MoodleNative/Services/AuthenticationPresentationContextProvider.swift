import AuthenticationServices
import UIKit

@MainActor
final class AuthenticationPresentationContextProvider: NSObject,
    ASWebAuthenticationPresentationContextProviding
{
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = windowScenes.first else {
            preconditionFailure("A window scene is required to present ASWebAuthenticationSession.")
        }

        if let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
            return keyWindow
        }

        return ASPresentationAnchor(windowScene: windowScene)
    }
}
