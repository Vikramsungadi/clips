import Carbon
import Cocoa
import ImageIO

/// A borderless panel that can take keyboard input without activating the app,
/// so the app you were using stays in front and can receive the paste.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Draws the selected row as a rounded accent-coloured highlight, even though the search field has keyboard focus.
final class ClipRowView: NSTableRowView {
    override var isEmphasized: Bool { get { true } set {} }

    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 10, yRadius: 10).fill()
    }
}

/// One row: [thumbnail, images only] title …… [pin] [⌘n] [save, images only]
final class ClipCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("ClipCell")
    let thumb = NSImageView()
    let title = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let pin = NSImageView(image: NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")!)
    let hint = NSTextField(labelWithString: "")
    let save = NSButton(image: NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Save image")!,
                        target: nil, action: nil)
    private var titleAfterThumb: NSLayoutConstraint!
    private var titleAtEdge: NSLayoutConstraint!
    private var titleCentered: NSLayoutConstraint!
    private var titleRaised: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)
        identifier = Self.id
        thumb.imageScaling = .scaleProportionallyDown
        thumb.wantsLayer = true
        thumb.layer?.cornerRadius = 5
        thumb.layer?.masksToBounds = true
        title.font = .systemFont(ofSize: 14)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        pin.contentTintColor = .systemOrange
        pin.symbolConfiguration = .init(pointSize: 11, weight: .regular)
        hint.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .right
        save.isBordered = false
        save.contentTintColor = .secondaryLabelColor
        save.symbolConfiguration = .init(pointSize: 15, weight: .regular)

        for v in [thumb, title, subtitle, pin, hint, save] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        titleAfterThumb = title.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12)
        titleAtEdge = title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10)
        titleCentered = title.centerYAnchor.constraint(equalTo: centerYAnchor)
        titleRaised = title.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 1)
        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumb.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 64),
            thumb.heightAnchor.constraint(equalToConstant: 44),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: pin.leadingAnchor, constant: -8),
            title.trailingAnchor.constraint(lessThanOrEqualTo: pin.leadingAnchor, constant: -8),
            pin.trailingAnchor.constraint(equalTo: hint.leadingAnchor, constant: -6),
            pin.centerYAnchor.constraint(equalTo: centerYAnchor),
            hint.trailingAnchor.constraint(equalTo: save.leadingAnchor, constant: -6),
            hint.centerYAnchor.constraint(equalTo: centerYAnchor),
            hint.widthAnchor.constraint(equalToConstant: 26),
            save.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            save.centerYAnchor.constraint(equalTo: centerYAnchor),
            save.widthAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Image rows: thumbnail plus a second line of details. Text rows: one line, no thumbnail.
    func configure(thumbnail image: NSImage?, details: String?) {
        thumb.image = image
        thumb.isHidden = image == nil
        titleAfterThumb.isActive = image != nil
        titleAtEdge.isActive = image == nil
        subtitle.stringValue = details ?? ""
        subtitle.isHidden = details == nil
        titleCentered.isActive = details == nil
        titleRaised.isActive = details != nil
    }
}

/// One image in the Images grid: big thumbnail, details underneath, ⌘ hint and save button.
final class ImageTile: NSView {
    let image = NSImageView()
    let caption = NSTextField(labelWithString: "")
    let hint = NSTextField(labelWithString: "")
    let save = NSButton(image: NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Save image")!,
                        target: nil, action: nil)
    var onClick: (() -> Void)?
    var isSelected = false { didSet { updateLook() } }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        image.imageScaling = .scaleProportionallyDown
        image.wantsLayer = true
        image.layer?.cornerRadius = 8
        image.layer?.masksToBounds = true
        caption.font = .systemFont(ofSize: 12)
        caption.lineBreakMode = .byTruncatingTail
        caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hint.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        save.isBordered = false
        save.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        for v in [image, caption, hint, save] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            image.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            image.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            image.bottomAnchor.constraint(equalTo: caption.topAnchor, constant: -6),
            caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            caption.trailingAnchor.constraint(lessThanOrEqualTo: hint.leadingAnchor, constant: -6),
            hint.trailingAnchor.constraint(equalTo: save.leadingAnchor, constant: -6),
            hint.centerYAnchor.constraint(equalTo: caption.centerYAnchor),
            save.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            save.centerYAnchor.constraint(equalTo: caption.centerYAnchor),
        ])
        updateLook()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }

    private func updateLook() {
        layer?.backgroundColor = (isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.85)
                                             : NSColor.white.withAlphaComponent(0.06)).cgColor
        caption.textColor = isSelected ? .white : .secondaryLabelColor
        hint.textColor = isSelected ? .white : .secondaryLabelColor
        save.contentTintColor = isSelected ? .white : .secondaryLabelColor
    }
}

/// A row of the Images grid holding two tiles.
final class GridRowCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("GridRowCell")
    let tiles = [ImageTile(), ImageTile()]

    init() {
        super.init(frame: .zero)
        identifier = Self.id
        for t in tiles {
            t.translatesAutoresizingMaskIntoConstraints = false
            addSubview(t)
        }
        NSLayoutConstraint.activate([
            tiles[0].leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            tiles[1].leadingAnchor.constraint(equalTo: tiles[0].trailingAnchor, constant: 10),
            tiles[1].trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            tiles[0].widthAnchor.constraint(equalTo: tiles[1].widthAnchor),
            tiles[0].topAnchor.constraint(equalTo: topAnchor, constant: 3),
            tiles[0].bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            tiles[1].topAnchor.constraint(equalTo: topAnchor, constant: 3),
            tiles[1].bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class PanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    var onOpenSettings: (() -> Void)?

    private enum Tab: Int, CaseIterable {
        case all, text, images, saved
        var title: String { ["All", "Text", "Images", "Saved"][rawValue] }
    }

    private static let width: CGFloat = 640
    private static let textRowHeight: CGFloat = 32
    private static let imageRowHeight: CGFloat = 56
    private static let gridRowHeight: CGFloat = 156
    private static let savedRowHeight: CGFloat = 50

    private let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 460),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let search = NSTextField()
    private let tabs = NSSegmentedControl(labels: Tab.allCases.map(\.title), trackingMode: .selectOne, target: nil, action: nil)
    private let table = NSTableView()
    private let empty = NSTextField(labelWithString: "")
    private let footer = NSTextField(labelWithString: "")
    private let clearImagesButton = NSButton(title: "Clear images", target: nil, action: nil)

    private var shown: [Clip] = []
    private var selection = 0                     // index into `shown`
    private var isGrid: Bool { tab == .images }   // the Images tab is a 2-column grid
    private var keyMonitor: Any?
    private var lastHidden = Date.distantPast
    private var confirmClearUntil = Date.distantPast
    private var naming: (clip: Clip, isRename: Bool)?   // set while the search box is asking for a name
    private var confirmDelete: (id: UUID, until: Date)?
    private var askedForAccessibility = false
    private let thumbnails = NSCache<NSString, NSImage>()

    private var footerHints: String {
        switch tab {
        case .saved: return "↑↓ move   ↩ paste   ⇥ tab   ⌘0–9 pick   ⌘R rename   ⌘⌫ delete   esc close"
        case .images: return "←→↑↓ move   ↩ paste   ⇥ tab   ⌘0–9 pick   ⌘D save   ⌘S download   ⌘⌫ delete"
        default: return "↑↓ move   ↩ paste   ⇥ tab   ⌘0–9 pick   ⌘D save   ⌘P pin   ⌘⌫ delete   esc close"
        }
    }

    /// Shows a message in the footer for a moment, then the shortcut hints again.
    private func flashFooter(_ message: String, error: Bool = false) {
        footer.stringValue = message
        footer.textColor = error ? .systemRed : .secondaryLabelColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.footer.stringValue == message else { return }
            self.resetFooter()
        }
    }

    private func resetFooter() {
        footer.stringValue = footerHints
        footer.textColor = .tertiaryLabelColor
    }

    /// The open tab, remembered between launches. "All" the first time.
    private var tab: Tab {
        get { Tab(rawValue: UserDefaults.standard.integer(forKey: "lastTab")) ?? .all }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "lastTab") }
    }

    override init() {
        super.init()
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let background = NSView()
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 24
            glass.contentView = background
            // Clip to the rounded shape so nothing (or the shadow) shows in the square corners.
            glass.wantsLayer = true
            glass.layer?.cornerRadius = 24
            glass.layer?.cornerCurve = .continuous
            glass.layer?.masksToBounds = true
            panel.contentView = glass
        } else {
            let blur = NSVisualEffectView()
            blur.material = .hudWindow
            blur.state = .active
            blur.blendingMode = .behindWindow
            blur.wantsLayer = true
            blur.layer?.cornerRadius = 24
            blur.layer?.masksToBounds = true
            blur.layer?.borderWidth = 1
            blur.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
            background.translatesAutoresizingMaskIntoConstraints = false
            blur.addSubview(background)
            NSLayoutConstraint.activate([
                background.topAnchor.constraint(equalTo: blur.topAnchor),
                background.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
                background.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
                background.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            ])
            panel.contentView = blur
        }

        let searchIcon = NSImageView(image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)!)
        searchIcon.symbolConfiguration = .init(pointSize: 18, weight: .medium)
        searchIcon.contentTintColor = .secondaryLabelColor
        search.placeholderString = "Search clips"
        search.font = .systemFont(ofSize: 22)
        search.isBordered = false
        search.drawsBackground = false
        search.focusRingType = .none
        search.delegate = self

        tabs.target = self
        tabs.action = #selector(tabClicked)
        tabs.controlSize = .regular
        tabs.refusesFirstResponder = true

        let separator = NSBox()
        separator.boxType = .separator

        table.headerView = nil
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip")))
        table.style = .plain
        table.backgroundColor = .clear
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked)
        table.refusesFirstResponder = true

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        empty.textColor = .secondaryLabelColor
        empty.alignment = .center

        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .tertiaryLabelColor
        footer.lineBreakMode = .byTruncatingTail
        footer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        clearImagesButton.isBordered = false
        clearImagesButton.font = .systemFont(ofSize: 11)
        clearImagesButton.contentTintColor = .secondaryLabelColor
        clearImagesButton.target = self
        clearImagesButton.action = #selector(clearImagesClicked)

        for v in [searchIcon, search, tabs, separator, scroll, empty, footer, clearImagesButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(v)
        }
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            searchIcon.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
            searchIcon.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            search.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            search.trailingAnchor.constraint(equalTo: tabs.leadingAnchor, constant: -12),
            tabs.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            tabs.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            separator.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
            empty.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            empty.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            footer.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            footer.trailingAnchor.constraint(lessThanOrEqualTo: clearImagesButton.leadingAnchor, constant: -10),
            footer.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -12),
            clearImagesButton.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            clearImagesButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])

        ClipStore.shared.onChange = { [weak self] in
            guard let self else { return }
            self.prepareThumbnails()
            if self.panel.isVisible { self.reload(keepSelection: true) }
        }
        prepareThumbnails()
    }

    // MARK: Showing and hiding

    func toggle() {
        if panel.isVisible { hide(); return }
        // Clicking the menu bar icon while open first hides the panel (it loses focus); don't reopen it.
        if Date().timeIntervalSince(lastHidden) < 0.25 { return }
        show()
    }

    func show() {
        endNaming()
        confirmDelete = nil
        search.stringValue = ""
        tabs.selectedSegment = tab.rawValue
        resetFooter()
        resetClearButton()
        reload(keepSelection: false)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let f = screen.frame
        let top = f.maxY - f.height * 0.2
        let height = fittingHeight()
        panel.setFrame(NSRect(x: f.midX - Self.width / 2, y: top - height, width: Self.width, height: height), display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()   // recompute the shadow from the rounded shape, not the square window
        panel.makeFirstResponder(search)
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in self?.handleShortcut(e) ?? e }
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        lastHidden = Date()
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    func windowDidResignKey(_ notification: Notification) { hide() }

    // MARK: Tabs

    @objc private func tabClicked() {
        tab = Tab(rawValue: tabs.selectedSegment) ?? .all
        resetFooter()
        reload(keepSelection: false)
    }

    private func switchTab(by step: Int) {
        let count = Tab.allCases.count
        tab = Tab(rawValue: (tab.rawValue + step + count) % count)!
        tabs.selectedSegment = tab.rawValue
        resetFooter()
        reload(keepSelection: false)
    }

    // MARK: List

    private func reload(keepSelection: Bool) {
        let selectedID = keepSelection && shown.indices.contains(selection) ? shown[selection].id : nil
        let query = search.stringValue
        let source = tab == .saved ? ClipStore.shared.saved : ClipStore.shared.ordered
        shown = source.filter { clip in
            switch tab {
            case .all, .saved: break
            case .text: if clip.isImage { return false }
            case .images: if !clip.isImage { return false }
            }
            return query.isEmpty || clip.text.localizedCaseInsensitiveContains(query)
                || (clip.name?.localizedCaseInsensitiveContains(query) ?? false)
        }
        table.reloadData()
        empty.isHidden = !shown.isEmpty
        empty.stringValue = !query.isEmpty ? "No clips match “\(query)”."
            : tab == .images ? "No images yet. Screenshots and copied images will show up here."
            : tab == .saved ? "Nothing saved yet. Press ⌘D on any clip to name it and keep it forever."
            : "No clips yet. Copy something and it will show up here."
        select(shown.firstIndex { $0.id == selectedID } ?? 0)
        clearImagesButton.isHidden = tab == .text || tab == .saved || !ClipStore.shared.clips.contains { $0.isImage && !$0.pinned }
        if panel.isVisible {
            // Grow or shrink downwards, keeping the search box where it is.
            let h = fittingHeight(), f = panel.frame
            if abs(h - f.height) > 0.5 {
                panel.setFrame(NSRect(x: f.minX, y: f.maxY - h, width: f.width, height: h), display: true)
                panel.invalidateShadow()
            }
        }
    }

    /// Search box + rows + footer, capped so long histories scroll.
    private func fittingHeight() -> CGFloat {
        let gap = table.intercellSpacing.height
        let rows = shown.isEmpty ? 70
            : isGrid ? CGFloat((shown.count + 1) / 2) * (Self.gridRowHeight + gap) + 6
            : shown.reduce(6) { $0 + rowHeight($1) + gap }
        return 64 + min(rows, isGrid ? 480 : 400) + 40
    }

    private func rowHeight(_ clip: Clip) -> CGFloat {
        clip.isImage ? Self.imageRowHeight : clip.name != nil ? Self.savedRowHeight : Self.textRowHeight
    }

    private func select(_ index: Int) {
        guard shown.indices.contains(index) else { return }
        let old = selection
        selection = index
        if isGrid {
            table.deselectAll(nil)
            let rows = IndexSet([old / 2, index / 2].filter { $0 < table.numberOfRows })
            table.reloadData(forRowIndexes: rows, columnIndexes: [0])
            table.scrollRowToVisible(index / 2)
        } else {
            table.selectRowIndexes([index], byExtendingSelection: false)
            table.scrollRowToVisible(index)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { isGrid ? (shown.count + 1) / 2 : shown.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        isGrid ? Self.gridRowHeight : rowHeight(shown[row])
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { ClipRowView() }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if isGrid { return gridCell(row) }
        let cell = tableView.makeView(withIdentifier: ClipCell.id, owner: nil) as? ClipCell ?? ClipCell()
        let clip = shown[row]
        if let name = clip.name {
            cell.title.stringValue = name
            cell.title.font = .systemFont(ofSize: 14, weight: .semibold)
            cell.configure(thumbnail: clip.isImage ? thumbnail(for: clip) : nil, details: oneLine(clip.text))
        } else if clip.isImage {
            cell.title.font = .systemFont(ofSize: 14)
            // Stored as "Image 3456×2234": show "Image" with the size and age underneath.
            let size = clip.text.replacingOccurrences(of: "Image ", with: "")
            cell.title.stringValue = "Image"
            cell.configure(thumbnail: thumbnail(for: clip),
                           details: size + "  ·  " + Self.ago.localizedString(for: clip.date, relativeTo: Date()))
        } else {
            cell.title.font = .systemFont(ofSize: 14)
            cell.title.stringValue = oneLine(clip.text)
            cell.configure(thumbnail: nil, details: nil)
        }
        cell.pin.isHidden = !clip.pinned
        cell.hint.stringValue = row < 10 ? "⌘\(row)" : ""
        cell.save.isHidden = !clip.isImage
        cell.save.target = self
        cell.save.action = #selector(saveClicked(_:))
        cell.save.tag = row
        cell.save.toolTip = "Save to \(Settings.saveFolder.lastPathComponent)  (⌘S)"
        cell.toolTip = clip.isImage ? nil : String(clip.text.prefix(1000))
        return cell
    }

    private func gridCell(_ row: Int) -> NSView {
        let cell = table.makeView(withIdentifier: GridRowCell.id, owner: nil) as? GridRowCell ?? GridRowCell()
        for (column, tile) in cell.tiles.enumerated() {
            let index = row * 2 + column
            guard shown.indices.contains(index) else { tile.isHidden = true; continue }
            let clip = shown[index]
            tile.isHidden = false
            tile.image.image = thumbnail(for: clip, maxPixels: Self.gridThumb)
            let size = clip.text.replacingOccurrences(of: "Image ", with: "")
            tile.caption.stringValue = (clip.pinned ? "Pinned  ·  " : "") + size + "  ·  "
                + Self.ago.localizedString(for: clip.date, relativeTo: Date())
            tile.hint.stringValue = index < 10 ? "⌘\(index)" : ""
            tile.save.target = self
            tile.save.action = #selector(saveClicked(_:))
            tile.save.tag = index
            tile.save.toolTip = "Save to \(Settings.saveFolder.lastPathComponent)  (⌘S)"
            tile.isSelected = index == selection
            tile.onClick = { [weak self] in self?.choose(index) }
        }
        return cell
    }

    /// The clip squashed onto one line. Only the start is used: a row can't show more, and huge clips stay cheap.
    private func oneLine(_ text: String) -> String {
        String(text.prefix(300)).components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static let ago: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    // MARK: Thumbnails

    private static let listThumb = 176   // pixels on the long side: 64×44 pt rows at 2×
    private static let gridThumb = 600   // grid tiles
    private let thumbQueue = DispatchQueue(label: "clips.thumbnails", qos: .userInitiated)
    private var loading = Set<String>()

    /// Returns the thumbnail if it's ready; otherwise starts making it in the background and
    /// refreshes the row when done, so switching tabs never waits on image decoding.
    private func thumbnail(for clip: Clip, maxPixels: Int = listThumb) -> NSImage? {
        guard let file = clip.image, let url = ClipStore.shared.imageURL(clip) else { return nil }
        let key = "\(maxPixels)-\(file)"
        if let cached = thumbnails.object(forKey: key as NSString) { return cached }
        guard loading.insert(key).inserted else { return nil }
        thumbQueue.async { [weak self] in
            let image = Self.makeThumbnail(url, maxPixels: maxPixels)
            DispatchQueue.main.async {
                guard let self else { return }
                self.loading.remove(key)
                guard let image else { return }
                self.thumbnails.setObject(image, forKey: key as NSString)
                self.refreshRows(showing: file)
            }
        }
        return nil
    }

    /// Decodes the image directly at thumbnail size (much cheaper than loading the full screenshot).
    private static func makeThumbnail(_ url: URL, maxPixels: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixels,
              ] as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
    }

    private func refreshRows(showing file: String) {
        guard panel.isVisible else { return }
        let indexes = shown.indices.filter { shown[$0].image == file }
        let rows = IndexSet(indexes.map { isGrid ? $0 / 2 : $0 }.filter { $0 < table.numberOfRows })
        if !rows.isEmpty { table.reloadData(forRowIndexes: rows, columnIndexes: [0]) }
    }

    /// Makes thumbnails for every image ahead of time, so they're ready before a tab needs them.
    private func prepareThumbnails() {
        let images = (ClipStore.shared.clips + ClipStore.shared.saved).filter(\.isImage)
        for clip in images {
            _ = thumbnail(for: clip)
            _ = thumbnail(for: clip, maxPixels: Self.gridThumb)
        }
    }

    @objc private func rowClicked() {
        if !isGrid && table.clickedRow >= 0 { choose(table.clickedRow) }
    }

    // MARK: Keyboard

    func controlTextDidChange(_ obj: Notification) {
        if naming == nil { reload(keepSelection: false) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if naming != nil {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)): finishNaming()
            case #selector(NSResponder.cancelOperation(_:)): endNaming()
            case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:)),
                 #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)): break
            default: return false
            }
            return true
        }
        switch selector {
        case #selector(NSResponder.moveUp(_:)): select(selection - (isGrid ? 2 : 1))
        case #selector(NSResponder.moveDown(_:)): select(min(selection + (isGrid ? 2 : 1), shown.count - 1))
        case #selector(NSResponder.moveLeft(_:)) where isGrid: select(selection - 1)
        case #selector(NSResponder.moveRight(_:)) where isGrid: select(selection + 1)
        case #selector(NSResponder.insertTab(_:)): switchTab(by: 1)
        case #selector(NSResponder.insertBacktab(_:)): switchTab(by: -1)
        case #selector(NSResponder.insertNewline(_:)): choose(selection)
        case #selector(NSResponder.cancelOperation(_:)): hide()
        default: return false
        }
        return true
    }

    /// ⌘-shortcuts while the panel is open; everything else (typing, ⌘A, ⌘C…) goes to the search field.
    private func handleShortcut(_ e: NSEvent) -> NSEvent? {
        guard panel.isKeyWindow, naming == nil,
              e.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else { return e }
        let key = e.charactersIgnoringModifiers ?? ""
        if let n = Int(key) {
            choose(n)
            return nil
        }
        let selected = shown.indices.contains(selection) ? shown[selection] : nil
        switch (Int(e.keyCode), key) {
        case (kVK_Delete, _): if let c = selected { delete(c) }
        case (_, "d"): if let c = selected, tab != .saved { startNaming(c, isRename: false) }
        case (_, "r"): if let c = selected, tab == .saved { startNaming(c, isRename: true) }
        case (_, "p"): if let c = selected, tab != .saved { ClipStore.shared.togglePin(c) }
        case (_, "s"): if let c = selected, c.isImage { saveImage(c) }
        case (_, ","): hide(); onOpenSettings?()
        default: return e
        }
        return nil
    }

    // MARK: Saving and clearing images

    @objc private func saveClicked(_ sender: NSButton) {
        if shown.indices.contains(sender.tag) { saveImage(shown[sender.tag]) }
    }

    /// Saves to the chosen folder and briefly confirms in the footer.
    private func saveImage(_ clip: Clip) {
        if let url = ClipStore.shared.exportImage(clip) {
            flashFooter("Downloaded to \(url.deletingLastPathComponent().lastPathComponent) ✓  \(url.lastPathComponent)")
        } else {
            flashFooter("Couldn't save the image.", error: true)
        }
    }

    /// First click asks for confirmation; a second click within 3 seconds clears.
    @objc private func clearImagesClicked() {
        if Date() < confirmClearUntil {
            resetClearButton()
            ClipStore.shared.clearImages()
            return
        }
        confirmClearUntil = Date().addingTimeInterval(3)
        clearImagesButton.title = "Click again to clear all images"
        clearImagesButton.contentTintColor = .systemRed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if let self, Date() >= self.confirmClearUntil { self.resetClearButton() }
        }
    }

    private func resetClearButton() {
        confirmClearUntil = .distantPast
        clearImagesButton.title = "Clear images"
        clearImagesButton.contentTintColor = .secondaryLabelColor
    }

    // MARK: Saved clips

    /// Turns the search box into a name field for saving (⌘D) or renaming (⌘R).
    private func startNaming(_ clip: Clip, isRename: Bool) {
        naming = (clip, isRename)
        tabs.isEnabled = false
        search.placeholderString = "Name this clip"
        search.stringValue = clip.name ?? suggestedName(clip)
        search.currentEditor()?.selectAll(nil)
        footer.stringValue = isRename ? "Type a new name   ↩ rename   esc cancel" : "Type a name   ↩ save forever   esc cancel"
        footer.textColor = .secondaryLabelColor
    }

    private func finishNaming() {
        guard let (clip, isRename) = naming else { return }
        let typed = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = typed.isEmpty ? suggestedName(clip) : typed
        endNaming()
        if isRename {
            ClipStore.shared.rename(clip, to: name)
            flashFooter("Renamed to “\(name)” ✓")
        } else {
            ClipStore.shared.saveForever(clip, name: name)
            flashFooter("Saved as “\(name)” ✓  Find it in the Saved tab.")
        }
    }

    private func endNaming() {
        guard naming != nil else { return }
        naming = nil
        tabs.isEnabled = true
        search.placeholderString = "Search clips"
        search.stringValue = ""
        resetFooter()
        reload(keepSelection: true)
    }

    private func suggestedName(_ clip: Clip) -> String {
        let line = oneLine(clip.text)
        return line.count > 40 ? String(line.prefix(40)) + "…" : line
    }

    /// History clips delete straight away; saved clips need a second ⌘⌫ within 3 seconds.
    private func delete(_ clip: Clip) {
        guard tab == .saved else { ClipStore.shared.delete(clip); return }
        if let pending = confirmDelete, pending.id == clip.id, Date() < pending.until {
            confirmDelete = nil
            ClipStore.shared.deleteSaved(clip)
            flashFooter("Deleted “\(clip.name ?? "clip")”")
        } else {
            confirmDelete = (clip.id, Date().addingTimeInterval(3))
            flashFooter("Press ⌘⌫ again to delete “\(clip.name ?? "clip")” for good", error: true)
        }
    }

    // MARK: Choosing a clip

    private func choose(_ row: Int) {
        guard shown.indices.contains(row) else { return }
        let clip = shown[row]
        hide()
        ClipStore.shared.copyToClipboard(clip)
        if Settings.pasteDirectly { pasteIntoFrontApp() }
    }

    /// Sends ⌘V to the app that was in front when the panel opened.
    private func pasteIntoFrontApp() {
        guard AXIsProcessTrusted() else {
            if !askedForAccessibility {
                askedForAccessibility = true
                _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: down)
                e?.flags = .maskCommand
                e?.post(tap: .cghidEventTap)
            }
        }
    }
}
