import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking
import SwiftUI

struct LmsCourseDetailView: View {
    @Environment(\.lmsSession) private var session
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue

    let course: LmsCourseSummary
    let navigationPath: String

    @State private var viewModel: CourseDetailViewModel
    @State private var collapsedSectionIDs: Set<Int> = []
    @State private var presentedForum: LmsForumReference?
    @State private var presentedAssignment: LmsAssignmentReference?

    init(
        course: LmsCourseSummary,
        navigationPath: String = String(localized: "navigationPath.courseDetail")
    ) {
        self.course = course
        self.navigationPath = navigationPath
        _viewModel = State(
            initialValue: CourseDetailViewModel(
                courseID: course.id,
                courseTitle: course.title,
                courseShortName: course.shortName,
                navigationPath: navigationPath
            )
        )
    }

    var body: some View {
        Group {
            if session == nil {
                // セッションがない場合
                ContentUnavailableView(
                    "timetable.loginRequired.title",
                    systemImage: "book.closed",
                    description: Text("courseDetail.loginRequired.description")
                )
            } else if viewModel.isLoading && viewModel.sections.isEmpty {
                // 初回ロード
                LoadingOverlayCard("courseDetail.loading")
            } else {
                List {

                    // タイトル・ステータス
                    VStack(alignment: .leading, spacing: 12) {
                        Text(course.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)

                        if courseStatuses.isEmpty == false {
                            HStack(spacing: 12) {
                                ForEach(courseStatuses, id: \.self) { status in
                                    Image(systemName: status.systemImage)
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(status.color)
                                        .frame(width: 18, height: 18)
                                        .accessibilityLabel(status.displayName)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    // エラー表示
                    if let errorMessage = viewModel.errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    if viewModel.sections.isEmpty == false {
                        ForEach(viewModel.sections) { section in
                            Section {
                                if isSectionExpanded(section) {
                                    if section.modules.isEmpty {
                                        Text("courseDetail.section.empty")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(section.modules) { module in
                                            LmsCourseModuleRow(
                                                module: module,
                                                onOpenResource: openResource,
                                                onOpenForum: openForum,
                                                onOpenAssignment: openAssignment
                                            )
                                        }
                                    }
                                }
                            } header: {
                                Button {
                                    toggleSection(section)
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(section.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Image(systemName: isSectionExpanded(section) ? "chevron.down" : "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if session != nil && !viewModel.isLoading && viewModel.errorMessage == nil && viewModel.sections.isEmpty {
                ContentUnavailableView(
                    "courseDetail.emptyMaterials",
                    systemImage: "tray"
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let detailURL = course.detailURL {
                    Button("common.openInMoodle", systemImage: "safari") {
                        openResource(detailURL)
                    }
                }
            }
        }
        .loadable(viewModel, session: session)
        .navigationDestination(item: $presentedForum) { forum in
            LmsForumDiscussionsView(
                forum: forum,
                navigationPath: "\(navigationPath) > \(String(localized: "navigationPath.forum"))"
            )
        }
        .navigationDestination(item: $presentedAssignment) { assignment in
            LmsAssignmentDetailView(
                assignment: assignment,
                navigationPath: "\(navigationPath) > \(String(localized: "navigationPath.assignments.assignmentDetail"))"
            )
        }
    }

    private var courseStatuses: [TimetableStatus] {
        var statuses: [TimetableStatus] = []

        if course.isFavorite {
            statuses.append(.favorite)
        }
        if course.unreadAnnouncementCount > 0 {
            statuses.append(.unreadAnnouncement)
        }
        if course.assignmentCount > 0 {
            statuses.append(.pendingAssignment)
        }
        if course.unreadForumPostCount > 0 {
            statuses.append(.unreadForum)
        }

        return statuses
    }

    private func openResource(_ url: URL) {
        openInApp(url)
    }

    private func openInApp(_ url: URL) {
        openURL(url, prefersInApp: prefersInAppExternalLinks)
    }

    private func openForum(_ forum: LmsForumReference) {
        presentedForum = forum
    }

    private func openAssignment(_ assignment: LmsAssignmentReference) {
        presentedAssignment = assignment
    }

    private func isSectionExpanded(_ section: CourseDetailViewModel.SectionPresentation) -> Bool {
        collapsedSectionIDs.contains(section.id) == false
    }

    private func toggleSection(_ section: CourseDetailViewModel.SectionPresentation) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedSectionIDs.contains(section.id) {
                collapsedSectionIDs.remove(section.id)
            } else {
                collapsedSectionIDs.insert(section.id)
            }
        }
    }
}

private struct LmsCourseModuleRow: View {
    let module: CourseDetailViewModel.ModulePresentation
    let onOpenResource: (URL) -> Void
    let onOpenForum: (LmsForumReference) -> Void
    let onOpenAssignment: (LmsAssignmentReference) -> Void

    private func performPrimaryAction(
        _ action: CourseDetailViewModel.ModulePresentation.PrimaryAction
    ) {
        switch action {
        case .resource(let url):
            onOpenResource(url)
        case .forum(let reference):
            onOpenForum(reference)
        case .assignment(let reference):
            onOpenAssignment(reference)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let primaryAction = module.primaryAction {
                Button {
                    performPrimaryAction(primaryAction)
                } label: {
                    rowContent()
                }
                .buttonStyle(.plain)
            } else {
                rowContent()
            }

            if module.contentNodes.isEmpty == false {
                LmsResourceTreeView(
                    nodes: module.contentNodes,
                    onOpenResource: onOpenResource
                )
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func rowContent() -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: module.iconName)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(module.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Text(module.typeName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)

                    if module.attachmentCount > 0 {
                        Text(Self.localizedAttachmentCount(module.attachmentCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if module.dateLines.isEmpty == false {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(module.dateLines, id: \.self) { dateLine in
                            Text(dateLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if module.completion != nil || module.trailingIndicatorSymbolName != nil {
                LmsCourseModuleAccessories(
                    completion: module.completion,
                    indicatorSymbolName: module.trailingIndicatorSymbolName
                )
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct LmsCourseModuleAccessories: View {
    let completion: LmsModuleCompletionSummary?
    let indicatorSymbolName: String?

    var body: some View {
        VStack(spacing: 6) {
            if let completion {
                LmsCourseModuleCompletionRing(completion: completion)
            }

            if let indicatorSymbolName {
                Image(systemName: indicatorSymbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 12, alignment: .center)
            }
        }
        .frame(width: 20, alignment: .trailing)
        .padding(.top, 1)
    }
}

struct LmsModuleCompletionRequirementRow: View {
    let requirement: LmsModuleCompletionRequirement

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: requirement.symbolName)
                .font(.body.weight(requirement.isComplete ? .semibold : .regular))
                .foregroundStyle(requirement.isComplete ? .green : Color.secondary)
                .frame(width: 20, alignment: .center)

            Text(requirement.text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(requirement.accessibilityLabel)
    }
}

private struct LmsCourseModuleCompletionRing: View {
    let completion: LmsModuleCompletionSummary

    var body: some View {
        Group {
            if completion.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: indicatorSize, weight: .bold))
                    .foregroundStyle(.green)
            } else if completion.progress == 0 {
                Image(systemName: "checkmark.circle.dotted")
                    .font(.system(size: indicatorSize, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.75))
            }
        }
        .frame(width: indicatorSize, height: indicatorSize)
        .accessibilityLabel(Text("courseDetail.completion.accessibilityLabel"))
        .accessibilityValue(completion.accessibilityLabel)
    }

    private let indicatorSize: CGFloat = 16

    private var progressColor: Color {
        if completion.isInProgress {
            return .accentColor
        }

        return Color.secondary.opacity(0.65)
    }

    private var trackColor: Color {
        Color.secondary.opacity(0.18)
    }
}

extension LmsCourseModuleRow {
    fileprivate static func localizedAttachmentCount(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "courseDetail.attachments.count"), count)
    }
}

#Preview {
    LmsCourseDetailView(
        course: LmsCourseSummary(
            id: 1,
            title: String(localized: "debug.sampleCourse.title"),
            courseCode: "53374",
            shortName: String(localized: "debug.sampleCourse.shortName"),
            summary: String(localized: "debug.sampleCourse.summary"),
            courseImageURL: nil,
            progress: 55,
            isFavorite: true,
            academicSemester: AcademicSemester(academicYear: 2026, season: .spring),
            scheduleSlots: [
                TimetableScheduleSlot(dayIndex: 0, periodIndices: [1], room: "H301")
            ],
            assignmentCount: 2,
            unreadAnnouncementCount: 1,
            unreadForumPostCount: 3,
            isRecentlyAccessed: true,
            detailURL: URL(string: "https://moodle.example.edu/course/view.php?id=1")
        )
    )
    .environment(
        \.lmsSession,
        LmsAuthenticationSession(
            siteURL: "https://moodle.example.edu",
            token: "preview-token",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example",
            authenticatedAt: .now
        )
    )
}
