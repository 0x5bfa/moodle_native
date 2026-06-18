import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking

@Observable
@MainActor
final class CourseDetailViewModel: LoadableObject {
    struct SectionPresentation: Identifiable, Equatable {
        let id: Int
        let title: String
        let modules: [ModulePresentation]
    }

    struct ModulePresentation: Identifiable, Equatable {
        enum PrimaryAction: Equatable {
            case resource(URL)
            case forum(LmsForumReference)
            case assignment(LmsAssignmentReference)
        }

        let id: Int
        let title: String
        let typeName: String
        let iconName: String
        let attachmentCount: Int
        let dateLines: [String]
        let contentNodes: [LmsResourceTreeNode]
        let primaryAction: PrimaryAction?
        let completion: LmsModuleCompletionSummary?

        var showsExternalIndicator: Bool {
            if case .resource? = primaryAction {
                return true
            }

            return false
        }

        var showsNavigationIndicator: Bool {
            switch primaryAction {
            case .forum?, .assignment?:
                return true
            case .resource?, .none:
                return false
            }
        }

        var trailingIndicatorSymbolName: String? {
            if showsExternalIndicator {
                return "arrow.up.forward.square"
            }

            if showsNavigationIndicator {
                return "chevron.right"
            }

            return nil
        }
    }

    private(set) var sections: [SectionPresentation] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let courseID: Int
    private let courseTitle: String
    private let courseShortName: String
    private let logContext: LmsRequestLogContext
    private var loadedSession: LmsAuthenticationSession?
    private var hasLoaded = false
    private var loadGeneration = 0

    init(
        courseID: Int,
        courseTitle: String,
        courseShortName: String,
        navigationPath: String = String(localized: "navigationPath.courseDetail")
    ) {
        self.courseID = courseID
        self.courseTitle = courseTitle
        self.courseShortName = courseShortName
        self.logContext = LmsRequestLogContext(navigationPath: navigationPath, pageTitle: courseTitle)
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        guard hasLoaded == false || loadedSession != session else {
            return
        }

        await load(session: session)
    }

    func refresh(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        await load(session: session, forceRefresh: true)
    }

    private func load(
        session: LmsAuthenticationSession,
        forceRefresh: Bool = false
    ) async {
        guard forceRefresh || hasLoaded == false || loadedSession != session else {
            return
        }

        let generation = loadGeneration + 1
        loadGeneration = generation
        isLoading = true
        errorMessage = nil

        do {
            let client = LmsWebServiceClient.logged(session: session, context: logContext)
            async let sectionsTask = client.fetchCourseContents(courseID: courseID)
            async let assignmentReferencesTask = Self.fetchAssignmentReferenceLookup(
                using: client,
                courseID: courseID,
                courseTitle: courseTitle,
                courseShortName: courseShortName
            )
            let sections = try await sectionsTask
            let assignmentReferencesByID = await assignmentReferencesTask
            guard generation == loadGeneration else {
                return
            }

            self.sections = Self.makeSectionPresentations(
                from: sections,
                courseID: courseID,
                courseTitle: courseTitle,
                courseShortName: courseShortName,
                assignmentReferencesByID: assignmentReferencesByID
            )
            loadedSession = session
            hasLoaded = true
            isLoading = false
        } catch {
            guard generation == loadGeneration else {
                return
            }

            if Self.isCancellation(error) {
                isLoading = false
                return
            }

            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    private func reset() {
        loadGeneration += 1
        sections = []
        isLoading = false
        errorMessage = nil
        loadedSession = nil
        hasLoaded = false
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

        return String(localized: "courseDetail.error.fetchFailed")
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

    static func makeSectionPresentations(
        from sections: [LmsWebServiceClient.CourseSection],
        courseID: Int,
        courseTitle: String,
        courseShortName: String,
        assignmentReferencesByID: [Int: LmsAssignmentReference] = [:]
    ) -> [SectionPresentation] {
        sections.map { section in
            SectionPresentation(
                id: section.id,
                title: sectionTitle(for: section),
                modules: section.modules.map {
                    makeModulePresentation(
                        from: $0,
                        courseID: courseID,
                        courseTitle: courseTitle,
                        courseShortName: courseShortName,
                        assignmentReferencesByID: assignmentReferencesByID
                    )
                }
            )
        }
    }

    private static func makeModulePresentation(
        from module: LmsWebServiceClient.CourseModule,
        courseID: Int,
        courseTitle: String,
        courseShortName: String,
        assignmentReferencesByID: [Int: LmsAssignmentReference]
    ) -> ModulePresentation {
        let destinationURL = module.url.flatMap(URL.init(string:))
        let contentFiles = module.contents.compactMap(makeContentPresentation)

        return ModulePresentation(
            id: module.id,
            title: module.name,
            typeName: moduleTypeName(for: module.modName),
            iconName: moduleIconName(for: module.modName),
            attachmentCount: contentFiles.count,
            dateLines: module.dates.prefix(2).map(formatDateLine),
            contentNodes: buildContentNodes(from: contentFiles),
            primaryAction: makePrimaryAction(
                for: module,
                destinationURL: destinationURL,
                courseID: courseID,
                courseTitle: courseTitle,
                courseShortName: courseShortName,
                assignmentReferencesByID: assignmentReferencesByID
            ),
            completion: module.completionData?.summary
        )
    }

    private static func makeContentPresentation(
        from content: LmsWebServiceClient.ModuleContent
    ) -> LmsResourceTreeFile? {
        guard let url = content.fileURL.flatMap(URL.init(string:)) else {
            return nil
        }

        return LmsResourceTreeFile(
            id: content.id,
            title: moduleContentTitle(for: content),
            url: url,
            pathComponents: moduleContentPathComponents(for: content)
        )
    }

    private static func buildContentNodes(
        from files: [LmsResourceTreeFile]
    ) -> [LmsResourceTreeNode] {
        files.treeNodes()
    }

    private static func fetchAssignmentReferenceLookup(
        using client: LmsWebServiceClient,
        courseID: Int,
        courseTitle: String,
        courseShortName: String
    ) async -> [Int: LmsAssignmentReference] {
        do {
            let assignmentsByCourse = try await client.fetchAssignments(courseIDs: [courseID])
            return makeAssignmentReferenceLookup(
                from: assignmentsByCourse,
                courseTitle: courseTitle,
                courseShortName: courseShortName
            )
        } catch {
            return [:]
        }
    }

    private static func makeAssignmentReferenceLookup(
        from assignmentsByCourse: [LmsWebServiceClient.CourseAssignments],
        courseTitle: String,
        courseShortName: String
    ) -> [Int: LmsAssignmentReference] {
        var assignmentReferencesByID: [Int: LmsAssignmentReference] = [:]

        for course in assignmentsByCourse {
            for assignment in course.assignments {
                let reference = LmsAssignmentReference(
                    assignmentID: assignment.id,
                    courseModuleID: assignment.courseModuleID,
                    courseID: assignment.courseID,
                    courseTitle: courseTitle,
                    courseShortName: courseShortName,
                    title: assignment.name,
                    introPreview: LmsHTMLTextFormatter.plainText(from: assignment.intro),
                    dueDate: date(from: assignment.dueDate),
                    allowsSubmissionsFromDate: date(from: assignment.allowsSubmissionsFromDate),
                    cutoffDate: date(from: assignment.cutoffDate),
                    updatedAt: date(from: assignment.timeModified),
                    submissionDrafts: assignment.submissionDrafts,
                    requiresSubmissionStatement: assignment.requiresSubmissionStatement,
                    submissionStatement: assignment.submissionStatement,
                    timeLimit: assignment.timeLimit,
                    enabledSubmissionPluginTypes: assignment.enabledSubmissionPluginTypes,
                    onlineTextWordLimit: assignment.onlineTextWordLimit,
                    detailURL: nil,
                    completionRequirements: []
                )

                assignmentReferencesByID[assignment.id] = reference
                assignmentReferencesByID[assignment.courseModuleID] = reference
            }
        }

        return assignmentReferencesByID
    }

    private static func date(from timestamp: Int?) -> Date? {
        guard let timestamp, timestamp > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private static func makePrimaryAction(
        for module: LmsWebServiceClient.CourseModule,
        destinationURL: URL?,
        courseID: Int,
        courseTitle: String,
        courseShortName: String,
        assignmentReferencesByID: [Int: LmsAssignmentReference]
    ) -> ModulePresentation.PrimaryAction? {
        if module.modName == "forum", let instanceID = module.instanceID {
            return .forum(
                LmsForumReference(
                    forumID: instanceID,
                    courseModuleID: module.id,
                    title: module.name,
                    detailURL: destinationURL,
                    completionRequirements: module.completionData?.requirements ?? []
                )
            )
        }

        if module.modName == "assign", let instanceID = module.instanceID {
            if let reference = assignmentReferencesByID[instanceID] ?? assignmentReferencesByID[module.id] {
                return .assignment(reference.merging(courseModule: module))
            }

            return .assignment(
                LmsAssignmentReference(
                    assignmentID: instanceID,
                    courseModuleID: module.id,
                    courseID: courseID,
                    courseTitle: courseTitle,
                    courseShortName: courseShortName,
                    title: module.name,
                    introPreview: nil,
                    dueDate: nil,
                    allowsSubmissionsFromDate: nil,
                    cutoffDate: nil,
                    updatedAt: nil,
                    detailURL: destinationURL,
                    completionRequirements: module.completionData?.requirements ?? []
                )
            )
        }

        if module.contents.isEmpty, let destinationURL {
            return .resource(destinationURL)
        }

        return nil
    }
    private static func sectionTitle(for section: LmsWebServiceClient.CourseSection) -> String {
        let trimmedName = section.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty == false {
            return trimmedName
        }

        if let sectionNumber = section.section {
            return String.localizedStringWithFormat(
                String(localized: "courseDetail.section.number"),
                sectionNumber
            )
        }

        return String(localized: "courseDetail.section.defaultTitle")
    }

    private static func moduleTypeName(for modName: String) -> String {
        switch modName {
        case "assign":
            return String(localized: "courseDetail.moduleType.assignment")
        case "forum":
            return String(localized: "courseDetail.moduleType.forum")
        case "resource":
            return String(localized: "courseDetail.moduleType.resource")
        case "url":
            return String(localized: "courseDetail.moduleType.url")
        case "page":
            return String(localized: "courseDetail.moduleType.page")
        case "quiz":
            return String(localized: "courseDetail.moduleType.quiz")
        case "attendance":
            return String(localized: "courseDetail.moduleType.attendance")
        case "folder":
            return String(localized: "courseDetail.moduleType.folder")
        case "lti":
            return String(localized: "courseDetail.moduleType.lti")
        default:
            return modName
        }
    }

    private static func moduleIconName(for modName: String) -> String {
        switch modName {
        case "assign":
            return "checklist"
        case "forum":
            return "bubble.left.and.bubble.right"
        case "resource":
            return "doc.text"
        case "url":
            return "link"
        case "page":
            return "doc.plaintext"
        case "quiz":
            return "questionmark.circle"
        case "attendance":
            return "calendar.badge.checkmark"
        case "folder":
            return "folder"
        case "lti":
            return "play.rectangle"
        default:
            return "square.stack.3d.up"
        }
    }

    private static func moduleContentTitle(for content: LmsWebServiceClient.ModuleContent) -> String {
        if let fileName = content.fileName,
            fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        {
            return fileName
        }

        if let type = content.type,
            type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        {
            return type
        }

        return String(localized: "common.attachment")
    }

    private static func moduleContentPathComponents(
        for content: LmsWebServiceClient.ModuleContent
    ) -> [String] {
        guard let filePath = content.filePath else {
            return []
        }

        return filePath.lmsPathComponents
    }

    private static func formatDateLine(for date: LmsWebServiceClient.ModuleDate) -> String {
        "\(date.label) \(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(date.timestamp))))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
