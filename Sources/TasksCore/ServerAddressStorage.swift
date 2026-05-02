import Foundation

public struct ServerAddressStorage {
    private static let key = "caldavURL"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> String? {
        defaults.string(forKey: Self.key)
    }

    public func save(_ url: String) {
        defaults.set(url, forKey: Self.key)
        defaults.synchronize()
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
        defaults.synchronize()
    }
}
