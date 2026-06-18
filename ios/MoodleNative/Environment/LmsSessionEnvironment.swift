import MoodleNativeCore
import SwiftUI

private struct LmsSessionEnvironmentKey: EnvironmentKey {
    static let defaultValue: LmsAuthenticationSession? = nil
}

extension EnvironmentValues {
    var lmsSession: LmsAuthenticationSession? {
        get { self[LmsSessionEnvironmentKey.self] }
        set { self[LmsSessionEnvironmentKey.self] = newValue }
    }
}
