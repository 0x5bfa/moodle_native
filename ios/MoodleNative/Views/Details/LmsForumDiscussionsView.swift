import MoodleNativeCore
import MoodleNativeNetworking
import MoodleNativeFeatures
import SwiftUI

struct LmsForumDiscussionsView: View {
    @Environment(\.lmsSession) private var session
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue

    let forum: LmsForumReference
    let navigationPath: String

    @State private var viewModel: ForumDiscussionsViewModel

    init(forum: LmsForumReference, navigationPath: String = String(localized: "navigationPath.forum")) {
        self.forum = forum
        self.navigationPath = navigationPath
        _viewModel = State(
            initialValue: ForumDiscussionsViewModel(
                forumID: forum.forumID,
                pageTitle: forum.title,
                navigationPath: navigationPath
            )
        )
    }

    var body: some View {
        Group {
            if session == nil {
                ContentUnavailableView(
                    "assignments.loginRequired.title",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("forumDiscussions.loginRequired.description")
                )
            } else if viewModel.isLoading {
                LoadingOverlayCard("forumDiscussions.loading")
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "forumDiscussions.unavailable.title",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                List {
                    if forum.completionRequirements.isEmpty == false {
                        Section("forumDiscussions.todo.section") {
                            ForEach(forum.completionRequirements) { requirement in
                                LmsModuleCompletionRequirementRow(requirement: requirement)
                            }
                        }
                    }

                    if viewModel.discussions.isEmpty {
                        ContentUnavailableView(
                            "forumDiscussions.empty.title",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("forumDiscussions.empty.description")
                        )
                    } else {
                        Section("forumDiscussions.items.section") {
                            ForEach(viewModel.discussions) { discussion in
                                NavigationLink {
                                    LmsForumDiscussionDetailView(
                                        discussion: discussion,
                                        navigationPath: "\(navigationPath) > \(String(localized: "navigationPath.discussion"))"
                                    )
                                } label: {
                                    ForumDiscussionRow(discussion: discussion)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(forum.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let detailURL = forum.detailURL {
                    Button("common.openInMoodle", systemImage: "safari") {
                        openInApp(detailURL)
                    }
                }
            }
        }
        .loadable(viewModel, session: session)
    }

    private func openInApp(_ url: URL) {
        openURL(url, prefersInApp: prefersInAppExternalLinks)
    }
}
