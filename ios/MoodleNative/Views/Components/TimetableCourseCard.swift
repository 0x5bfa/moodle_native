import SwiftUI

struct TimetableCourseCard: View {
    let course: TimetableCourse
    let edit: TimetableCourseEdit?
    let titleLineLimit: Int
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedTitle(course.title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                ForEach(course.statuses, id: \.self) { status in
                    Image(systemName: status.systemImage)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(status.color)
                        .frame(width: 12, height: 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)

            if let room = course.room {
                Text(room)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(baseBackgroundColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tintOverlayColor)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    borderColor,
                    lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isEditing {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, accentColor)
                    .padding(6)
            }
        }
        .opacity(isEditing ? 0.42 : 1)
    }

    private var accent: TimetableCourseAccent {
        edit?.accent ?? .none
    }

    private var accentColor: Color {
        accent == .none ? Color.accentColor : accent.color
    }

    private var titleColor: Color {
        if accent != .none {
            return accent.color
        }

        return course.isTentative ? Color.accentColor : Color.primary
    }

    private var baseBackgroundColor: Color {
        return Color(.secondarySystemBackground)
    }

    private var tintOverlayColor: Color {
        guard accent != .none else {
            return .clear
        }

        return accent.color.opacity(0.13)
    }

    private var borderColor: Color {
        if accent != .none {
            return accent.color.opacity(0.55)
        }

        return course.isTentative ? Color.accentColor.opacity(0.35) : Color(.separator).opacity(0.18)
    }

    private func formattedTitle(_ value: String) -> String {
        let characters = Array(value)
        guard characters.count > 1 else {
            return value
        }

        var result = ""

        for index in characters.indices {
            let current = characters[index]
            result.append(current)

            let nextIndex = characters.index(after: index)
            if nextIndex < characters.endIndex,
                shouldInsertBreak(after: current, before: characters[nextIndex])
            {
                result.append("\u{200B}")
            }
        }

        return result
    }

    private func shouldInsertBreak(after current: Character, before next: Character) -> Bool {
        isTimetableWordCharacter(current) && isTimetableWordCharacter(next)
    }

    private func isTimetableWordCharacter(_ character: Character) -> Bool {
        switch character {
        case "A"..."Z", "a"..."z", "0"..."9", "(", ")", "-", "&", "/", "+", ".":
            return true
        default:
            return false
        }
    }
}
