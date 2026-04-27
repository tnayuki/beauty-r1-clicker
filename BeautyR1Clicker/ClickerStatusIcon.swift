import AppKit

/// Template image for the menu-bar status item. Mirrors the app icon style:
/// four directional chevrons around a center dot.
enum ClickerStatusIcon {
    struct Style {
        let lineWidth: CGFloat
        let halfArm: CGFloat
        let depth: CGFloat
    }

    static func makeTemplateImage() -> NSImage {
        makeImage(base: .normal, pressed: nil)
    }

    /// Brief flash when a synthetic key is posted. If `direction` is given,
    /// only that chevron is drawn extra-bold so the press direction is visible.
    static func makeActiveTemplateImage(direction: Direction? = nil) -> NSImage {
        makeImage(base: .active, pressed: direction.map { ($0, .pressed) })
    }

    private static func makeImage(
        base: Style,
        pressed: (Direction, Style)?
    ) -> NSImage {
        let logical: CGFloat = 18
        let dist: CGFloat = 5.5
        let centerR: CGFloat = 1.8

        let image = NSImage(size: NSSize(width: logical, height: logical), flipped: true) { dst in
            NSGraphicsContext.current?.imageInterpolation = .high
            let cx = dst.width / 2
            let cy = dst.height / 2

            NSColor.black.set()

            NSBezierPath(
                ovalIn: NSRect(
                    x: cx - centerR, y: cy - centerR,
                    width: centerR * 2, height: centerR * 2
                )
            ).fill()

            let arrows: [(Direction, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (.up,    0, -1, 1, 0),
                (.down,  0,  1, 1, 0),
                (.left, -1,  0, 0, 1),
                (.right, 1,  0, 0, 1)
            ]
            for (dir, dx, dy, px, py) in arrows {
                let style = (dir == pressed?.0) ? pressed!.1 : base
                let bx = cx + dx * dist
                let by = cy + dy * dist
                let path = NSBezierPath()
                path.lineWidth = style.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: NSPoint(x: bx + px * style.halfArm, y: by + py * style.halfArm))
                path.line(to: NSPoint(x: bx + dx * style.depth,   y: by + dy * style.depth))
                path.line(to: NSPoint(x: bx - px * style.halfArm, y: by - py * style.halfArm))
                path.stroke()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}

extension ClickerStatusIcon.Style {
    static let normal  = ClickerStatusIcon.Style(lineWidth: 2.0, halfArm: 2.2, depth: 1.4)
    static let active  = ClickerStatusIcon.Style(lineWidth: 2.0, halfArm: 2.2, depth: 1.4)
    static let pressed = ClickerStatusIcon.Style(lineWidth: 3.4, halfArm: 2.8, depth: 1.9)
}
