import SwiftUI
import MoodleNativeFeatures

struct NotificationDetailRowView: View {
    let row: LmsNotificationDetailPresentation.Section.Row
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue
    @State private var htmlContentHeight: CGFloat = 1

    var body: some View {
        switch row.content {
        case .text(let value):
            if let label = row.label {
                LabeledContent(label, value: value)
            } else {
                Text(value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .link(let title, let url):
            if let label = row.label {
                LabeledContent(label) {
                    Button(title) {
                        openInApp(url)
                    }
                }
            } else {
                Button(title) {
                    openInApp(url)
                }
            }

        case .html(let html):
            VStack(alignment: .leading, spacing: 8) {
                if let label = row.label {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HtmlBodyView(
                    htmlFragment: html,
                    onOpenURL: openInApp,
                    contentHeight: $htmlContentHeight
                )
                .frame(height: max(htmlContentHeight, 120))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func openInApp(_ url: URL) {
        openURL(url, prefersInApp: prefersInAppExternalLinks)
    }
}
