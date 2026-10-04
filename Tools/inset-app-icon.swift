#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: inset-app-icon.swift source.png output.png\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let canvasPixels = 1024
let artworkPixels = 872
let inset = CGFloat(canvasPixels - artworkPixels) / 2

guard let source = NSImage(contentsOf: sourceURL),
      let bitmap = NSBitmapImageRep(
          bitmapDataPlanes: nil,
          pixelsWide: canvasPixels,
          pixelsHigh: canvasPixels,
          bitsPerSample: 8,
          samplesPerPixel: 4,
          hasAlpha: true,
          isPlanar: false,
          colorSpaceName: .deviceRGB,
          bytesPerRow: 0,
          bitsPerPixel: 0
      ),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not prepare icon canvas")
}

bitmap.size = NSSize(width: canvasPixels, height: canvasPixels)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
context.shouldAntialias = true
context.cgContext.clear(CGRect(x: 0, y: 0, width: canvasPixels, height: canvasPixels))

source.draw(
    in: NSRect(
        x: inset,
        y: inset,
        width: CGFloat(artworkPixels),
        height: CGFloat(artworkPixels)
    ),
    from: NSRect(origin: .zero, size: source.size),
    operation: .copy,
    fraction: 1,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
)

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode inset icon")
}

try png.write(to: outputURL, options: .atomic)
print("Generated: \(outputURL.path)")
