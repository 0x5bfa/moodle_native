import SwiftUI

struct NotificationRow: View {
    let notification: NotificationListItem
    var isSelecting = false
    var isSelected = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectionColor)
                    .padding(.top, 2)
            } else {
                Circle()
                    .fill(notification.isUnread ? Color.accentColor : Color.clear)
                    .frame(width: 8, height: 8)
                    .padding(.top, 8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                VStack(alignment: .leading) {
                    Text(notification.sourceTitle)
                        .font(.headline)
                        .lineLimit(1)

                    Text(notification.title)
                        .font(.body)
                        .lineLimit(1)

                    Text(notification.preview)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(timestampText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .opacity(isSelecting && notification.isUnread == false ? 0.55 : 1)
    }

    private var selectionColor: Color {
        if notification.isUnread == false {
            return .secondary
        }

        return isSelected ? .accentColor : .secondary
    }

    private var timestampText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitsStyle = .full
        return formatter.localizedString(for: notification.receivedAt, relativeTo: .now)
    }
}
