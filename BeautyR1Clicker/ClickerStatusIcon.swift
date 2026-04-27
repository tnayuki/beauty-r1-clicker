import AppKit

/// Template image for the menu-bar status item. We avoid SF Symbols and instead draw
/// a circular ring with four cardinal dots to evoke a "ring-style clicker" look.
enum ClickerStatusIcon {
    /// Logical size 18pt. `isTemplate = true` lets the icon follow the menu bar's
    /// light/dark appearance automatically.
    static func makeTemplateImage() -> NSImage {
        let logical: CGFloat = 18
        let image = NSImage(size: NSSize(width: logical, height: logical), flipped: true) { dst in
            NSGraphicsContext.current?.imageInterpolation = .high
            let w = dst.width
            let h = dst.height
            let s = min(w, h)
            let pad: CGFloat = 1.25
            let ring = s - pad * 2
            let ox = (w - ring) / 2
            let oy = (h - ring) / 2
            let ringRect = NSRect(x: ox, y: oy, width: ring, height: ring)

            NSColor.black.set()

            let outer = NSBezierPath(ovalIn: ringRect)
            outer.lineWidth = 1.15
            outer.stroke()

            // Four cardinal dots (cross) — evokes a touch ring.
            let cx = w / 2
            let cy = h / 2
            let dotR: CGFloat = 1.05
            let dist = (ring / 2) - dotR - 0.35
            let dirs: [(CGFloat, CGFloat)] = [
                (0, -1), (1, 0), (0, 1), (-1, 0)
            ]
            for (ux, uy) in dirs {
                let d = NSBezierPath(
                    ovalIn: NSRect(
                        x: cx + ux * dist - dotR,
                        y: cy + uy * dist - dotR,
                        width: dotR * 2,
                        height: dotR * 2
                    )
                )
                d.fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    /// Used for the brief flash when a synthetic key is posted. The ring is thicker
    /// and the dots are slightly larger to make the press feedback feel responsive.
    static func makeActiveTemplateImage() -> NSImage {
        let logical: CGFloat = 18
        let image = NSImage(size: NSSize(width: logical, height: logical), flipped: true) { dst in
            NSGraphicsContext.current?.imageInterpolation = .high
            let w = dst.width
            let h = dst.height
            let s = min(w, h)
            let pad: CGFloat = 1.1
            let ring = s - pad * 2
            let ox = (w - ring) / 2
            let oy = (h - ring) / 2
            let ringRect = NSRect(x: ox, y: oy, width: ring, height: ring)

            NSColor.black.set()

            let outer = NSBezierPath(ovalIn: ringRect)
            outer.lineWidth = 2.0
            outer.stroke()

            let cx = w / 2
            let cy = h / 2
            let dotR: CGFloat = 1.3
            let dist = (ring / 2) - dotR - 0.25
            let dirs: [(CGFloat, CGFloat)] = [
                (0, -1), (1, 0), (0, 1), (-1, 0)
            ]
            for (ux, uy) in dirs {
                let d = NSBezierPath(
                    ovalIn: NSRect(
                        x: cx + ux * dist - dotR,
                        y: cy + uy * dist - dotR,
                        width: dotR * 2,
                        height: dotR * 2
                    )
                )
                d.fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}
