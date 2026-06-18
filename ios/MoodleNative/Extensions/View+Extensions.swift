import MoodleNativeCore
import SwiftUI

extension View {
    func loadable(
        session: LmsAuthenticationSession?,
        loadIfNeeded: @escaping @MainActor (LmsAuthenticationSession?) async -> Void,
        refresh: @escaping @MainActor (LmsAuthenticationSession?) async -> Void
    ) -> some View {
        modifier(
            LoadableTaskModifier(
                session: session,
                loadIfNeeded: loadIfNeeded,
                refresh: refresh
            )
        )
    }

    func loadable(
        _ object: some LoadableObject,
        session: LmsAuthenticationSession?
    ) -> some View {
        loadable(
            session: session,
            loadIfNeeded: { session in
                await object.loadIfNeeded(session: session)
            },
            refresh: { session in
                await object.refresh(session: session)
            }
        )
    }
}
