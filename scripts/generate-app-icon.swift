#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <iconset-output-dir>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try? FileManager.default.removeItem(at: outputDirectory)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, dimension) in iconSizes {
    let size = NSSize(width: dimension, height: dimension)
    let image = NSImage(size: size)

    image.lockFocus()
    drawIcon(in: NSRect(origin: .zero, size: size))
    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGenerator", code: 1)
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(filename), options: .atomic)
}

func drawIcon(in rect: NSRect) {
    let scale = rect.width / 1024
    let backgroundRect = rect.insetBy(dx: 72 * scale, dy: 72 * scale)
    let borderWidth = max(2, 8 * scale)
    let cornerRadius = 220 * scale

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 40 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.set()

    let gradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.22, alpha: 1),
        NSColor(calibratedWhite: 0.14, alpha: 1),
    ])!
    let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)
    gradient.draw(in: backgroundPath, angle: -90)

    NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
    backgroundPath.lineWidth = borderWidth
    backgroundPath.stroke()

    let glowRect = NSRect(
        x: rect.minX + 620 * scale,
        y: rect.minY + 710 * scale,
        width: 250 * scale,
        height: 250 * scale
    )
    let glowPath = NSBezierPath(ovalIn: glowRect)
    NSColor.systemBlue.withAlphaComponent(0.22).setFill()
    glowPath.fill()

    let plateRect = NSRect(
        x: rect.minX + 212 * scale,
        y: rect.minY + 210 * scale,
        width: 600 * scale,
        height: 600 * scale
    )
    let platePath = NSBezierPath(roundedRect: plateRect, xRadius: 150 * scale, yRadius: 150 * scale)
    NSColor(calibratedWhite: 0.1, alpha: 0.96).setFill()
    platePath.fill()

    NSColor.systemBlue.withAlphaComponent(0.18).setStroke()
    platePath.lineWidth = max(2, 6 * scale)
    platePath.stroke()

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 300 * scale, weight: .bold)
    let symbol = NSImage(
        systemSymbolName: "server.rack",
        accessibilityDescription: "LocalHostManager"
    )?.withSymbolConfiguration(symbolConfig)

    if let symbol {
        let symbolRect = NSRect(
            x: rect.minX + 330 * scale,
            y: rect.minY + 308 * scale,
            width: 360 * scale,
            height: 360 * scale
        )

        symbol.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        symbol.unlockFocus()
        symbol.draw(in: symbolRect)
    }

    let indicatorRect = NSRect(
        x: rect.minX + 665 * scale,
        y: rect.minY + 635 * scale,
        width: 74 * scale,
        height: 74 * scale
    )
    let indicatorPath = NSBezierPath(ovalIn: indicatorRect)
    NSColor.systemBlue.setFill()
    indicatorPath.fill()
}
