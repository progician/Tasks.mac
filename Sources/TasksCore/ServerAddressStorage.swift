import Foundation

public struct ServerAddressStorage {
    private static let key = "caldavURL"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> String? {
        nil
    }

    public func save(_ url: String) {
    }

    public func clear() {
    }
}
