#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-installer-assets.swift <output-directory>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconsetDirectory = outputDirectory.appending(path: "TokenBar.iconset", directoryHint: .isDirectory)
let backgroundURL = outputDirectory.appending(path: "TokenBar Installer.png")
let fileManager = FileManager.default

try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

func bitmap(width: Int, height: Int, draw: () -> Void) throws -> NSBitmapImageRep {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: representation) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return representation
}

func writePNG(_ representation: NSBitmapImageRep, to url: URL) throws {
    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url, options: .atomic)
}

let icon = try bitmap(width: 1024, height: 1024) {
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 42
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()

    let tile = NSBezierPath(roundedRect: NSRect(x: 40, y: 48, width: 944, height: 944), xRadius: 220, yRadius: 220)
    NSColor(calibratedWhite: 0.985, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 0.86, alpha: 1).setStroke()
    tile.lineWidth = 5
    tile.stroke()

    let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "TokenBar")
        ?? NSImage(systemSymbolName: "gauge", accessibilityDescription: "TokenBar")
    let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 500, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [
            NSColor(calibratedWhite: 0.12, alpha: 1),
            NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.42, alpha: 1)
        ]))
    if let configuredSymbol = symbol?.withSymbolConfiguration(symbolConfiguration) {
        configuredSymbol.draw(in: NSRect(x: 192, y: 198, width: 640, height: 640))
    }
}

let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let fullIconImage = NSImage(size: NSSize(width: 1024, height: 1024))
fullIconImage.addRepresentation(icon)
for item in iconSizes {
    let resized = try bitmap(width: item.pixels, height: item.pixels) {
        NSGraphicsContext.current?.imageInterpolation = .high
        fullIconImage.draw(
            in: NSRect(x: 0, y: 0, width: item.pixels, height: item.pixels),
            from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
            operation: .copy,
            fraction: 1
        )
    }
    try writePNG(resized, to: iconsetDirectory.appending(path: item.name))
}

let backgroundScale = 2
let backgroundSize = NSSize(width: 660, height: 394)
let background = try bitmap(
    width: Int(backgroundSize.width) * backgroundScale,
    height: Int(backgroundSize.height) * backgroundScale
) {
    NSGraphicsContext.current?.cgContext.scaleBy(
        x: CGFloat(backgroundScale),
        y: CGFloat(backgroundScale)
    )

    NSColor(calibratedWhite: 0.992, alpha: 1).setFill()
    NSRect(origin: .zero, size: backgroundSize).fill()

    let title = "Install TokenBar" as NSString
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 29, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
    ]
    let titleSize = title.size(withAttributes: titleAttributes)
    title.draw(at: NSPoint(x: (660 - titleSize.width) / 2, y: 310), withAttributes: titleAttributes)

    let subtitle = "Double click the icon below" as NSString
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 16, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1)
    ]
    let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
    subtitle.draw(at: NSPoint(x: (660 - subtitleSize.width) / 2, y: 282), withAttributes: subtitleAttributes)

    let iconBackdrop = NSBezierPath(roundedRect: NSRect(x: 229, y: 62, width: 202, height: 202), xRadius: 11, yRadius: 11)
    NSColor(calibratedWhite: 0.91, alpha: 1).setFill()
    iconBackdrop.fill()
    NSColor(calibratedWhite: 0.95, alpha: 1).setStroke()
    iconBackdrop.lineWidth = 2.5
    iconBackdrop.stroke()
}
background.size = backgroundSize

try writePNG(background, to: backgroundURL)
