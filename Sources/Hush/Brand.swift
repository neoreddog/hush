import AppKit

/// Hush brand palette, type, and assets. Source of truth: branding/brand-guidelines.html.
enum Brand {
    // Palette — deep plum family only; no greens, reds, or yellows anywhere.
    static let inkPlum = NSColor(red: 0x1C / 255, green: 0x0F / 255, blue: 0x17 / 255, alpha: 1)
    static let hushPlum = NSColor(red: 0x5B / 255, green: 0x2A / 255, blue: 0x48 / 255, alpha: 1)
    static let glow = NSColor(red: 0xB0 / 255, green: 0x6A / 255, blue: 0x8C / 255, alpha: 1)
    static let quietGrey = NSColor(red: 0x8C / 255, green: 0x7A / 255, blue: 0x85 / 255, alpha: 1)
    static let mist = NSColor(red: 0xF6 / 255, green: 0xEF / 255, blue: 0xF2 / 255, alpha: 1)

    // Dynamic colors: the plum values are dark and vanish against a
    // dark-mode menu, so dark mode swaps to the lighter glow tone.
    static let headline = dynamic(light: hushPlum, dark: glow)
    static let accent = dynamic(light: hushPlum, dark: glow)

    /// The dropdown's ground — the three brand surfaces. Each theme
    /// forces a menu appearance so the dynamic text and slider colors
    /// resolve legibly against its wash.
    enum Theme: String, CaseIterable {
        case ink, mist, plum

        var title: String { "Hush on \(rawValue.capitalized)" }

        /// Wash laid over the menu's material. Returned as a plain color
        /// (not dynamic) because it lands on a CALayer.
        var wash: NSColor {
            switch self {
            case .ink: return Brand.inkPlum.withAlphaComponent(0.85)
            case .mist: return Brand.mist.withAlphaComponent(0.85)
            case .plum: return Brand.hushPlum.withAlphaComponent(0.85)
            }
        }

        var appearance: NSAppearance? {
            switch self {
            case .mist: return NSAppearance(named: .aqua)
            case .ink, .plum: return NSAppearance(named: .darkAqua)
            }
        }

        /// Headline/accent color, fixed per theme rather than resolved from
        /// the system's light/dark appearance. An open NSMenu freezes its
        /// appearance for the duration of tracking, so a dynamic NSColor
        /// tied to `effectiveAppearance` would never repaint while flipping
        /// through themes with the submenu held open — this sidesteps that
        /// by picking the concrete color ourselves.
        var headlineColor: NSColor {
            self == .mist ? Brand.hushPlum : Brand.glow
        }

        /// Text color for native NSMenuItem titles (Theme, Advanced, Quit).
        /// These are system-drawn, so — same reasoning as `headlineColor` —
        /// they need an attributed title with an explicit color to repaint
        /// while the menu stays open across a theme switch.
        var itemTextColor: NSColor {
            self == .mist ? Brand.inkPlum : Brand.mist
        }
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    /// Display serif for status lines and headings. Never bold.
    static func display(ofSize size: CGFloat) -> NSFont {
        NSFont(name: "Iowan Old Style", size: size)
            ?? NSFont(name: "Palatino", size: size)
            ?? NSFont(name: "Georgia", size: size)
            ?? .systemFont(ofSize: size)
    }

    // Menu bar glyphs, drawn from SettlingBarsView's geometry so idle,
    // static-active, and the live animation all line up exactly. Idle is
    // muted plum — deliberately dimmed, never the system's white tint.
    static let menuBarIdle: NSImage? = SettlingBarsView.glyph(resting: true)
    static let menuBarActive: NSImage? = SettlingBarsView.glyph(resting: false)
}
