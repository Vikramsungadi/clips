# Clips — project context

Keyboard-first clipboard history for macOS (14+), built as a native AppKit app compiled with `swiftc` (no Xcode project). Lives in the menu bar, opens a Spotlight-style Liquid Glass panel with ⇧⌘Space.

## Origin

Started as a replacement for the free CopyClip app, whose menu bar popup had no global shortcut. A first workaround (a background helper that faked a click on CopyClip's menu bar icon) needed timing hacks for full-screen apps, so Clips was written to own the whole flow: its own hotkey, its own panel, no fake clicks.

## Layout

```
Sources/
  main.swift       App delegate: menu bar icon (left click = panel, right click = menu), hotkey wiring, open-at-login on first run
  HotKey.swift     Global shortcut via Carbon RegisterEventHotKey; stored in UserDefaults; change/reset with rollback if taken
  ClipStore.swift  Clipboard polling, history + Saved storage, image files, secret filtering, background disk I/O
  Panel.swift      The panel: search, tabs, list/grid, keyboard handling, thumbnails, paste-into-app
  Settings.swift   UserDefaults-backed settings + SwiftUI Settings window + shortcut recorder
makeicon.swift     Draws the app icon (paperclip on blue–purple squircle)
build.sh           Compile → icon → sign → install to /Applications → relaunch
docs/screenshots/  README images
```

Data: `~/Library/Application Support/Clips/` → `history.json`, `saved.json`, `images/<sha256-prefix>.png`.

## Behaviour and decisions (keep these unless asked)

- **Panel**: borderless non-activating `NSPanel` (`KeyPanel`) so the previous app stays frontmost and receives the ⌘V paste. Level `.popUpMenu`, `.canJoinAllSpaces` + `.fullScreenAuxiliary` so it opens over full-screen apps. Centered horizontally, top at 20% of the screen. Hides when it loses key.
- **Look**: `NSGlassEffectView` (Liquid Glass) on macOS 26, `NSVisualEffectView` blur fallback. 24pt continuous corners; layer is clipped and `invalidateShadow()` is called after show/resize, otherwise square corners show.
- **Single list layout.** A right-side preview pane was tried and **rejected** by the user — don't reintroduce it.
- **Tabs**: All / Text / Images / Saved, segmented control at the right of the search bar. Default All; the last used tab is remembered (`lastTab`). ⇥ / ⇧⇥ cycle tabs.
- **Rows**: text rows 32pt, one line. Image rows 56pt (taller on purpose), thumbnail + "Image" + "W×H · age". Saved rows 50pt: bold name + one-line preview.
- **Images tab is a 2-column grid** (`GridRowCell` with two `ImageTile`s, rows of 156pt). Selection is tracked by `selection` (index into `shown`), not by table selection; ←→ move by 1, ↑↓ by 2.
- **Panel height fits content** (capped: 400 list / 480 grid), growing downward; only resized when the height actually changes.
- **Shortcuts**: ↩ paste, ⌘0–9 quick pick (⌘0 = newest, CopyClip-style), ⌘P pin, ⌘D save to Saved (name prompt in the search field), ⌘R rename (Saved tab), ⌘S download image, ⌘⌫ delete (Saved needs a second ⌘⌫ within 3 s), ⌘, settings, esc close. Footer hints change per tab.
- **Saved** clips are a separate list, never trimmed or cleared by Clear History / Clear images; saving identical content again renames instead of duplicating.
- **Pinned** clips stay at the top of history and survive the history limit and clears.
- **Text vs image**: if a copy has both (Excel, Word), keep the text. Finder file copies are recorded as their name, not as files.
- **Secrets**: skip pasteboard types marked concealed/transient (nspasteboard.org), apps in the ignore list, and text matching token patterns (GitHub, OpenAI/Anthropic `sk-`, AWS `AKIA`, Slack `xox*`, private key blocks). Random passwords typed in notes can't be detected.
- **Paste into app** posts ⌘V via `CGEvent` and needs Accessibility permission; without it Clips only copies and asks once.
- **Images download** (⌘S / ⬇) to the folder in Settings, default `~/Downloads`, named `Clip <date> at <time>.png`. Clear images needs two clicks (confirm), keeps pinned.

## Performance rules (measured, don't regress)

- Never decode full images on the main thread. Thumbnails use ImageIO (`CGImageSourceCreateThumbnailAtIndex`) at 176px (list) / 600px (grid), made on a background queue, cached in `NSCache`, pre-warmed at launch and on every change. Uncached cells show empty and refresh when ready. (Old approach: ~70 ms per image on main → laggy tab switches.)
- New images are processed off-main: PNG data from the pasteboard is stored as-is (screenshots), TIFF is converted in the background. (Was ~160 ms main-thread hitch per screenshot.)
- History/Saved JSON is written on a background queue, debounced 0.3 s; `flush()` on quit.
- Row text uses only the first 300 characters before collapsing whitespace.

## Build, sign, release

```sh
./build.sh                       # build + install to /Applications + relaunch
ditto -c -k --sequesterRsrc --keepParent build/Clips.app build/Clips.zip
gh release create vX.Y build/Clips.zip --repo Vikramsungadi/clips --title "Clips X.Y" --notes "…"
```

- Signing uses a local self-signed identity named **"Vikram Local Code Signing"** in the login keychain (falls back to ad-hoc). A stable identity keeps the Accessibility permission across rebuilds — ad-hoc signing makes macOS forget it on every build.
- Releases are not notarized: users must right-click → Open the first time (or remove the quarantine attribute). Notarization needs a paid Apple Developer account.
- GitHub: repo `Vikramsungadi/clips`, pushed with the GitHub CLI signed in as Vikramsungadi. The gh credential helper is set **only in this repo's git config**, not globally, so other repos on the machine keep their own accounts. Commits use the account's GitHub noreply email.

## Ideas not done yet

- Store copied files (Finder) as files, like Maccy.
- Larger image preview on hover / Quick Look (space bar).
- Rich text / HTML clips; per-clip source app icon.
- App Store or notarized distribution (needs sandboxing; auto-paste via Accessibility gets extra review).
- MIT or other license (none chosen yet).
