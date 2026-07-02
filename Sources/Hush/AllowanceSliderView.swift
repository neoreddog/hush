import AppKit

/// A menu-embedded slider for the allowance — how much of the Mac the
/// watched background task is allowed to use.
final class AllowanceSliderView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let slider = NSSlider()
    private let onChange: (Int) -> Void

    init(onChange: @escaping (Int) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 56))

        label.font = .menuFont(ofSize: NSFont.systemFontSize(for: .small))
        label.textColor = .secondaryLabelColor

        slider.minValue = 5
        slider.maxValue = 95
        slider.integerValue = Settings.cpuLimitPercent
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)
        toolTip = "How much of your Mac the background task is allowed to use."

        for view in [label, slider] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2),
        ])

        updateLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        slider.integerValue = Settings.cpuLimitPercent
        updateLabel()
    }

    @objc private func sliderMoved() {
        // Snap to 5% steps so the value reads cleanly.
        let snapped = (slider.integerValue + 2) / 5 * 5
        slider.integerValue = snapped
        updateLabel()
        onChange(snapped)
    }

    private func updateLabel() {
        label.stringValue = "Allowance: \(slider.integerValue)%"
    }
}
