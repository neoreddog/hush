import AppKit

/// A single row in the Theme submenu. Standard NSMenuItems close the whole
/// menu tree as soon as their action fires, which makes flipping between
/// themes tedious — you'd have to reopen the menu bar dropdown and the
/// submenu for every try. Custom-view menu items don't get that
/// auto-dismiss behavior, so this draws its own hover highlight and
/// checkmark to look like a native item while staying open on click.
final class ThemeMenuRowView: NSView {
    private let theme: Brand.Theme
    private let onSelect: (Brand.Theme) -> Void

    private let checkmark = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let highlight = NSView()
    private var trackingArea: NSTrackingArea?

    init(theme: Brand.Theme, onSelect: @escaping (Brand.Theme) -> Void) {
        self.theme = theme
        self.onSelect = onSelect
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 22))

        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = 4
        highlight.isHidden = true
        highlight.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlight)

        checkmark.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        checkmark.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmark)

        label.stringValue = theme.title
        label.font = .menuFont(ofSize: NSFont.systemFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            highlight.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            highlight.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            highlight.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            highlight.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            checkmark.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            checkmark.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 12),

            label.leadingAnchor.constraint(equalTo: checkmark.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        highlight.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        highlight.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        highlight.isHidden = true
    }

    override func mouseDown(with event: NSEvent) {
        onSelect(theme)
    }

    func refresh() {
        checkmark.isHidden = theme != Settings.theme
    }
}
