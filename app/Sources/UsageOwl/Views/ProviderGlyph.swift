import SwiftUI
import AppKit

/// Geometric provider marks drawn in code — no asset files.
/// Crisp at 14–16pt and legible both monochrome and in brand color.
struct ProviderGlyph: View {
    enum Kind {
        case claude, kimi, codex, copilot, moonshot, owl

        init(providerID: String) {
            switch providerID {
            case "claude": self = .claude
            case "kimi": self = .kimi
            case "codex": self = .codex
            case "copilot": self = .copilot
            case "moonshot": self = .moonshot
            default: self = .owl
            }
        }
    }

    let kind: Kind
    var color: Color = .primary

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            switch kind {
            case .claude: Self.drawClaude(context: context, center: center, radius: radius, color: color)
            case .kimi: Self.drawKimi(context: context, center: center, radius: radius, color: color)
            case .codex: Self.drawCodex(context: context, center: center, radius: radius, color: color)
            case .copilot: Self.drawCopilot(context: context, center: center, radius: radius, color: color)
            case .moonshot: Self.drawMoonshot(context: context, center: center, radius: radius, color: color)
            case .owl: Self.drawOwl(context: context, center: center, radius: radius, color: color)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Claude: 6 tapered petals rotated around the center (asterisk/starburst).
    private static func drawClaude(context: GraphicsContext, center c: CGPoint, radius r: CGFloat, color: Color) {
        let halfWidth = r * 0.17
        for i in 0..<6 {
            var petal = Path()
            petal.move(to: CGPoint(x: -halfWidth, y: -r * 0.16))
            petal.addLine(to: CGPoint(x: 0, y: -r))
            petal.addLine(to: CGPoint(x: halfWidth, y: -r * 0.16))
            petal.closeSubpath()
            var ctx = context
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: .degrees(Double(i) * 60))
            ctx.fill(petal, with: .color(color))
        }
    }

    /// Kimi: crescent moon — filled circle with an offset circular cutout.
    private static func drawKimi(context: GraphicsContext, center c: CGPoint, radius r: CGFloat, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(color))
        var cut = context
        cut.blendMode = .destinationOut
        let cr = r * 0.84
        let cc = CGPoint(x: c.x + r * 0.55, y: c.y - r * 0.22)
        cut.fill(Path(ellipseIn: CGRect(x: cc.x - cr, y: cc.y - cr, width: 2 * cr, height: 2 * cr)),
                 with: .color(.black))
    }

    /// Codex: filled hexagon with an inner circle punched out.
    private static func drawCodex(context: GraphicsContext, center c: CGPoint, radius r: CGFloat, color: Color) {
        var hex = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
            if i == 0 { hex.move(to: point) } else { hex.addLine(to: point) }
        }
        hex.closeSubpath()
        context.fill(hex, with: .color(color))
        var cut = context
        cut.blendMode = .destinationOut
        let cr = r * 0.36
        cut.fill(Path(ellipseIn: CGRect(x: c.x - cr, y: c.y - cr, width: 2 * cr, height: 2 * cr)),
                 with: .color(.black))
    }

    /// Copilot: 4-point spark (concave diamond).
    private static func drawCopilot(context: GraphicsContext, center c: CGPoint, radius r: CGFloat, color: Color) {
        let k = r * 0.16
        var spark = Path()
        spark.move(to: CGPoint(x: c.x, y: c.y - r))
        spark.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        spark.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        spark.closeSubpath()
        context.fill(spark, with: .color(color))
    }

    /// Moonshot: planet with an orbit ring.
    private static func drawMoonshot(context: GraphicsContext, center c: CGPoint, radius r: CGFloat, color: Color) {
        var ring = context
        ring.translateBy(x: c.x, y: c.y)
        ring.rotate(by: .degrees(-24))
        ring.stroke(Path(ellipseIn: CGRect(x: -r, y: -r * 0.34, width: 2 * r, height: r * 0.68)),
                    with: .color(color), lineWidth: r * 0.16)
        let pr = r * 0.58
        context.fill(Path(ellipseIn: CGRect(x: c.x - pr, y: c.y - pr, width: 2 * pr, height: 2 * pr)),
                     with: .color(color))
    }

    /// UsageOwl mark: ears, ringed face, eyes with pupils, beak — the full logo.
    /// Geometry mirrors the 64x64 brand SVG so menu bar, popup and site match.
    private static func drawOwl(context: GraphicsContext, center c: CGPoint, radius r: CGFloat, color: Color) {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: c.x + (x - 32) / 32 * r, y: c.y + (y - 32) / 32 * r)
        }
        // ears
        for (a, b, d) in [(15, 9, 15), (49, 9, 49)] as [(CGFloat, CGFloat, CGFloat)] {
            var ear = Path()
            ear.move(to: pt(a, b))
            ear.addLine(to: pt(a == 15 ? 26 : 38, 19))
            ear.addLine(to: pt(d, 21))
            ear.closeSubpath()
            context.fill(ear, with: .color(color))
        }
        // head ring
        let headR = 21 / 32 * r
        context.stroke(
            Path(ellipseIn: CGRect(x: c.x - headR, y: c.y + (36 - 32) / 32 * r - headR,
                                   width: 2 * headR, height: 2 * headR)),
            with: .color(color), lineWidth: 3.5 / 32 * r)
        // eyes with pupils
        let eyeR = 7 / 32 * r
        let pupilR = 2.8 / 32 * r
        for dx in [-8, 8] as [CGFloat] {
            let ex = c.x + dx / 32 * r, ey = c.y + (33 - 32) / 32 * r
            context.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: ey - eyeR, width: 2 * eyeR, height: 2 * eyeR)),
                         with: .color(color))
            var cut = context
            cut.blendMode = .destinationOut
            cut.fill(Path(ellipseIn: CGRect(x: ex - pupilR, y: ey - pupilR, width: 2 * pupilR, height: 2 * pupilR)),
                     with: .color(.black))
        }
        // beak
        var beak = Path()
        beak.move(to: pt(32, 41))
        beak.addLine(to: pt(28.5, 46.5))
        beak.addLine(to: pt(35.5, 46.5))
        beak.closeSubpath()
        context.fill(beak, with: .color(color))
    }
}

extension ProviderGlyph {
    /// Cached template bitmaps for MenuBarExtra labels.
    /// Canvas/custom drawing is silently dropped inside MenuBarExtra label views,
    /// so the label uses these NSImages (rendered once from the same SwiftUI glyph).
    /// `isTemplate` makes macOS tint them to match the menu bar style.
    @MainActor
    enum Images {
        private static var cache: [Kind: NSImage] = [:]

        static func template(for kind: Kind) -> NSImage {
            if let cached = cache[kind] { return cached }
            let renderer = ImageRenderer(content:
                ProviderGlyph(kind: kind, color: .black)
                    .frame(width: 14, height: 14))
            renderer.scale = 3  // crisp on retina menu bars
            let image = renderer.nsImage ?? NSImage(size: NSSize(width: 14, height: 14))
            // ImageRenderer reports the NSImage's logical size in PIXELS
            // (14pt @3x -> 42x42), which would triple the glyph's layout width
            // inside the status item. Pin it back to points.
            image.size = NSSize(width: 14, height: 14)
            image.isTemplate = true
            cache[kind] = image
            return image
        }
    }
}
