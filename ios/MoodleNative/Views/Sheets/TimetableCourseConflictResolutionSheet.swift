import SwiftUI

struct TimetableCourseConflictResolutionSheet: View {
    private static let noSelectionID = ""

    let conflicts: [TimetableCourseConflict]
    let weekdayLabel: (Int) -> String
    let onResolve: ([String: String]) -> Void

    @State private var selections: [String: String]

    init(
        conflicts: [TimetableCourseConflict],
        weekdayLabel: @escaping (Int) -> String,
        onResolve: @escaping ([String: String]) -> Void
    ) {
        self.conflicts = conflicts
        self.weekdayLabel = weekdayLabel
        self.onResolve = onResolve
        self._selections = State(initialValue: [:])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("timetableConflict.message")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .listRowBackground(Color.clear)
                }

                ForEach(conflicts) { conflict in
                    Section(conflictTitle(for: conflict)) {
                        Picker("timetableConflict.coursePicker", selection: selectionBinding(for: conflict)) {
                            Text("common.select")
                                .tag(Self.noSelectionID)

                            ForEach(conflict.courses) { course in
                                Text(course.title)
                                    .tag(course.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "timetableConflict.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        onResolve(selections)
                    }
                    .disabled(hasSelectionsForAllConflicts == false)
                }
            }
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }

    private var hasSelectionsForAllConflicts: Bool {
        conflicts.allSatisfy { conflict in
            guard let selectedCourseID = selections[conflict.id] else {
                return false
            }

            return conflict.courses.contains { $0.id == selectedCourseID }
        }
    }

    private func conflictTitle(for conflict: TimetableCourseConflict) -> String {
        String.localizedStringWithFormat(
            String(localized: "timetableConflict.sectionTitle"),
            weekdayLabel(conflict.dayIndex),
            conflict.periodTitle
        )
    }

    private func selectionBinding(for conflict: TimetableCourseConflict) -> Binding<String> {
        Binding {
            selections[conflict.id] ?? Self.noSelectionID
        } set: { newValue in
            selections[conflict.id] = newValue
        }
    }
}
