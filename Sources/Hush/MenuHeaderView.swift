import AppKit

/// The dropdown's status header — serif headline over a quiet sub line.
/// A custom view rather than disabled menu items, because macOS dims
/// disabled items to grey and ignores their attributed colors.
final class MenuHeaderView: NSView {
    private let headline = NSTextField(labelWithString: "")
    private let sub = NSTextField(labelWithString: "")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 58))

        headline.font = Brand.display(ofSize: 19)
        headline.textColor = Settings.theme.headlineColor
        sub.font = .menuFont(ofSize: NSFont.systemFontSize(for: .small))
        sub.textColor = Brand.quietGrey

        for view in [headline, sub] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            headline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            headline.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            headline.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            sub.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            sub.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            sub.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 3),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Washes the whole dropdown plum. NSMenu offers no supported way to
    /// color its background, so once this view is hosted in the menu's
    /// window we walk up to the backing material view and slip a tinted
    /// view beneath the items. If macOS restructures that hierarchy the
    /// walk finds nothing and the menu just keeps its stock background.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }

        var ancestor = superview
        while let view = ancestor, !(view is NSVisualEffectView) { ancestor = view.superview }
        guard let material = ancestor else { return }

        if let tint = material.subviews.first(where: { $0.identifier == Self.tintID }) {
            tint.layer?.backgroundColor = Settings.theme.wash.cgColor
            return
        }
        let tint = NSView(frame: material.bounds)
        tint.identifier = Self.tintID
        tint.autoresizingMask = [.width, .height]
        tint.wantsLayer = true
        tint.layer?.backgroundColor = Settings.theme.wash.cgColor
        material.addSubview(tint, positioned: .below, relativeTo: material.subviews.first)
    }

    private static let tintID = NSUserInterfaceItemIdentifier("hush-menu-tint")

    func update(headline headlineText: String, sub subText: String) {
        headline.stringValue = headlineText
        sub.stringValue = subText
    }

    /// Re-applies the wash and text color for the current theme. Needed
    /// when the theme changes while the menu is open (picking a theme from
    /// its submenu no longer closes the menu): `viewDidMoveToWindow` only
    /// fires once when the menu first opens, and an already-open NSMenu
    /// freezes its own appearance for the duration of tracking, so we can't
    /// rely on dynamic, appearance-resolved colors to repaint themselves.
    func applyTheme() {
        headline.textColor = Settings.theme.headlineColor
        headline.needsDisplay = true

        guard window != nil else { return }
        var ancestor: NSView? = superview
        while let view = ancestor, !(view is NSVisualEffectView) { ancestor = view.superview }
        guard let material = ancestor,
              let tint = material.subviews.first(where: { $0.identifier == Self.tintID })
        else { return }
        tint.layer?.backgroundColor = Settings.theme.wash.cgColor
    }
}
