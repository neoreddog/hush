#!/usr/bin/env swift
// Draws the Hush DMG installer window background: calm Mist canvas with a soft
// Plum arrow pointing from the app toward the Applications folder.
// Usage: swift scripts/dmg-background.swift <out.png> <scale>
import AppKit

// Window content size, in points. Icons are placed on top of this by Finder.
let W: CGFloat = 640
let H: CGFloat = 400

// Brand palette
func hex(_ s: String, _ a: CGFloat = 1) -> NSColor {
    var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let mistTop = hex("FBF8FA")
let mistBot = hex("F1E8EE")
let plum    = hex("5B2A48")
let glow    = hex("B06A8C")
let quiet   = hex("8C7A85")

func render(scale: CGFloat, to path: String) {
    let pxW = Int(W * scale), pxH = Int(H * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pxW, pixelsHigh: pxH,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = NSSize(width: W, height: H) // point size -> maps to hi-dpi pixels
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // AppKit origin is bottom-left; author in top-left coords via this helper.
    func y(_ top: CGFloat) -> CGFloat { H - top }

    // Soft vertical wash for a little depth.
    NSGradient(starting: mistTop, ending: mistBot)?
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    // Icon centers (must match the positions set in make-dmg.sh).
    let leftC  = CGPoint(x: 192, y: 172)   // Hush.app icon center (top-left coords)
    let rightC = CGPoint(x: 448, y: 172)   // Applications folder center
    let midX   = (leftC.x + rightC.x) / 2

    // The arrow: a clean shaft with a chevron head, rounded and plum.
    let yc = y(leftC.y)
    let x0 = midX - 40, x1 = midX + 40, hh: CGFloat = 24
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: x0, y: yc))
    arrow.line(to: CGPoint(x: x1, y: yc))
    arrow.move(to: CGPoint(x: x1 - hh, y: yc + hh))
    arrow.line(to: CGPoint(x: x1, y: yc))
    arrow.line(to: CGPoint(x: x1 - hh, y: yc - hh))
    arrow.lineWidth = 15
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    plum.setStroke()
    arrow.stroke()

    // Quiet, jargon-free instruction along the bottom.
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let text = "Drag Hush into your Applications folder"
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
        .foregroundColor: quiet,
        .paragraphStyle: para,
    ]
    (text as NSString).draw(in: NSRect(x: 0, y: y(360), width: W, height: 22),
                            withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

let args = CommandLine.arguments
guard args.count >= 3, let scale = Double(args[2]) else {
    FileHandle.standardError.write("usage: dmg-background.swift <out.png> <scale>\n".data(using: .utf8)!)
    exit(1)
}
render(scale: CGFloat(scale), to: args[1])
