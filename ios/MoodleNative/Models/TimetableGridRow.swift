import Foundation

struct TimetableGridRow: Identifiable {
    let id: String
    let title: String
    let courses: [TimetableCourse?]
}
