import AppKit

/// Hush brand palette, type, and assets. Source of truth: branding/brand-guidelines.html.
enum Brand {
    // Palette — deep plum family only; no greens, reds, or yellows anywhere.
    static let inkPlum = NSColor(red: 0x1C / 255, green: 0x0F / 255, blue: 0x17 / 255, alpha: 1)
    static let hushPlum = NSColor(red: 0x5B / 255, green: 0x2A / 255, blue: 0x48 / 255, alpha: 1)
    static let glow = NSColor(red: 0xB0 / 255, green: 0x6A / 255, blue: 0x8C / 255, alpha: 1)
    static let quietGrey = NSColor(red: 0x8C / 255, green: 0x7A / 255, blue: 0x85 / 255, alpha: 1)
    static let mist = NSColor(red: 0xF6 / 255, green: 0xEF / 255, blue: 0xF2 / 255, alpha: 1)

    /// Display serif for status lines and headings. Never bold.
    static func display(ofSize size: CGFloat) -> NSFont {
        NSFont(name: "Iowan Old Style", size: size)
            ?? NSFont(name: "Palatino", size: size)
            ?? NSFont(name: "Georgia", size: size)
            ?? .systemFont(ofSize: size)
    }

    /// Menu bar glyph, idle: template image (macOS tints for light/dark).
    static let menuBarIdle: NSImage? = {
        let image = NSImage(named: "hush-menubar-idle")
        image?.isTemplate = true
        return image
    }()

    /// Menu bar glyph, active: full-color settling bars.
    static let menuBarActive: NSImage? = {
        let image = NSImage(named: "hush-menubar-active")
        image?.isTemplate = false
        return image
    }()
}
