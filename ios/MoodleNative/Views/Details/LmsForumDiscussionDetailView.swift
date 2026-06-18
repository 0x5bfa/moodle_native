import MoodleNativeCore
import MoodleNativeNetworking
import MoodleNativeFeatures
import SwiftUI

struct LmsForumDiscussionDetailView: View {
    @Environment(\.lmsSession) private var session

    let discussion: LmsWebServiceClient.ForumDiscussion

    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue
    @State private var viewModel: ForumDiscussionDetailViewModel

    init(
        discussion: LmsWebServiceClient.ForumDiscussion,
        navigationPath: String = String(localized: "navigationPath.discussionDetail")
    ) {
        self.discussion = discussion
        _viewModel = State(
            initialValue: ForumDiscussionDetailViewModel(
                discussionID: discussion.discussionID,
                pageTitle: discussion.displayTitle,
                navigationPath: navigationPath
            )
        )
    }

    var body: some View {
        Group {
            if session == nil {
                ContentUnavailableView(
                    "assignments.loginRequired.title",
                    systemImage: "text.bubble",
                    description: Text("forumDiscussionDetail.loginRequired.description")
                )
            } else if viewModel.isLoading {
                LoadingOverlayCard("forumDiscussionDetail.loading")
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "forumDiscussionDetail.unavailable.title",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.posts.isEmpty && viewModel.errorMessage == nil {
                ContentUnavailableView(
                    "forumDiscussionDetail.empty.title",
                    systemImage: "text.bubble",
                    description: Text("forumDiscussionDetail.empty.description")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(threadedPosts.enumerated()), id: \.element.id) { index, node in
                            if index > 0 {
                                Divider()
                            }

                            ForumPostRow(node: node, depth: 0, onOpenResource: openResource)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(discussion.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let discussionURL = viewModel.discussionURL {
                    Button("common.openInMoodle", systemImage: "safari") {
                        openResource(discussionURL)
                    }
                }
            }
        }
        .loadable(viewModel, session: session)
    }

    private var threadedPosts: [LmsForumPostThreadNode] {
        viewModel.posts.threadedPosts()
    }

    private func openResource(_ url: URL) {
        switch url.scheme?.lowercased() {
        case "http", "https", nil:
            openURL(url, prefersInApp: prefersInAppExternalLinks)
        default:
            openURL(url)
        }
    }
}
