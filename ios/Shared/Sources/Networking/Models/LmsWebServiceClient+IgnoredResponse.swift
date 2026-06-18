import Foundation

extension LmsWebServiceClient {
    struct IgnoredResponse: Decodable, Sendable {
        private struct AnyCodingKey: CodingKey {
            var stringValue: String
            var intValue: Int?

            init?(stringValue: String) {
                self.stringValue = stringValue
                intValue = nil
            }

            init?(intValue: Int) {
                stringValue = String(intValue)
                self.intValue = intValue
            }
        }

        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer() {
                if container.decodeNil() {
                    return
                }

                if (try? container.decode(Bool.self)) != nil {
                    return
                }

                if (try? container.decode(Int.self)) != nil {
                    return
                }

                if (try? container.decode(Double.self)) != nil {
                    return
                }

                if (try? container.decode(String.self)) != nil {
                    return
                }
            }

            if (try? decoder.unkeyedContainer()) != nil {
                return
            }

            if (try? decoder.container(keyedBy: AnyCodingKey.self)) != nil {
                return
            }
        }
    }
}
