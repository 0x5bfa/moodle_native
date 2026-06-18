import SwiftUI
import WidgetKit

/// ホーム画面ウィジェットと次の授業 Live Activity をまとめる WidgetBundle
@main
struct AppWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextClassWidget()
        NextClassLiveActivity()
    }
}
