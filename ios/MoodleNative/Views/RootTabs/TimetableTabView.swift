import MoodleNativeCore
import MoodleNativeFeatures
import SwiftUI

struct TimetableTabView: View {
    @Environment(LmsAuthenticationViewModel.self) private var lmsAuthenticationViewModel
    @Environment(\.lmsSession) private var session
    @State private var viewModel = TimetableViewModel()
    @State private var isEditingCourses = false
    @State private var selectedEditingCourse: TimetableCourse?
    @State private var selectedDetailCourseID: Int?
    @State private var recentlyLongPressedCourseID: String?
    @State private var courseEdits = TimetableCourseEditStore.load()
    #if DEBUG
    @AppStorage(DebugTimetableFixtureStore.selectionStorageKey)
    private var debugTimetableFixtureID = DebugTimetableFixtureStore.noneFixtureID
    #endif
    @AppStorage(CoursesDisplayMode.storageKey) private var displayModeRawValue = CoursesDisplayMode.timetable.rawValue
    @AppStorage(TimetableViewModel.selectedSemesterStorageKey) private var selectedSemesterID = ""

    private var displayMode: CoursesDisplayMode {
        CoursesDisplayMode(rawValue: displayModeRawValue) ?? .timetable
    }

    private var timetableNavigationTitle: String {
        guard let selectedSemester = viewModel.selectedSemester else {
            return String(localized: "timetable.title")
        }

        return selectedSemester.navigationTitle
    }

    var body: some View {
        NavigationStack {
            Group {
                if session == nil && isShowingDebugFixture == false {
                    ContentUnavailableView(
                        "timetable.loginRequired.title",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("timetable.loginRequired.description")
                    )
                } else if viewModel.isLoading {
                    LoadingOverlayCard("timetable.loading")
                } else {
                    switch displayMode {
                    case .timetable:
                        if let errorMessage = viewModel.errorMessage,
                            viewModel.hasScheduledCourses == false
                        {
                            ContentUnavailableView(
                                "timetable.unavailable.title",
                                systemImage: "exclamationmark.triangle",
                                description: Text(errorMessage)
                            )
                        } else if viewModel.hasScheduledCourses == false {
                            ContentUnavailableView(
                                "timetable.empty.title",
                                systemImage: "calendar",
                                description: Text("timetable.empty.description")
                            )
                        } else {
                            GeometryReader { geometry in
                                VStack(alignment: .leading, spacing: 12) {
                                    if let errorMessage = viewModel.errorMessage {
                                        TimetableNoticeCard(
                                            title: String(localized: "timetable.loadError.title"),
                                            message: errorMessage,
                                            systemImage: "exclamationmark.triangle"
                                        )
                                    }

                                    timetableGrid(availableSize: geometry.size)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        }
                    case .list:
                        if let errorMessage = viewModel.errorMessage,
                            viewModel.displayedCourseSummaries.isEmpty
                        {
                            ContentUnavailableView(
                                "timetable.listUnavailable.title",
                                systemImage: "exclamationmark.triangle",
                                description: Text(errorMessage)
                            )
                        } else if viewModel.displayedCourseSummaries.isEmpty {
                            ContentUnavailableView(
                                "timetable.empty.title",
                                systemImage: "book.closed",
                                description: Text("timetable.empty.description")
                            )
                        } else {
                            List {
                                if let errorMessage = viewModel.errorMessage {
                                    Section {
                                        Text(errorMessage)
                                            .font(.footnote)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Section {
                                    ForEach(viewModel.displayedCourseSummaries) { course in
                                        NavigationLink {
                                            LmsCourseDetailView(
                                                course: course,
                                                navigationPath: String(localized: "navigationPath.timetable.courseDetail")
                                            )
                                        } label: {
                                            CourseSummaryRow(course: course)
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(timetableNavigationTitle)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem {
                    Button {
                        isEditingCourses.toggle()
                    } label: {
                        if isEditingCourses {
                            Label("timetable.toolbar.finishEditing", systemImage: "checkmark")
                        } else {
                            Label("timetable.toolbar.editCourses", systemImage: "square.and.pencil")
                        }
                    }
                    .disabled(session == nil || displayMode != .timetable || viewModel.hasScheduledCourses == false)
                }

                ToolbarItem {
                    if session != nil {
                        Button("common.reload", systemImage: "arrow.clockwise") {
                            Task {
                                await viewModel.refresh(session: session)
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedEditingCourse) { course in
                let summary = viewModel.courseSummary(for: course)

                TimetableCourseEditSheet(
                    course: course,
                    isFavorite: summary?.isFavorite,
                    toggleFavorite: shouldAllowFavoriteToggle ? { isFavorite in
                        guard let summary else {
                            return
                        }

                        try await viewModel.setCourseFavorite(
                            courseID: summary.id,
                            isFavorite: isFavorite,
                            session: session
                        )
                    } : nil,
                    edit: editBinding(for: course.id)
                )
            }
            .navigationDestination(item: $selectedDetailCourseID) { courseID in
                if let course = detailCourseSummary(for: courseID) {
                    LmsCourseDetailView(
                        course: course,
                        navigationPath: String(localized: "navigationPath.timetable.courseDetail")
                    )
                } else {
                    ContentUnavailableView(
                        "timetable.courseUnavailable.title",
                        systemImage: "book.closed",
                        description: Text("timetable.courseUnavailable.description")
                    )
                }
            }
            .sheet(isPresented: courseConflictSheetBinding) {
                TimetableCourseConflictResolutionSheet(
                    conflicts: viewModel.pendingCourseConflicts,
                    weekdayLabel: weekdayLabel
                ) { resolutions in
                    viewModel.resolveCourseConflicts(resolutions)
                }
                .id(viewModel.pendingCourseConflicts.map(\.id).joined(separator: ","))
            }
            .loadable(
                session: session,
                loadIfNeeded: { session in
                    await viewModel.loadIfNeeded(
                        session: session,
                        userIDResolved: lmsAuthenticationViewModel.updateSessionUserID
                    )
                },
                refresh: { session in
                    await viewModel.refresh(
                        session: session,
                        userIDResolved: lmsAuthenticationViewModel.updateSessionUserID
                    )
                }
            )
            #if DEBUG
            .task(id: debugTimetableFixtureID) {
                await applySelectedDebugFixtureIfNeeded()
            }
            #endif
            .onChange(of: selectedSemesterID) { _, semesterID in
                viewModel.selectSemester(id: semesterID)
            }
        }
    }

    #if DEBUG
    private func applySelectedDebugFixtureIfNeeded() async {
        if let fixture = DebugTimetableFixtureStore.fixture(id: debugTimetableFixtureID) {
            displayModeRawValue = CoursesDisplayMode.timetable.rawValue
            viewModel.applyDebugFixture(fixture)
        } else {
            viewModel.clearDebugFixture()
            await viewModel.loadIfNeeded(session: session)
        }
    }

    private var isShowingDebugFixture: Bool {
        viewModel.isUsingDebugFixture
    }
    #else
    private var isShowingDebugFixture: Bool {
        false
    }
    #endif

    private var shouldAllowFavoriteToggle: Bool {
        #if DEBUG
        if viewModel.isUsingDebugFixture {
            return false
        }
        #endif

        return session != nil
    }

    private var courseConflictSheetBinding: Binding<Bool> {
        Binding {
            viewModel.pendingCourseConflicts.isEmpty == false
        } set: { _ in
        }
    }

    private func timetableGrid(availableSize: CGSize) -> some View {
        let horizontalPadding: CGFloat = 32
        let rowHeaderWidth: CGFloat = 18
        let spacing: CGFloat = 2
        let headerHeight: CGFloat = 18
        let rowCount = max(viewModel.gridRows.count, 1)
        let totalSpacing = CGFloat(rowCount) * spacing
        let availableHeight = timetableGridHeight(in: availableSize)
        let rawRowHeight = (availableHeight - headerHeight - totalSpacing) / CGFloat(rowCount)
        let rowHeight = min(104, max(46, rawRowHeight.rounded(.down)))
        let titleLineLimit = timetableTitleLineLimit(for: rowHeight)

        return VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .center, spacing: spacing) {
                Color.clear
                    .frame(width: rowHeaderWidth, height: headerHeight)

                ForEach(viewModel.weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity, minHeight: headerHeight, maxHeight: headerHeight,
                            alignment: .center)
                }
            }

            if viewModel.scheduledGridRows.isEmpty == false {
                scheduledTimetableGrid(
                    availableWidth: max(0, availableSize.width - horizontalPadding),
                    rowHeaderWidth: rowHeaderWidth,
                    spacing: spacing,
                    rowHeight: rowHeight
                )
            }

            ForEach(viewModel.unscheduledGridRows) { row in
                timetableRow(
                    title: row.title,
                    rowHeaderWidth: rowHeaderWidth,
                    spacing: spacing,
                    height: rowHeight
                ) {
                    ForEach(Array(row.courses.enumerated()), id: \.offset) { _, course in
                        if let course, let summary = viewModel.courseSummary(for: course) {
                            if isEditingCourses {
                                Button {
                                    selectedEditingCourse = course
                                } label: {
                                    TimetableCourseCard(
                                        course: course,
                                        edit: courseEdits[course.id],
                                        titleLineLimit: titleLineLimit,
                                        isEditing: true
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .buttonStyle(.plain)
                            } else {
                                TimetableCourseCard(
                                    course: course,
                                    edit: courseEdits[course.id],
                                    titleLineLimit: titleLineLimit,
                                    isEditing: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    openCourseDetail(summary, course: course)
                                }
                                .onLongPressGesture {
                                    openCourseEditSheet(for: course)
                                }
                            }
                        } else {
                            TimetableEmptyCell()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func scheduledTimetableGrid(
        availableWidth: CGFloat,
        rowHeaderWidth: CGFloat,
        spacing: CGFloat,
        rowHeight: CGFloat
    ) -> some View {
        let dayCount = CGFloat(viewModel.weekdays.count)
        let columnWidth = max(0, (availableWidth - rowHeaderWidth - (dayCount * spacing)) / dayCount)
        let rowCount = viewModel.scheduledGridRows.count
        let coveredSlots = scheduledGridCoveredSlots()
        let totalHeight =
            (CGFloat(rowCount) * rowHeight)
            + (CGFloat(max(rowCount - 1, 0)) * spacing)

        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(viewModel.scheduledGridRows.enumerated()), id: \.element.id) {
                    rowIndex,
                    row in
                    timetableRow(
                        title: row.title,
                        rowHeaderWidth: rowHeaderWidth,
                        spacing: spacing,
                        height: rowHeight
                    ) {
                        ForEach(viewModel.weekdays.indices, id: \.self) { dayIndex in
                            if coveredSlots.contains(scheduledGridSlotKey(dayIndex: dayIndex, periodIndex: rowIndex)) {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                TimetableEmptyCell()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }

            ForEach(viewModel.scheduledGridPlacements) { course in
                if let dayIndex = course.dayIndex, let periodIndex = course.periodIndex {
                    let cardHeight =
                        (CGFloat(course.periodSpan) * rowHeight)
                        + (CGFloat(max(course.periodSpan - 1, 0)) * spacing)

                    timetableCourseButton(
                        course: course,
                        titleLineLimit: timetableTitleLineLimit(for: cardHeight)
                    )
                    .frame(width: columnWidth, height: cardHeight, alignment: .topLeading)
                    .clipped()
                    .offset(
                        x: rowHeaderWidth + spacing + (CGFloat(dayIndex) * (columnWidth + spacing)),
                        y: CGFloat(periodIndex) * (rowHeight + spacing)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: totalHeight, maxHeight: totalHeight, alignment: .topLeading)
    }

    private func scheduledGridCoveredSlots() -> Set<String> {
        viewModel.scheduledGridPlacements.reduce(into: Set<String>()) { result, course in
            guard let dayIndex = course.dayIndex, let periodIndex = course.periodIndex else {
                return
            }

            for offset in 0..<course.periodSpan {
                result.insert(scheduledGridSlotKey(dayIndex: dayIndex, periodIndex: periodIndex + offset))
            }
        }
    }

    private func scheduledGridSlotKey(dayIndex: Int, periodIndex: Int) -> String {
        "\(dayIndex)-\(periodIndex)"
    }

    private func timetableGridHeight(in size: CGSize) -> CGFloat {
        let verticalPadding: CGFloat = 16
        let noticeHeight: CGFloat = viewModel.errorMessage == nil ? 0 : 72
        let contentSpacing: CGFloat = viewModel.errorMessage == nil ? 0 : 12
        return max(240, size.height - verticalPadding - noticeHeight - contentSpacing)
    }

    private func timetableTitleLineLimit(for rowHeight: CGFloat) -> Int {
        switch rowHeight {
        case ..<56:
            return 1
        case ..<76:
            return 2
        case ..<96:
            return 3
        default:
            return 4
        }
    }

    @ViewBuilder
    private func timetableCourseButton(
        course: TimetableCourse,
        titleLineLimit: Int
    ) -> some View {
        if let summary = viewModel.courseSummary(for: course) {
            if isEditingCourses {
                Button {
                    selectedEditingCourse = course
                } label: {
                    TimetableCourseCard(
                        course: course,
                        edit: courseEdits[course.id],
                        titleLineLimit: titleLineLimit,
                        isEditing: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                TimetableCourseCard(
                    course: course,
                    edit: courseEdits[course.id],
                    titleLineLimit: titleLineLimit,
                    isEditing: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    openCourseDetail(summary, course: course)
                }
                .onLongPressGesture {
                    openCourseEditSheet(for: course)
                }
            }
        } else {
            TimetableEmptyCell()
        }
    }

    private func openCourseDetail(_ summary: LmsCourseSummary, course: TimetableCourse) {
        guard recentlyLongPressedCourseID != course.id else {
            return
        }

        selectedDetailCourseID = summary.id
    }

    private func openCourseEditSheet(for course: TimetableCourse) {
        recentlyLongPressedCourseID = course.id
        selectedEditingCourse = course

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if recentlyLongPressedCourseID == course.id {
                recentlyLongPressedCourseID = nil
            }
        }
    }

    private func detailCourseSummary(for courseID: Int) -> LmsCourseSummary? {
        viewModel.displayedCourseSummaries.first { $0.id == courseID }
    }

    private func weekdayLabel(for dayIndex: Int) -> String {
        guard viewModel.weekdays.indices.contains(dayIndex) else {
            return "-"
        }

        return viewModel.weekdays[dayIndex]
    }

    private func editBinding(for courseID: String) -> Binding<TimetableCourseEdit> {
        Binding {
            courseEdits[courseID] ?? TimetableCourseEdit()
        } set: { newValue in
            if newValue.isEmpty {
                courseEdits.removeValue(forKey: courseID)
            } else {
                courseEdits[courseID] = newValue
            }

            TimetableCourseEditStore.save(courseEdits)
        }
    }

    @ViewBuilder
    private func timetableRow<Content: View>(
        title: String,
        rowHeaderWidth: CGFloat,
        spacing: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            if title.isEmpty == false {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: rowHeaderWidth, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .leading)
            }

            content()
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
    }
}

extension AcademicSemester {
    fileprivate var navigationTitle: String {
        let shortAcademicYear = academicYear % 100
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "en" {
            return String.localizedStringWithFormat(
                String(localized: "timetable.semester.navigation.englishFormat"),
                season.navigationTitleAbbreviation,
                shortAcademicYear
            )
        }

        return String.localizedStringWithFormat(
            String(localized: "timetable.semester.navigation.japaneseFormat"),
            shortAcademicYear,
            season.title
        )
    }
}

extension SemesterSeason {
    fileprivate var navigationTitleAbbreviation: String {
        switch self {
        case .spring:
            return String(localized: "timetable.semester.spring.short")
        case .fall:
            return String(localized: "timetable.semester.fall.short")
        case .unknown:
            return String(localized: "timetable.semester.unknown.short")
        }
    }
}

#Preview {
    TimetableTabView()
}
