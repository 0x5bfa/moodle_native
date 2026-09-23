import MoodleNativeCore
import MoodleNativeFeatures
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

extension View {
    func assignmentContextMenu(
        assignment: LmsAssignmentItem,
        siteURL: String,
        isHidden: Bool,
        canHide: Bool,
        onHide: @escaping () -> Void,
        onRestore: @escaping () -> Void
    ) -> some View {
        modifier(
            AssignmentContextMenuModifier(
                assignment: assignment,
                siteURL: siteURL,
                isHidden: isHidden,
                canHide: canHide,
                onHide: onHide,
                onRestore: onRestore
            )
        )
    }
}

private struct AssignmentContextMenuModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue

    let assignment: LmsAssignmentItem
    let siteURL: String
    let isHidden: Bool
    let canHide: Bool
    let onHide: () -> Void
    let onRestore: () -> Void

    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        // The assignments list is a plain `LazyVStack` on Mac (see AssignmentsTabView), so the
        // context menu no longer paints the old full-width red cell outline. The `preview:` lifts
        // the row into a floating rounded card on right-click — clear, standard macOS feedback
        // (Mail/Notes style) with no loud tint.
        content
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contextMenu {
                menuItems
            } preview: {
                LmsAssignmentRow(assignment: assignment)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minWidth: 320, maxWidth: 460, alignment: .leading)
            }
        #else
        content
            .contextMenu {
                menuItems
            }
        #endif
    }

    @ViewBuilder
    private var menuItems: some View {
        if let detailURL = assignment.reference(siteURL: siteURL).detailURL {
            Button("common.openInMoodle", systemImage: "safari") {
                openURL(detailURL, prefersInApp: prefersInAppExternalLinks)
            }
        }

        if isHidden {
            Button("assignments.action.restore", systemImage: "eye") {
                onRestore()
            }
        } else if canHide {
            Button("assignments.action.hide", systemImage: "eye.slash", role: .destructive) {
                onHide()
            }
        }
    }
}

extension View {
    /// Large inline title on iPhone/iPad, standard inline title on Mac.
    /// macOS surfaces the title in the window/toolbar, so oversized in-content titles read as iPad-scaled.
    @ViewBuilder
    func adaptiveNavigationTitleDisplayMode() -> some View {
        #if targetEnvironment(macCatalyst)
        toolbarTitleDisplayMode(.inline)
        #else
        toolbarTitleDisplayMode(.inlineLarge)
        #endif
    }
}
