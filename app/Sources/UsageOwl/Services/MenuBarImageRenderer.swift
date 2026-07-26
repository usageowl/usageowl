import AppKit

/// Composes the entire menu bar label into ONE template NSImage.
///
/// MenuBarExtra's label bridging flattens the label view hierarchy into a
/// single AppKit representation and drops every image child after the first
/// (offscreen ImageRenderer checks can't reproduce this — it only happens in
/// the real status item). A single pre-composed bitmap is the certain fix.
enum MenuBarImageRenderer {
    struct Item {
        let glyph: NSImage   // 14x14 template glyph (from ProviderGlyph.Images)
        let text: String     // "25%" or "--"
        let dimmed: Bool     // true -> text drawn at 55% alpha
    }

    private static let glyphSize = NSSize(width: 14, height: 14)
    private static let glyphTextGap: CGFloat = 2
    private static let itemSpacing: CGFloat = 8
    private static let separatorGap: CGFloat = 6
    private static let separatorSize = NSSize(width: 1, height: 12)
    private static let height: CGFloat = 18  // status item height is 22
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)

    /// Draws all items into one bitmap, template-tinted by macOS at display time.
    /// `leadingOwl` prepends the owl mark with a hairline divider after it.
    @MainActor
    static func render(items: [Item], leadingOwl: Bool = false) -> NSImage {
        var width: CGFloat = leadingOwl
            ? glyphSize.width + separatorGap + separatorSize.width + itemSpacing
            : 0
        for (index, item) in items.enumerated() {
            if index > 0 { width += itemSpacing }
            width += glyphSize.width + glyphTextGap + ceil(textSize(of: item.text).width)
        }
        let size = NSSize(width: max(ceil(width), 1), height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            if leadingOwl {
                ProviderGlyph.Images.template(for: .owl).draw(
                    in: CGRect(x: x, y: (height - glyphSize.height) / 2,
                               width: glyphSize.width, height: glyphSize.height))
                x += glyphSize.width + separatorGap
                NSColor.black.withAlphaComponent(0.35).setFill()
                NSBezierPath(rect: NSRect(x: x, y: (height - separatorSize.height) / 2,
                                          width: separatorSize.width, height: separatorSize.height)).fill()
                x += separatorSize.width + itemSpacing
            }
            for (index, item) in items.enumerated() {
                if index > 0 { x += itemSpacing }
                item.glyph.draw(in: CGRect(x: x, y: (height - glyphSize.height) / 2,
                                           width: glyphSize.width, height: glyphSize.height))
                x += glyphSize.width + glyphTextGap
                let string = NSAttributedString(string: item.text, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.black.withAlphaComponent(item.dimmed ? 0.55 : 1.0),
                ])
                let stringSize = string.size()
                string.draw(at: NSPoint(x: x, y: (height - stringSize.height) / 2))
                x += ceil(stringSize.width)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func textSize(of text: String) -> CGSize {
        (text as NSString).size(withAttributes: [.font: font])
    }
}
