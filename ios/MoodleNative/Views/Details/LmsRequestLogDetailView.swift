import MoodleNativeCore
import SwiftUI

struct LmsRequestLogDetailView: View {
    let entry: LmsRequestLogEntry

    var body: some View {
        List {
            Section("requestLogDetail.screen.section") {
                LabeledContent("requestLogDetail.title", value: entry.context.pageTitle)
                LabeledContent("requestLogDetail.navigationPath", value: entry.context.navigationPath)
                LabeledContent(
                    "requestLogDetail.time",
                    value: entry.occurredAt.formatted(date: .complete, time: .standard)
                )
                LabeledContent(
                    "requestLogDetail.result",
                    value: entry.hasError
                        ? String(localized: "requestLogDetail.result.error")
                        : String(localized: "requestLogDetail.result.success")
                )
            }

            Section("requestLogDetail.request.section") {
                LabeledContent("wsfunction", value: entry.wsFunction)
                if let statusCode = entry.statusCode {
                    LabeledContent("HTTP status", value: String(statusCode))
                }

                if entry.parameters.isEmpty == false {
                    ForEach(Array(entry.parameters.enumerated()), id: \.offset) { _, parameter in
                        LabeledContent(parameter.name, value: parameter.value ?? "<nil>")
                    }
                }
            }

            if let errorMessage = entry.errorMessage, errorMessage.isEmpty == false {
                Section("requestLogDetail.error.section") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("requestLogDetail.responseJSON.section") {
                ScrollView(.horizontal) {
                    Text(entry.responseBody.isEmpty ? "<empty response>" : entry.responseBody)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(entry.context.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
