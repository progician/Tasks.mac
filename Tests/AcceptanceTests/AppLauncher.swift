import Foundation

/// Launches the app bundle for acceptance testing.
///
/// Reads `AT_BUNDLE_PATH` from the environment (set by `make test`) and
/// returns a running `Process`, or `nil` if the bundle cannot be found.
///
/// Extra entries in `environment` are merged over the inherited process
/// environment, letting tests inject configuration such as `CALDAV_URL`.
func launchApp(environment: [String: String] = [:]) -> Process? {
    guard let bundlePath = ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] else { return nil }
    let execPath = bundlePath + "/Contents/MacOS/Tasks.mac"
    guard FileManager.default.fileExists(atPath: execPath) else { return nil }
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: execPath)
    proc.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    proc.standardOutput = Pipe()
    proc.standardError  = Pipe()
    try? proc.run()
    return proc
}
