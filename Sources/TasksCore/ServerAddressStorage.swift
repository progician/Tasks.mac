import Foundation

public struct ServerAddressStorage {
    private static let caldavURLKey = "caldavURL"
    private static let nextcloudServerURLKey = "nextcloudServerURL"
    private static let nextcloudUsernameKey = "nextcloudUsername"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> String? {
        defaults.string(forKey: Self.caldavURLKey)
    }

    public func save(_ url: String) {
        defaults.set(url, forKey: Self.caldavURLKey)
        defaults.synchronize()
    }

    public func saveNextcloudSettings(serverURL: String, username: String) {
        defaults.set(serverURL, forKey: Self.nextcloudServerURLKey)
        defaults.set(username, forKey: Self.nextcloudUsernameKey)
        defaults.synchronize()
    }

    public func loadNextcloudServerURL() -> String? {
        defaults.string(forKey: Self.nextcloudServerURLKey)
    }

    public func loadNextcloudUsername() -> String? {
        defaults.string(forKey: Self.nextcloudUsernameKey)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.caldavURLKey)
        defaults.removeObject(forKey: Self.nextcloudServerURLKey)
        defaults.removeObject(forKey: Self.nextcloudUsernameKey)
        defaults.synchronize()
    }
}
