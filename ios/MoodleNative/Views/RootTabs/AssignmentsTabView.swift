import MoodleNativeCore
import MoodleNativeFeatures
import SwiftUI

struct AssignmentsTabView: View {
    @Environment(\.lmsSession) private var session
    @AppStorage("assignments.assignmentFilter")
    private var assignmentFilterRawValue = AssignmentFilter.own.rawValue
    @State private var isSelectingAssignments = false
    @State private var selectedAssignmentIDs = Set<Int>()
    let viewModel: AssignmentsViewModel

    init(viewModel: AssignmentsViewModel) {
        self.viewModel = viewModel
    }

    private var assignmentFilter: AssignmentFilter {
        get {
            AssignmentFilter(rawValue: assignmentFilterRawValue) ?? .own
        }
        nonmutating set {
            assignmentFilterRawValue = newValue.rawValue
        }
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
                                }
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
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("tab.assignments")
            .toolbarTitleDisplayMode(.inlineLarge)
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
            .onChange(of: assignmentFilterRawValue) {
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
        HStack(spacing: 8) {
            ForEach(AssignmentFilter.allCases) { filter in
                Button {
                    assignmentFilter = filter
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: filter.systemImage)
                        Text(filter.title)
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(assignmentFilter == filter ? Color.white : Color.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(assignmentFilter == filter ? Color.accentColor : Color(.tertiarySystemFill))
                    }
                }
                .buttonStyle(.plain)
            }
        }
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
            return "tray.fill"
        case .own:
            return "checklist.checked"
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

#Preview {
    AssignmentsTabView(viewModel: AssignmentsViewModel())
}
