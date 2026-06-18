import SwiftUI
import MoodleNativeFeatures

struct NotificationDetailSectionView: View {
    let section: LmsNotificationDetailPresentation.Section

    var body: some View {
        if let title = section.title {
            Section(title) {
                ForEach(section.rows) { row in
                    NotificationDetailRowView(row: row)
                }
            }
        } else {
            Section {
                ForEach(section.rows) { row in
                    NotificationDetailRowView(row: row)
                }
            }
        }
    }
}
