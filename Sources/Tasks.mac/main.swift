import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 800, height: 600)
        let width: CGFloat = 480
        let height: CGFloat = 120
        let rect = NSRect(x: (screenSize.width - width) / 2,
                          y: (screenSize.height - height) / 2,
                          width: width,
                          height: height)

        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.title = "Main Window"

        let label = NSTextField(labelWithString: "Welcome — Acceptance Test")
        label.font = NSFont.systemFont(ofSize: 20)
        label.alignment = .center
        label.frame = NSRect(x: 20, y: (height - 30) / 2, width: width - 40, height: 30)
        label.isSelectable = false

        // Add the label to the window's content view
        window.contentView?.addSubview(label)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // nothing for now
    }
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
