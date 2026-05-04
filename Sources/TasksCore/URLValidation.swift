import Foundation

public func isValidCalDAVURL(_ string: String) -> Bool {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let url = URL(string: trimmed),
          let scheme = url.scheme,
          ["http", "https"].contains(scheme.lowercased()),
          let host = url.host, !host.isEmpty
    else { return false }
    return true
}

public func constructNextcloudCalDAVURL(serverURL: String, username: String) -> String {
    let base = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
    return "\(base)/remote.php/dav/calendars/\(username)/"
}

/// If the provided base URL looks like a Nextcloud server root and we have
/// stored Nextcloud settings (server URL + username) that refer to the same
/// host, return the constructed CalDAV URL for that Nextcloud user.
/// Otherwise, return the original `base` unchanged.
public func resolveNextcloudCalDAVURLIfNeeded(base: String, storedServerURL: String?, storedUsername: String?) -> String {
    guard let storedServerURL, let storedUsername else { return base }
    guard let baseURL = URL(string: base), let storedURL = URL(string: storedServerURL) else { return base }

    // If base already contains the WebDAV path, leave it alone.
    if base.contains("/remote.php/dav/") { return base }

    // Only amend when hosts match and base path is effectively the server root.
    let baseIsRoot = (baseURL.path.isEmpty || baseURL.path == "/")
    if baseIsRoot && baseURL.host?.lowercased() == storedURL.host?.lowercased() {
        return constructNextcloudCalDAVURL(serverURL: storedServerURL, username: storedUsername)
    }

    return base
}
