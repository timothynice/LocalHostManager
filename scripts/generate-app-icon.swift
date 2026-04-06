#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("Usage: generate-app-icon.swift <source-png> <iconset-output-dir>\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Couldn't load source icon at \(sourceURL.path)\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
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
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon(sourceImage, in: NSRect(origin: .zero, size: size))
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

func drawIcon(_ sourceImage: NSImage, in rect: NSRect) {
    let sourceSize = sourceImage.size
    guard sourceSize.width > 0, sourceSize.height > 0 else {
        return
    }

    let sourceAspect = sourceSize.width / sourceSize.height
    let targetAspect = rect.width / rect.height

    let drawRect: NSRect
    if sourceAspect > targetAspect {
        let width = rect.height * sourceAspect
        drawRect = NSRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: rect.height)
    } else {
        let height = rect.width / sourceAspect
        drawRect = NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
    }

    sourceImage.draw(
        in: drawRect,
        from: NSRect(origin: .zero, size: sourceSize),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
}
