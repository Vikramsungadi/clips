import Carbon
import Cocoa
import ServiceManagement
import SwiftUI

enum Settings {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            "maxItems": 80,
            "pasteDirectly": true,
            "skipSecrets": true,
            "saveImages": true,
            "saveFolder": FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path,
            "ignoredApps": "com.1password.1password, com.bitwarden.desktop, com.apple.Passwords, com.apple.keychainaccess",
            "hotKeyCode": HotKey.defaultKeyCode,
            "hotKeyModifiers": HotKey.defaultModifiers,
            "hotKeyLabel": HotKey.defaultLabel,
        ])
    }

    static var maxItems: Int { defaults.integer(forKey: "maxItems") }
    static var pasteDirectly: Bool { defaults.bool(forKey: "pasteDirectly") }
    static var skipSecrets: Bool { defaults.bool(forKey: "skipSecrets") }
    static var saveImages: Bool { defaults.bool(forKey: "saveImages") }
    static var saveFolder: URL { URL(fileURLWithPath: defaults.string(forKey: "saveFolder")!) }
    static var ignoredApps: Set<String> {
        Set((defaults.string(forKey: "ignoredApps") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }
}

/// Records a new global shortcut: click the button, then press the keys.
final class ShortcutRecorder: ObservableObject {
    @Published var label = HotKey.shared.label
    @Published var recording = false
    @Published var message = ""
    private var monitor: Any?

    func start() {
        message = ""
        recording = true
        HotKey.shared.unregister()   // so pressing the current shortcut doesn't open the panel
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handle(e)
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        HotKey.shared.register()
    }

    func reset() {
        stop()
        if !HotKey.shared.reset() { message = "\(HotKey.defaultLabel) is being used by another app." }
        label = HotKey.shared.label
    }

    private func handle(_ e: NSEvent) {
        let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if e.keyCode == kVK_Escape && flags.isEmpty { stop(); return }
        guard !flags.intersection([.command, .control, .option]).isEmpty else {
            message = "Include ⌘, ⌃ or ⌥ in the shortcut."
            return
        }
        let newLabel = HotKey.label(for: e)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        if HotKey.shared.change(keyCode: Int(e.keyCode), modifiers: HotKey.carbonModifiers(flags), label: newLabel) {
            message = ""
        } else {
            message = "\(newLabel) is being used by another app. Try a different one."
        }
        label = HotKey.shared.label
    }
}

struct SettingsView: View {
    @AppStorage("maxItems") private var maxItems = 80
    @AppStorage("pasteDirectly") private var pasteDirectly = true
    @AppStorage("skipSecrets") private var skipSecrets = true
    @AppStorage("saveImages") private var saveImages = true
    @AppStorage("saveFolder") private var saveFolder = ""
    @AppStorage("ignoredApps") private var ignoredApps = ""
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @StateObject private var recorder = ShortcutRecorder()

    var body: some View {
        Form {
            Section {
                LabeledContent("Open Clips with") {
                    HStack {
                        Button(recorder.recording ? "Press new shortcut…" : recorder.label) {
                            recorder.recording ? recorder.stop() : recorder.start()
                        }
                        .frame(minWidth: 150)
                        if recorder.label != HotKey.defaultLabel && !recorder.recording {
                            Button("Reset") { recorder.reset() }
                        }
                    }
                }
                if !recorder.message.isEmpty {
                    Text(recorder.message).foregroundStyle(.red).font(.callout)
                } else if recorder.recording {
                    Text("Press the keys you want to use, or Esc to cancel.").foregroundStyle(.secondary).font(.callout)
                }
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in
                        if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                    }
            }
            Section {
                Picker("Keep history", selection: $maxItems) {
                    ForEach([20, 50, 80, 150, 300], id: \.self) { Text("\($0) clips") }
                }
                Toggle("Save copied images", isOn: $saveImages)
                LabeledContent("Save images to") {
                    HStack {
                        Text((saveFolder as NSString).abbreviatingWithTildeInPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") { chooseSaveFolder() }
                    }
                }
                Toggle("Paste into the current app after choosing a clip", isOn: $pasteDirectly)
                Toggle("Don't save passwords, tokens and API keys", isOn: $skipSecrets)
            }
            Section("Don't save copies from these apps (bundle IDs, comma separated)") {
                TextField("", text: $ignoredApps, axis: .vertical)
                    .labelsHidden()
                    .lineLimit(2...4)
            }
            Section {
                Button("Clear images (keeps pinned images)") { ClipStore.shared.clearImages() }
                Button("Clear history (keeps pinned clips)") { ClipStore.shared.clearUnpinned() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize()
        .onDisappear { if recorder.recording { recorder.stop() } }
    }

    private func chooseSaveFolder() {
        let open = NSOpenPanel()
        open.canChooseDirectories = true
        open.canChooseFiles = false
        open.canCreateDirectories = true
        open.prompt = "Use This Folder"
        open.directoryURL = URL(fileURLWithPath: saveFolder)
        if open.runModal() == .OK, let url = open.url { saveFolder = url.path }
    }
}

final class SettingsWindow {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Clips Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
