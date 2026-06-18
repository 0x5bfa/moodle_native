import Foundation
import MoodleNativeCore
import Security

final class LmsAuthenticationStore {
    private let service = "dev.example.MoodleNative.lms-auth-session"
    private let account = "Moodle"
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func load() throws -> LmsAuthenticationSession? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw LmsAuthenticationError.invalidStoredSession
            }

            do {
                return try decoder.decode(LmsAuthenticationSession.self, from: data)
            } catch {
                throw LmsAuthenticationError.invalidStoredSession
            }
        case errSecItemNotFound:
            return nil
        default:
            throw LmsAuthenticationError.keychain(status)
        }
    }

    func save(_ session: LmsAuthenticationSession) throws {
        let data = try encoder.encode(session)
        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: data
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = baseQuery
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            item[kSecValueData] = data

            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw LmsAuthenticationError.keychain(addStatus)
            }

            return
        }

        guard updateStatus == errSecSuccess else {
            throw LmsAuthenticationError.keychain(updateStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LmsAuthenticationError.keychain(status)
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }
}
