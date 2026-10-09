import Carbon
import Cocoa

/// The global shortcut that opens Clips. Stored in UserDefaults so it can be changed in Settings.
final class HotKey {
    static let shared = HotKey()

    static let defaultKeyCode = kVK_Space
    static let defaultModifiers = cmdKey | shiftKey
    static let defaultLabel = "⇧⌘Space"

    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private let defaults = UserDefaults.standard

    var label: String { defaults.string(forKey: "hotKeyLabel") ?? Self.defaultLabel }

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.shared.onPress?()
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// Registers the saved shortcut. Returns false if another app already owns it.
    @discardableResult
    func register() -> Bool {
        unregister()
        let status = RegisterEventHotKey(UInt32(defaults.integer(forKey: "hotKeyCode")),
                                         UInt32(defaults.integer(forKey: "hotKeyModifiers")),
                                         EventHotKeyID(signature: 0x434C_4950, id: 1),
                                         GetApplicationEventTarget(), 0, &ref)
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    /// Switches to a new shortcut, keeping the old one if the new one can't be registered.
    func change(keyCode: Int, modifiers: Int, label: String) -> Bool {
        let old = (defaults.integer(forKey: "hotKeyCode"), defaults.integer(forKey: "hotKeyModifiers"), self.label)
        save(keyCode, modifiers, label)
        if register() { return true }
        save(old.0, old.1, old.2)
        register()
        return false
    }

    func reset() -> Bool { change(keyCode: Self.defaultKeyCode, modifiers: Self.defaultModifiers, label: Self.defaultLabel) }

    private func save(_ keyCode: Int, _ modifiers: Int, _ label: String) {
        defaults.set(keyCode, forKey: "hotKeyCode")
        defaults.set(modifiers, forKey: "hotKeyModifiers")
        defaults.set(label, forKey: "hotKeyLabel")
    }

    // MARK: Converting a key press

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.shift) { m |= shiftKey }
        if flags.contains(.option) { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        return m
    }

    static func label(for event: NSEvent) -> String {
        let f = event.modifierFlags
        let mods = (f.contains(.control) ? "⌃" : "") + (f.contains(.option) ? "⌥" : "")
            + (f.contains(.shift) ? "⇧" : "") + (f.contains(.command) ? "⌘" : "")
        return mods + keyName(event)
    }

    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func keyName(_ event: NSEvent) -> String {
        if let name = namedKeys[Int(event.keyCode)] { return name }
        return (event.characters(byApplyingModifiers: []) ?? "?").uppercased()
    }
}
