import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let panel = PanelController()
    private let settings = SettingsWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        ClipStore.shared.startWatching()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clips")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        panel.onOpenSettings = { [weak self] in self?.settings.show() }
        HotKey.shared.onPress = { [weak self] in self?.panel.toggle() }
        if !HotKey.shared.register() {
            settings.show()   // the saved shortcut is taken by another app; let the user pick a new one
        }

        // Open at login by default; it can be turned off in Settings.
        if !UserDefaults.standard.bool(forKey: "didFirstLaunch") {
            UserDefaults.standard.set(true, forKey: "didFirstLaunch")
            try? SMAppService.mainApp.register()
        }
    }

    /// Left click opens the clips panel; right click shows the app menu.
    @objc private func statusItemClicked() {
        guard NSApp.currentEvent?.type == .rightMouseUp else { panel.toggle(); return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Clips (\(HotKey.shared.label))", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit Clips", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func applicationWillTerminate(_ notification: Notification) { ClipStore.shared.flush() }

    @objc private func openPanel() { panel.show() }
    @objc private func openSettings() { settings.show() }
    @objc private func clearHistory() { ClipStore.shared.clearUnpinned() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
