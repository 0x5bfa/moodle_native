import SwiftUI

struct LoadingOverlayCard: View {
    private let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        ProgressView(title)
            .padding(20)
    }
}
