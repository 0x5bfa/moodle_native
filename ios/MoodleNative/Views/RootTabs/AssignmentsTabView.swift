import MoodleNativeCore
import MoodleNativeFeatures
import SwiftUI

struct AssignmentsTabView: View {
    @Environment(\.lmsSession) private var session
    @State private var assignmentFilter: AssignmentFilter = .own
    @State private var isSelectingAssignments = false
    @State private var selectedAssignmentIDs = Set<Int>()
    let viewModel: AssignmentsViewModel

    init(viewModel: AssignmentsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Group {
                if session == nil {
                    ContentUnavailableView(
                        "assignments.loginRequired.title",
                        systemImage: "checklist.unchecked",
                        description: Text("assignments.loginRequired.description")
                    )
                } else if viewModel.isLoading {
                    LoadingOverlayCard("assignments.loading")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "assignments.unavailable.title",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.assignments.isEmpty {
                    ContentUnavailableView(
                        "assignments.empty.title",
                        systemImage: "checklist",
                        description: Text("assignments.empty.description")
                    )
                } else if let session {
                    assignmentsCollection(session: session)
                }
            }
            .navigationTitle("tab.assignments")
            .adaptiveNavigationTitleDisplayMode()
            .toolbar {
                if session != nil, displayedAssignments.contains(where: { viewModel.isHidden($0) == false }) {
                    if isSelectingAssignments {
                        ToolbarItem {
                            Button("common.cancel") {
                                isSelectingAssignments = false
                                selectedAssignmentIDs.removeAll()
                            }
                        }

                        ToolbarSpacer(.fixed)

                        ToolbarItem {
                            Button {
                                hideSelectedAssignments()
                            } label: {
                                Image(systemName: "eye.slash")
                            }
                            .accessibilityLabel(Text("assignments.action.hideSelected"))
                            .disabled(selectedVisibleAssignments.isEmpty)
                        }
                    } else {
                        ToolbarItem {
                            Button("common.select") {
                                isSelectingAssignments = true
                                selectedAssignmentIDs.removeAll()
                            }
                        }
                    }
                }
            }
            .onChange(of: displayedAssignments.map(\.id)) {
                selectedAssignmentIDs.formIntersection(Set(displayedAssignments.map(\.id)))
                if displayedAssignments.contains(where: { viewModel.isHidden($0) == false }) == false {
                    isSelectingAssignments = false
                    selectedAssignmentIDs.removeAll()
                }
            }
            .onChange(of: assignmentFilter) {
                isSelectingAssignments = false
                selectedAssignmentIDs.removeAll()
            }
            .loadable(viewModel, session: session)
        }
    }

    private var selectedVisibleAssignments: [LmsAssignmentItem] {
        displayedAssignments.filter {
            viewModel.isHidden($0) == false && selectedAssignmentIDs.contains($0.id)
        }
    }

    private func toggleSelection(for assignment: LmsAssignmentItem) {
        guard viewModel.isHidden(assignment) == false else {
            return
        }

        if selectedAssignmentIDs.contains(assignment.id) {
            selectedAssignmentIDs.remove(assignment.id)
        } else {
            selectedAssignmentIDs.insert(assignment.id)
        }
    }

    private func hideSelectedAssignments() {
        let assignments = selectedVisibleAssignments
        viewModel.hide(assignments)
        selectedAssignmentIDs.subtract(assignments.map(\.id))

        if selectedVisibleAssignments.isEmpty {
            isSelectingAssignments = false
        }
    }

    private var displayedAssignments: [LmsAssignmentItem] {
        switch assignmentFilter {
        case .own:
            return viewModel.visibleAssignments
        case .all:
            return viewModel.allAssignments
        }
    }

    private var filterControls: some View {
        AssignmentFilterPillBar(
            selection: Binding(
                get: { assignmentFilter },
                set: { assignmentFilter = $0 }
            )
        )
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func assignmentsCollection(session: LmsAuthenticationSession) -> some View {
        #if targetEnvironment(macCatalyst)
        // Mac: a hand-built scroll list instead of `List`. A `List` row is a
        // `UICollectionViewListCell` that paints its own context-menu highlight across the full
        // detail column — the red outline that bleeds into the sidebar — and SwiftUI cannot
        // suppress or reshape it. A `LazyVStack` row is a plain view, so the right-click menu
        // shows an ordinary floating preview with no cell outline.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                filterControls
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                if displayedAssignments.isEmpty {
                    ContentUnavailableView(
                        "assignments.ownEmpty.title",
                        systemImage: "checklist",
                        description: Text("assignments.ownEmpty.description")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    ForEach(Array(displayedAssignments.enumerated()), id: \.element.id) { index, assignment in
                        assignmentRowCore(assignment, session: session)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                        if index < displayedAssignments.count - 1 {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        #else
        List {
            filterControls
                .listRowSeparator(.hidden)

            if displayedAssignments.isEmpty {
                ContentUnavailableView(
                    "assignments.ownEmpty.title",
                    systemImage: "checklist",
                    description: Text("assignments.ownEmpty.description")
                )
                .listRowSeparator(.hidden)
            }

            ForEach(displayedAssignments) { assignment in
                assignmentRowCore(assignment, session: session)
            }
        }
        .listStyle(.plain)
        #endif
    }

    @ViewBuilder
    private func assignmentRowCore(_ assignment: LmsAssignmentItem, session: LmsAuthenticationSession) -> some View {
        if isSelectingAssignments {
            Button {
                toggleSelection(for: assignment)
            } label: {
                AssignmentSelectionRow(
                    assignment: assignment,
                    isSelected: selectedAssignmentIDs.contains(assignment.id),
                    isDisabled: viewModel.isHidden(assignment)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isHidden(assignment))
        } else {
            NavigationLink {
                LmsAssignmentDetailView(
                    assignment: assignment.reference(siteURL: session.siteURL),
                    navigationPath: String(localized: "navigationPath.assignments.assignmentDetail")
                )
            } label: {
                LmsAssignmentRow(assignment: assignment)
                    .assignmentContextMenu(
                        assignment: assignment,
                        siteURL: session.siteURL,
                        isHidden: viewModel.isHidden(assignment),
                        canHide: assignmentFilter == .all || assignmentFilter == .own,
                        onHide: { viewModel.hide(assignment) },
                        onRestore: { viewModel.show(assignment) }
                    )
            }
            #if targetEnvironment(macCatalyst)
            .buttonStyle(MacAssignmentRowButtonStyle())
            .focusEffectDisabled()
            #else
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: assignmentFilter == .own) {
                if viewModel.isHidden(assignment) {
                    Button("assignments.action.restore", systemImage: "eye") {
                        viewModel.show(assignment)
                    }
                    .tint(.accentColor)
                } else if assignmentFilter == .all {
                    Button("assignments.action.hide", systemImage: "eye.slash") {
                        viewModel.hide(assignment)
                    }
                    .tint(.red)
                } else {
                    Button("assignments.action.hide", systemImage: "eye.slash", role: .destructive) {
                        viewModel.hide(assignment)
                    }
                }
            }
            #endif
        }
    }
}


private struct AssignmentFilterPillBar: View {
    @Binding var selection: AssignmentFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AssignmentFilter.allCases) { filter in
                pillSegment(for: filter)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.08), in: Capsule())
    }

    private func pillSegment(for filter: AssignmentFilter) -> some View {
        let isSelected = selection == filter

        return HStack(spacing: 8) {
            Image(systemName: filter.systemImage)
                .font(.system(size: 16, weight: .semibold))

            Text(filter.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
        .frame(maxWidth: .infinity, minHeight: 32)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            isSelected ? Color.accentColor : Color.clear,
            in: Capsule()
        )
        .contentShape(Capsule())
        .onTapGesture {
            selection = filter
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityElement(children: .combine)
    }
}

private enum AssignmentFilter: String, CaseIterable, Identifiable {
    case all
    case own

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all:
            return "assignments.filter.all"
        case .own:
            return "assignments.filter.own"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "tray"
        case .own:
            return "checklist"
        }
    }
}

private struct AssignmentSelectionRow: View {
    let assignment: LmsAssignmentItem
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selectionColor)
                .padding(.top, 6)

            LmsAssignmentRow(assignment: assignment)
        }
        .contentShape(Rectangle())
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var selectionColor: Color {
        if isDisabled {
            return .secondary
        }

        return isSelected ? .accentColor : .secondary
    }
}

#if targetEnvironment(macCatalyst)
/// Plain-looking row button that adds a clear rounded highlight on hover and press, so a
/// left-click has visible feedback in the `LazyVStack` (which, unlike `List`, provides none).
private struct MacAssignmentRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Backed(configuration: configuration)
    }

    private struct Backed: View {
        let configuration: ButtonStyle.Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(fillColor)
                        .padding(.horizontal, -10)
                        .padding(.vertical, -6)
                )
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
        }

        private var fillColor: Color {
            if configuration.isPressed {
                return Color.primary.opacity(0.14)
            }
            if isHovered {
                return Color.primary.opacity(0.06)
            }
            return Color.clear
        }
    }
}
#endif

#Preview {
    AssignmentsTabView(viewModel: AssignmentsViewModel())
}
