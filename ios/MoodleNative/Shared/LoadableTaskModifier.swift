import MoodleNativeCore
import SwiftUI

struct LoadableTaskModifier: ViewModifier {
    let session: LmsAuthenticationSession?
    let loadIfNeeded: @MainActor (LmsAuthenticationSession?) async -> Void
    let refresh: @MainActor (LmsAuthenticationSession?) async -> Void

    func body(content: Content) -> some View {
        content
            .refreshable {
                await refresh(session)
            }
            .task(id: session) {
                await loadIfNeeded(session)
            }
    }
}
