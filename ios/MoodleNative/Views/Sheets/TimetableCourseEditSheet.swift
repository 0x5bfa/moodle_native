import SwiftUI

struct TimetableCourseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let course: TimetableCourse
    let isFavorite: Bool?
    let toggleFavorite: (@MainActor (Bool) async throws -> Void)?
    @Binding var edit: TimetableCourseEdit

    @State private var favoriteOverride: Bool?
    @State private var isUpdatingFavorite = false
    @State private var favoriteErrorMessage: String?

    init(
        course: TimetableCourse,
        isFavorite: Bool? = nil,
        toggleFavorite: (@MainActor (Bool) async throws -> Void)? = nil,
        edit: Binding<TimetableCourseEdit>
    ) {
        self.course = course
        self.isFavorite = isFavorite
        self.toggleFavorite = toggleFavorite
        _edit = edit
        _favoriteOverride = State(initialValue: isFavorite)
    }

    var body: some View {
        NavigationStack {
            List {
                Text(course.title)
                    .lineLimit(2)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .listRowBackground(Color.clear)

                Section("timetableCourseEdit.accent.section") {
                    HStack {
                        ForEach(displayedAccents) { accent in
                            Button {
                                edit.accent = accent
                            } label: {
                                TimetableAccentSwatch(
                                    accent: accent,
                                    isSelected: edit.accent == accent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("timetableCourseEdit.attendance.section") {
                    HStack {
                        ForEach(TimetableAttendanceStatus.allCases) { status in
                            AttendanceCountButton(
                                status: status,
                                count: edit.attendanceCount(for: status),
                                onTap: {
                                    edit.incrementAttendance(status)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("timetableCourseEdit.memo.section") {
                    TextEditor(text: $edit.memo)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle(String(localized: "timetableCourseEdit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let currentFavorite {
                    ToolbarItem(placement: .topBarLeading) {
                        if isUpdatingFavorite {
                            ProgressView()
                        } else {
                            Button {
                                updateFavorite(to: currentFavorite == false)
                            } label: {
                                Image(systemName: currentFavorite ? "star.fill" : "star")
                                    .foregroundStyle(currentFavorite ? Color.yellow : Color.primary)
                            }
                            .disabled(toggleFavorite == nil)
                            .accessibilityLabel(
                                currentFavorite
                                    ? Text("timetableCourseEdit.favorite.remove")
                                    : Text("timetableCourseEdit.favorite.add")
                            )
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
            }
        }
        .alert("timetableCourseEdit.favorite.unavailable.title", isPresented: favoriteErrorIsPresented) {
            Button("OK", role: .cancel) {
                favoriteErrorMessage = nil
            }
        } message: {
            Text(favoriteErrorMessage ?? "")
        }
        .presentationDetents([.medium, .large], selection: .constant(.large))
        .presentationBackground(Color(.systemBackground))
    }

    private var displayedAccents: [TimetableCourseAccent] {
        TimetableCourseAccent.allCases.filter { $0 != .pink }
    }

    private var currentFavorite: Bool? {
        favoriteOverride ?? isFavorite
    }

    private var favoriteErrorIsPresented: Binding<Bool> {
        Binding(
            get: {
                favoriteErrorMessage != nil
            },
            set: { isPresented in
                if isPresented == false {
                    favoriteErrorMessage = nil
                }
            }
        )
    }

    private func updateFavorite(to newValue: Bool) {
        guard let toggleFavorite else {
            return
        }

        favoriteErrorMessage = nil
        isUpdatingFavorite = true

        Task {
            do {
                try await toggleFavorite(newValue)
                await MainActor.run {
                    favoriteOverride = newValue
                    isUpdatingFavorite = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    isUpdatingFavorite = false
                }
            } catch {
                await MainActor.run {
                    favoriteErrorMessage = message(for: error)
                    isUpdatingFavorite = false
                }
            }
        }
    }

    private func message(for error: Error) -> String {
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

        return String(localized: "timetableCourseEdit.favorite.error.updateFailed")
    }
}

private struct AttendanceCountButton: View {
    let status: TimetableAttendanceStatus
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(status.color)
                        .frame(width: 42, height: 42)

                    Text(count, format: .number)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.white)
                }

                Text(status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(status.title)
        .accessibilityValue(Text("\(count)"))
        .accessibilityHint("timetableCourseEdit.attendance.incrementHint")
    }
}
