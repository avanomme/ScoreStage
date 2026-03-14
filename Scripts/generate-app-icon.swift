#!/usr/bin/env swift

// generate-app-icon.swift — Generates ScoreStage app icon at all required sizes.
// Usage: swift Scripts/generate-app-icon.swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Icon Design
// Dark background (#1A1A1E) with rose copper accent (#D55D7A)
// Large prominent music note filling the icon

let bgColor = (r: 0x1A/255.0, g: 0x1A/255.0, b: 0x1E/255.0)
let accentColor = (r: 213.0/255.0, g: 93.0/255.0, b: 122.0/255.0)
let lightColor = (r: 0xF0/255.0, g: 0xF0/255.0, b: 0xF2/255.0)

func generateIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Coordinate system: origin top-left for easier reasoning
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let unit = s / 1024.0

    // Background — dark
    ctx.setFillColor(CGColor(red: bgColor.r, green: bgColor.g, blue: bgColor.b, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // Subtle radial gradient overlay for depth
    let gradientColors = [
        CGColor(red: 0x24/255.0, green: 0x22/255.0, blue: 0x2A/255.0, alpha: 1.0),
        CGColor(red: bgColor.r, green: bgColor.g, blue: bgColor.b, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 1]) {
        ctx.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: s * 0.45, y: s * 0.4),
            startRadius: 0,
            endCenter: CGPoint(x: s * 0.5, y: s * 0.5),
            endRadius: s * 0.75,
            options: .drawsAfterEndLocation
        )
    }

    // Subtle staff lines behind the note — very faint background texture
    let staffTop = s * 0.28
    let staffSpacing = s * 0.11
    let staffLineWidth = max(1.0, unit * 1.5)

    ctx.setStrokeColor(CGColor(red: lightColor.r, green: lightColor.g, blue: lightColor.b, alpha: 0.08))
    ctx.setLineWidth(staffLineWidth)

    for i in 0..<5 {
        let y = staffTop + CGFloat(i) * staffSpacing
        ctx.move(to: CGPoint(x: s * 0.05, y: y))
        ctx.addLine(to: CGPoint(x: s * 0.95, y: y))
    }
    ctx.strokePath()

    // ── Large prominent quarter note ──
    // Note head center — positioned in lower-center of icon
    let noteHeadCenterX = s * 0.42
    let noteHeadCenterY = s * 0.65
    let noteHeadRx = s * 0.16  // wide oval
    let noteHeadRy = s * 0.12  // shorter vertically

    // Note head — filled oval, slightly tilted
    ctx.saveGState()
    ctx.translateBy(x: noteHeadCenterX, y: noteHeadCenterY)
    ctx.rotate(by: -0.35)
    ctx.setFillColor(CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 1))
    ctx.fillEllipse(in: CGRect(
        x: -noteHeadRx, y: -noteHeadRy,
        width: noteHeadRx * 2, height: noteHeadRy * 2
    ))
    ctx.restoreGState()

    // Stem — tall vertical line from note head to near top
    let stemWidth = max(3.0, unit * 8.0)
    let stemX = noteHeadCenterX + noteHeadRx * 0.82
    let stemBottom = noteHeadCenterY - noteHeadRy * 0.5
    let stemTop = s * 0.12

    ctx.setStrokeColor(CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 1))
    ctx.setLineWidth(stemWidth)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: stemX, y: stemBottom))
    ctx.addLine(to: CGPoint(x: stemX, y: stemTop))
    ctx.strokePath()

    // Flag — elegant curved stroke from top of stem
    let flagLineWidth = max(3.0, unit * 7.0)
    ctx.setLineWidth(flagLineWidth)
    ctx.setLineCap(.round)

    // First flag
    ctx.move(to: CGPoint(x: stemX, y: stemTop))
    ctx.addCurve(
        to: CGPoint(x: stemX + s * 0.18, y: stemTop + s * 0.22),
        control1: CGPoint(x: stemX + s * 0.22, y: stemTop + s * 0.04),
        control2: CGPoint(x: stemX + s * 0.14, y: stemTop + s * 0.18)
    )
    ctx.strokePath()

    // Second flag (eighth note → sixteenth note feel)
    ctx.move(to: CGPoint(x: stemX, y: stemTop + s * 0.08))
    ctx.addCurve(
        to: CGPoint(x: stemX + s * 0.16, y: stemTop + s * 0.28),
        control1: CGPoint(x: stemX + s * 0.20, y: stemTop + s * 0.12),
        control2: CGPoint(x: stemX + s * 0.12, y: stemTop + s * 0.24)
    )
    ctx.strokePath()

    // Subtle glow behind the note head for depth
    ctx.saveGState()
    let glowColors = [
        CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 0.15),
        CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 0.0)
    ] as CFArray
    if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0, 1]) {
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: noteHeadCenterX, y: noteHeadCenterY),
            startRadius: s * 0.1,
            endCenter: CGPoint(x: noteHeadCenterX, y: noteHeadCenterY),
            endRadius: s * 0.3,
            options: .drawsAfterEndLocation
        )
    }
    ctx.restoreGState()

    return ctx.makeImage()
}

func savePNG(_ image: CGImage, path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create image destination: \(path)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) {
        print("Created: \(path)")
    } else {
        print("Failed to write: \(path)")
    }
}

// MARK: - Generate All Sizes

let iconsetPath = "ScoreStageApp/Assets.xcassets/AppIcon.appiconset"

struct IconSpec {
    let size: Int
    let scale: Int
    let platform: String
    let filename: String
}

let specs: [IconSpec] = [
    // iOS — single 1024x1024
    IconSpec(size: 1024, scale: 1, platform: "ios", filename: "icon_1024.png"),
    // macOS — all required sizes
    IconSpec(size: 16, scale: 1, platform: "mac", filename: "icon_16.png"),
    IconSpec(size: 16, scale: 2, platform: "mac", filename: "icon_16@2x.png"),
    IconSpec(size: 32, scale: 1, platform: "mac", filename: "icon_32.png"),
    IconSpec(size: 32, scale: 2, platform: "mac", filename: "icon_32@2x.png"),
    IconSpec(size: 128, scale: 1, platform: "mac", filename: "icon_128.png"),
    IconSpec(size: 128, scale: 2, platform: "mac", filename: "icon_128@2x.png"),
    IconSpec(size: 256, scale: 1, platform: "mac", filename: "icon_256.png"),
    IconSpec(size: 256, scale: 2, platform: "mac", filename: "icon_256@2x.png"),
    IconSpec(size: 512, scale: 1, platform: "mac", filename: "icon_512.png"),
    IconSpec(size: 512, scale: 2, platform: "mac", filename: "icon_512@2x.png"),
]

for spec in specs {
    let pixelSize = spec.size * spec.scale
    guard let image = generateIcon(size: pixelSize) else {
        print("Failed to generate \(spec.filename)")
        continue
    }
    savePNG(image, path: "\(iconsetPath)/\(spec.filename)")
}

// Update Contents.json
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "icon_16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try! contentsJSON.write(toFile: "\(iconsetPath)/Contents.json", atomically: true, encoding: .utf8)
print("Updated Contents.json")
print("Done!")
