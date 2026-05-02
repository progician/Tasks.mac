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
