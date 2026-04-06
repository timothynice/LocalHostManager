import AppKit

enum AppBrand {
    static let displayName = "Studi0 Ports"
    static let binaryName = "Studi0Ports"
    static let bundleIdentifier = "com.studi0ports.app"
    static let statusAccent = NSColor(
        calibratedRed: 1,
        green: 250.0 / 255.0,
        blue: 122.0 / 255.0,
        alpha: 1
    )
}

enum BrandStatusIcon {
    static let statusItem = make(size: NSSize(width: 17, height: 17))
    static let popover = make(size: NSSize(width: 22, height: 22))

    static func make(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        image.isTemplate = false
        image.size = size
        return image
    }

    private static func draw(in rect: NSRect) {
        let viewBoxSize = NSSize(width: 24, height: 24)
        let scale = min(rect.width / viewBoxSize.width, rect.height / viewBoxSize.height)
        let offsetX = (rect.width - (viewBoxSize.width * scale)) / 2
        let offsetY = (rect.height - (viewBoxSize.height * scale)) / 2
        let strokeWidth = max(1.45, 2 * scale)
        let dotDiameter = max(2.4, 3.2 * scale)

        func scaleRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
            NSRect(
                x: rect.minX + offsetX + x * scale,
                y: rect.minY + offsetY + y * scale,
                width: width * scale,
                height: height * scale
            )
        }

        let rackRects = [
            scaleRect(x: 3, y: 12, width: 18, height: 8),
            scaleRect(x: 3, y: 4, width: 18, height: 8),
        ]

        AppBrand.statusAccent.setStroke()
        for rackRect in rackRects {
            let path = NSBezierPath(roundedRect: rackRect, xRadius: 3 * scale, yRadius: 3 * scale)
            path.lineWidth = strokeWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }

        AppBrand.statusAccent.setFill()
        let indicatorCenters = [NSPoint(x: 7, y: 16), NSPoint(x: 7, y: 8)]
        for center in indicatorCenters {
            let circleRect = NSRect(
                x: rect.minX + offsetX + (center.x * scale) - dotDiameter / 2,
                y: rect.minY + offsetY + (center.y * scale) - dotDiameter / 2,
                width: dotDiameter,
                height: dotDiameter
            )
            NSBezierPath(ovalIn: circleRect).fill()
        }
    }
}
