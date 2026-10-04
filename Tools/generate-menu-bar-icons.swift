#!/usr/bin/env swift

import AppKit

let pointSize = NSSize(width: 18, height: 18)
let pixelScale = 2

func makeIcon(paused: Bool) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(pointSize.width) * pixelScale,
        pixelsHigh: Int(pointSize.height) * pixelScale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap")
    }

    bitmap.size = pointSize

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    context.cgContext.clear(CGRect(origin: .zero, size: pointSize))

    NSColor.black.setStroke()
    NSColor.black.setFill()

    let ring = NSBezierPath()
    ring.appendArc(
        withCenter: NSPoint(x: 9, y: 9),
        radius: 6.25,
        startAngle: 63,
        endAngle: 380,
        clockwise: false
    )
    ring.lineWidth = 2.1
    ring.lineCapStyle = .round
    ring.stroke()

    if paused {
        for x in [7.8, 10.2] {
            let pauseBar = NSBezierPath()
            pauseBar.move(to: NSPoint(x: x, y: 7.2))
            pauseBar.line(to: NSPoint(x: x, y: 10.8))
            pauseBar.lineWidth = 1.5
            pauseBar.lineCapStyle = .round
            pauseBar.stroke()
        }
    } else {
        let hand = NSBezierPath()
        hand.move(to: NSPoint(x: 9, y: 9))
        hand.line(to: NSPoint(x: 12.1, y: 12.1))
        hand.lineWidth = 2.1
        hand.lineCapStyle = .round
        hand.stroke()
    }

    NSBezierPath(
        ovalIn: NSRect(x: 13.1, y: 13.1, width: 2.8, height: 2.8)
    ).fill()

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return png
}

let resourcesURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources")
let icons = [
    ("MenuBarIconTemplate.png", false),
    ("MenuBarIconPausedTemplate.png", true),
]

for (fileName, paused) in icons {
    let outputURL = resourcesURL.appendingPathComponent(fileName)
    try makeIcon(paused: paused).write(to: outputURL, options: .atomic)
    print("Generated \(outputURL.path)")
}
