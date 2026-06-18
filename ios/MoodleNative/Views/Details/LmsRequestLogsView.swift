import MoodleNativeCore
import SwiftUI

struct LmsRequestLogsView: View {
    @State private var entries: [LmsRequestLogEntry] = []
    @State private var isConfirmingClear = false

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "requestLogs.empty.title",
                    systemImage: "list.bullet.rectangle",
                    description: Text("requestLogs.empty.description")
                )
            } else {
                List(entries) { entry in
                    NavigationLink {
                        LmsRequestLogDetailView(entry: entry)
                    } label: {
                        LmsRequestLogRow(entry: entry)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "requestLogs.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if entries.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("requestLogs.action.clear", role: .destructive) {
                        isConfirmingClear = true
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "requestLogs.confirmClear.title"),
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("requestLogs.action.clearAll", role: .destructive) {
                Task {
                    await LmsRequestLogStore.shared.clear()
                    entries = []
                }
            }
        }
        .task {
            entries = await LmsRequestLogStore.shared.entries()
        }
        .refreshable {
            entries = await LmsRequestLogStore.shared.entries()
        }
    }
}

private struct LmsRequestLogRow: View {
    let entry: LmsRequestLogEntry

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yy/M/d HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.hasError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(entry.hasError ? .red : .green)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.context.pageTitle)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(Self.timestampFormatter.string(from: entry.occurredAt))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Text(entry.context.navigationPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(entry.wsFunction)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = entry.errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LmsRequestLogsView()
    }
}
