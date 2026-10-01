#!/usr/bin/env swift
// Reproducible MILO icon artwork. Run from any directory with macOS Swift:
// swift apps/ios/scripts/generate-app-icon.swift
// CoreGraphics draws opaque RGB pixels; iOS applies the icon corner mask.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let script = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let root = script.deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
let assetDirectory = root.appendingPathComponent("apps/ios/Resources/Assets.xcassets/AppIcon.appiconset")
let previewDirectory = root.appendingPathComponent(".artifacts/ios/stability-20260930")
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [CGFloat((hex >> 16) & 255) / 255,
        CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, alpha])!
}
func radial(_ context: CGContext, colors: [CGColor], stops: [CGFloat], center: CGPoint,
            radius: CGFloat, endCenter: CGPoint? = nil) {
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: stops)!
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
        endCenter: endCenter ?? center, endRadius: radius, options: [.drawsAfterEndLocation])
}

func orbitPath(from start: CGFloat, to end: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let angle: CGFloat = .pi * 0.13
    for step in 0...200 {
        let t = start + (end - start) * CGFloat(step) / 200
        let x = 376 * cos(t), y = 130 * sin(t)
        let point = CGPoint(x: 506 + x * cos(angle) - y * sin(angle),
                            y: 500 + x * sin(angle) + y * cos(angle))
        if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    return path
}

func drawIcon(in context: CGContext) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    context.setFillColor(color(0x101027)); context.fill(canvas)
    // The quiet full-bleed field stays dark enough to survive the system mask.
    radial(context, colors: [color(0x31204E), color(0x18152F), color(0x101027)],
           stops: [0, 0.58, 1], center: CGPoint(x: 454, y: 541), radius: 720)
    context.saveGState()
    radial(context, colors: [color(0x8971EE, alpha: 0.18), color(0x8971EE, alpha: 0)],
           stops: [0, 1], center: CGPoint(x: 473, y: 523), radius: 385)
    context.restoreGState()

    // One inclined orbit: the rear arc sits behind the planet, the front arc
    // crosses its lower hemisphere. No extra stars compete with the mark.
    let back = orbitPath(from: 0, to: .pi)
    context.addPath(back); context.setStrokeColor(color(0xB7A6ED, alpha: 0.34))
    context.setLineWidth(4); context.setLineCap(.round); context.strokePath()

    let planet = CGRect(x: 262, y: 267, width: 474, height: 474)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -16), blur: 64, color: color(0x6D51D4, alpha: 0.25))
    context.setFillColor(color(0x7560B9)); context.fillEllipse(in: planet)
    context.restoreGState()

    context.saveGState()
    context.addEllipse(in: planet); context.clip()
    radial(context, colors: [color(0xE5DBFF), color(0xB8A5EB), color(0x8270BF), color(0x493776), color(0x251F47)],
           stops: [0, 0.28, 0.56, 0.82, 1], center: CGPoint(x: 405, y: 657), radius: 515,
           endCenter: CGPoint(x: 499, y: 504))
    // A broad reflected glow, with no texture that collapses into noise at 32pt.
    radial(context, colors: [color(0xACA9FF, alpha: 0.24), color(0xACA9FF, alpha: 0)],
           stops: [0, 1], center: CGPoint(x: 625, y: 367), radius: 197)
    context.restoreGState()
    context.addEllipse(in: planet.insetBy(dx: 1.5, dy: 1.5))
    context.setStrokeColor(color(0xE1D6FF, alpha: 0.20)); context.setLineWidth(3); context.strokePath()

    let front = orbitPath(from: .pi, to: .pi * 2)
    context.saveGState()
    context.setShadow(offset: .zero, blur: 12, color: color(0xC3ABFF, alpha: 0.32))
    context.addPath(front); context.setStrokeColor(color(0xD8C5F8, alpha: 0.90))
    context.setLineWidth(5.5); context.strokePath()
    context.restoreGState()
    // A single four-point light gives the icon a recognizable small-size accent.
    let star = CGMutablePath()
    let center = CGPoint(x: 772, y: 759)
    let points: [CGPoint] = [
        CGPoint(x: 0, y: 31), CGPoint(x: 7, y: 8), CGPoint(x: 27, y: 0),
        CGPoint(x: 7, y: -8), CGPoint(x: 0, y: -31), CGPoint(x: -7, y: -8),
        CGPoint(x: -27, y: 0), CGPoint(x: -7, y: 8)
    ]
    star.move(to: CGPoint(x: center.x + points[0].x, y: center.y + points[0].y))
    for point in points.dropFirst() { star.addLine(to: CGPoint(x: center.x + point.x, y: center.y + point.y)) }
    star.closeSubpath()
    context.saveGState()
    context.setShadow(offset: .zero, blur: 19, color: color(0xE7D7FF, alpha: 0.30))
    context.addPath(star); context.setFillColor(color(0xF0E2FF)); context.fillPath()
    context.restoreGState()
}

func render(size: Int, to url: URL) throws {
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw NSError(domain: "MiloIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot allocate RGB canvas"])
    }
    context.interpolationQuality = .high
    context.setShouldAntialias(true)
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: context)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "MiloIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create PNG destination"])
    }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyPNGDictionary: [:]] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "MiloIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot write PNG"])
    }
}

try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
try render(size: 1024, to: assetDirectory.appendingPathComponent("AppIcon.png"))
for size in [64, 32] {
    try render(size: size, to: previewDirectory.appendingPathComponent("Milo-AppIcon-\(size).png"))
}
let catalog = """
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try (catalog + "\n").write(to: assetDirectory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Generated opaque RGB MILO AppIcon and 64px/32px inspection previews.")
