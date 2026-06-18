import Foundation

extension KeyedDecodingContainer {
    func decodeBoolishIfPresent(forKey key: Key) throws -> Bool? {
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }

        if let value = try? decode(Int.self, forKey: key) {
            return value != 0
        }

        if let value = try? decode(String.self, forKey: key) {
            switch value.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }

        return nil
    }

    func decodeStringishIfPresent(forKey key: Key) throws -> String? {
        if try decodeNil(forKey: key) {
            return nil
        }

        if let value = try? decode(String.self, forKey: key) {
            return value
        }

        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }

        if let value = try? decode(Bool.self, forKey: key) {
            return value ? "1" : "0"
        }

        return nil
    }
}
