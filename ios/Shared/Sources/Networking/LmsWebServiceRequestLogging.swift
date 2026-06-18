import Foundation
import MoodleNativeCore

public protocol LmsWebServiceRequestLogging: Actor {
    func record(
        context: LmsRequestLogContext,
        wsFunction: String,
        parameters: [URLQueryItem],
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?
    )
}
