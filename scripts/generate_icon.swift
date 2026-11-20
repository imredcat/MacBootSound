#!/usr/bin/env swift
import AppKit
import Foundation

let rootDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesDir = rootDir.appendingPathComponent("Resources", isDirectory: true)
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("Failed to create CGContext")
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Standard macOS squircle geometry (~10% outer margin)
    let inset = s * 0.098
    let tileRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = tileRect.width * 0.225
    let tilePath = CGPath(
        roundedRect: tileRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    // Subtle soft drop shadow beneath the squircle
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.016),
        blur: s * 0.032,
        color: NSColor.black.withAlphaComponent(0.38).cgColor
    )
    ctx.addPath(tilePath)
    ctx.setFillColor(NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.06, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to squircle
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // VOX-inspired ultra-clean matte charcoal/obsidian surface
    let bgColors = [
        NSColor(calibratedRed: 0.11, green: 0.115, blue: 0.13, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.055, green: 0.058, blue: 0.068, alpha: 1.0).cgColor
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            bgGrad,
            start: CGPoint(x: tileRect.midX, y: tileRect.maxY),
            end: CGPoint(x: tileRect.midX, y: tileRect.minY),
            options: []
        )
    }

    // Minimalist hairline inner border
    let strokeWidth = max(1.0, s * 0.006)
    let rimRect = tileRect.insetBy(dx: strokeWidth * 0.5, dy: strokeWidth * 0.5)
    let rimPath = CGPath(
        roundedRect: rimRect,
        cornerWidth: cornerRadius - strokeWidth * 0.5,
        cornerHeight: cornerRadius - strokeWidth * 0.5,
        transform: nil
    )
    ctx.addPath(rimPath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    ctx.setLineWidth(strokeWidth)
    ctx.strokePath()

    // Generous breathing room & sharp geometric speaker + 2 clean VOX-orange wave arcs
    let u = tileRect.width
    let cx = tileRect.midX
    let cy = tileRect.midY

    let speakerPath = CGMutablePath()
    let leftX = cx - u * 0.215
    let waistX = cx - u * 0.115
    let frontX = cx - u * 0.005
    let boxHalfH = u * 0.072
    let hornHalfH = u * 0.165
    let r = u * 0.022

    speakerPath.move(to: CGPoint(x: leftX + r, y: cy + boxHalfH))
    speakerPath.addLine(to: CGPoint(x: waistX, y: cy + boxHalfH))
    speakerPath.addLine(to: CGPoint(x: frontX - r * 0.6, y: cy + hornHalfH - r * 0.35))
    speakerPath.addQuadCurve(
        to: CGPoint(x: frontX, y: cy + hornHalfH - r * 0.9),
        control: CGPoint(x: frontX, y: cy + hornHalfH)
    )
    speakerPath.addLine(to: CGPoint(x: frontX, y: cy - hornHalfH + r * 0.9))
    speakerPath.addQuadCurve(
        to: CGPoint(x: frontX - r * 0.6, y: cy - hornHalfH + r * 0.35),
        control: CGPoint(x: frontX, y: cy - hornHalfH)
    )
    speakerPath.addLine(to: CGPoint(x: waistX, y: cy - boxHalfH))
    speakerPath.addLine(to: CGPoint(x: leftX + r, y: cy - boxHalfH))
    speakerPath.addQuadCurve(
        to: CGPoint(x: leftX, y: cy - boxHalfH + r),
        control: CGPoint(x: leftX, y: cy - boxHalfH)
    )
    speakerPath.addLine(to: CGPoint(x: leftX, y: cy + boxHalfH - r))
    speakerPath.addQuadCurve(
        to: CGPoint(x: leftX + r, y: cy + boxHalfH),
        control: CGPoint(x: leftX, y: cy + boxHalfH)
    )
    speakerPath.closeSubpath()

    // Crisp pure white minimalist speaker cone
    ctx.addPath(speakerPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.96, green: 0.965, blue: 0.98, alpha: 1.0).cgColor)
    ctx.fillPath()

    // Two clean, balanced VOX-inspired warm orange geometric sound arcs
    let arcOrigin = CGPoint(x: frontX - u * 0.015, y: cy)
    let waveLineWidth = max(1.4, u * 0.036)
    let waveSpecs: [(radius: CGFloat, angleDeg: CGFloat)] = [
        (u * 0.115, 36.0),
        (u * 0.205, 42.0)
    ]

    for (idx, spec) in waveSpecs.enumerated() {
        let startRad = -spec.angleDeg * .pi / 180.0
        let endRad = spec.angleDeg * .pi / 180.0

        let arcPath = CGMutablePath()
        arcPath.addArc(
            center: arcOrigin,
            radius: spec.radius,
            startAngle: startRad,
            endAngle: endRad,
            clockwise: false
        )

        let strokedArc = arcPath.copy(
            strokingWithWidth: waveLineWidth,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )

        ctx.saveGState()
        ctx.addPath(strokedArc)
        ctx.clip()
        let topOrange = NSColor(
            calibratedRed: 1.0,
            green: idx == 0 ? 0.44 : 0.38,
            blue: 0.14,
            alpha: idx == 0 ? 1.0 : 0.85
        ).cgColor
        let bottomOrange = NSColor(
            calibratedRed: 0.96,
            green: 0.28,
            blue: 0.10,
            alpha: idx == 0 ? 1.0 : 0.85
        ).cgColor
        let colors = [topOrange, bottomOrange] as CFArray
        if let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: arcOrigin.x, y: cy + spec.radius),
                end: CGPoint(x: arcOrigin.x, y: cy - spec.radius),
                options: []
            )
        }
        ctx.restoreGState()
    }

    ctx.restoreGState() // End tile clip
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconEntries: [(name: String, size: Int)] = [
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

for entry in iconEntries {
    let rep = drawIcon(size: entry.size)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(entry.name)")
    }
    try pngData.write(to: iconsetDir.appendingPathComponent(entry.name))
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus != 0 {
    fatalError("iconutil failed with exit code \(proc.terminationStatus)")
}

try? FileManager.default.removeItem(at: iconsetDir)
print("Generated \(icnsURL.path)")
