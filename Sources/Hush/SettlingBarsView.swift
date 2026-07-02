import AppKit

/// The brand's settling-equalizer motif, live in the menu bar: five bars
/// hold their height, ease down into the idle glyph's resting dots, sit
/// quiet, then rise again. Timing mirrors the `hush` keyframes in
/// branding/brand-guidelines.html — 4.8s cycle, settled from 38% to 58%,
/// staggered left to right.
final class SettlingBarsView: NSView {
    private static let tallHeights: [CGFloat] = [7, 11, 5, 14, 9]
    private static let dotHeight: CGFloat = 3
    private static let barWidth: CGFloat = 3
    private static let gap: CGFloat = 2

    /// Static menu bar glyphs drawn from the same geometry as the
    /// animation, so the icon never shifts between states. Resting is
    /// the flat dots in muted plum; active is the raised bars in the
    /// brand gradient.
    static func glyph(resting: Bool) -> NSImage {
        let size = NSSize(width: 26, height: 16)
        return NSImage(size: size, flipped: false) { _ in
            let count = tallHeights.count
            let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
            let originX = (size.width - totalWidth) / 2
            let baseline = (size.height - (tallHeights.max() ?? 0)) / 2
            for (index, tall) in tallHeights.enumerated() {
                let rect = NSRect(
                    x: originX + CGFloat(index) * (barWidth + gap),
                    y: baseline,
                    width: barWidth,
                    height: resting ? dotHeight : tall
                )
                let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
                if resting {
                    Brand.quietGrey.setFill()
                    path.fill()
                } else {
                    NSGradient(starting: Brand.glow, ending: Brand.hushPlum)?.draw(in: path, angle: -90)
                }
            }
            return true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Let clicks fall through to the status bar button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        rebuild()
    }

    override func layout() {
        super.layout()
        rebuild()
    }

    private func rebuild() {
        guard let layer, bounds.width > 0 else { return }
        layer.sublayers = nil

        let count = Self.tallHeights.count
        let totalWidth = CGFloat(count) * Self.barWidth + CGFloat(count - 1) * Self.gap
        let originX = (bounds.width - totalWidth) / 2
        let maxTall = Self.tallHeights.max() ?? 0
        let baseline = (bounds.height - maxTall) / 2
        let start = CACurrentMediaTime()

        for (index, tall) in Self.tallHeights.enumerated() {
            let bar = CAGradientLayer()
            // Guidelines: linear-gradient(180deg, glow, plum) — glow on top.
            bar.colors = [Brand.glow.cgColor, Brand.hushPlum.cgColor]
            bar.startPoint = CGPoint(x: 0.5, y: 1)
            bar.endPoint = CGPoint(x: 0.5, y: 0)
            bar.cornerRadius = Self.barWidth / 2
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            bar.position = CGPoint(
                x: originX + CGFloat(index) * (Self.barWidth + Self.gap) + Self.barWidth / 2,
                y: baseline
            )
            bar.bounds = CGRect(x: 0, y: 0, width: Self.barWidth, height: Self.dotHeight)
            layer.addSublayer(bar)

            // Rest → rise → hold → settle → rest, easing both ways so the
            // loop has no jump.
            let settle = CAKeyframeAnimation(keyPath: "bounds.size.height")
            settle.values = [Self.dotHeight, tall, tall, Self.dotHeight, Self.dotHeight]
            settle.keyTimes = [0, 0.12, 0.42, 0.6, 1]
            settle.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .linear),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .linear),
            ]
            settle.duration = 4.8
            settle.repeatCount = .infinity
            settle.beginTime = start + Double(index) * 0.12
            bar.add(settle, forKey: "hush")
        }
    }
}
