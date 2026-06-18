import Foundation

enum AppSettings {
    enum AppIdentity {
        static let displayName = "Moodle Native"
    }

    enum MoodleSite {
        static let defaultURLString = "https://moodle.example.edu"
        static let overrideEnvironmentKey = "MOODLE_NATIVE_SITE_URL"

        static func resolvedURL() -> URL {
            if let rawOverride = ProcessInfo.processInfo.environment[overrideEnvironmentKey] {
                let override = rawOverride.trimmingCharacters(in: .whitespacesAndNewlines)
                if override.isEmpty == false, let overrideURL = URL(string: override) {
                    return overrideURL
                }
            }

            return URL(string: defaultURLString) ?? fallbackURL
        }

        private static var fallbackURL: URL {
            URL(string: defaultURLString)!
        }
    }

    enum NextClassLiveActivity {
        static let storageKey = "settings.nextClassLiveActivityEnabled"
        static let defaultValue = true

        static var isEnabled: Bool {
            UserDefaults.standard.object(forKey: storageKey) as? Bool ?? defaultValue
        }
    }

    enum ExternalLinks {
        static let preferInAppStorageKey = "settings.externalLinksPreferInApp"
        static let preferInAppDefaultValue = true
    }
}
