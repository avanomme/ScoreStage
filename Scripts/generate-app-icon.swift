#!/usr/bin/env swift

// generate-app-icon.swift — Generates ScoreStage app icon at all required sizes.
// Usage: swift Scripts/generate-app-icon.swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Icon Design
// Dark background (#1A1A1E) with rose copper accent (#D55D7A)
// Musical staff lines + stylized music note/stand

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

    // Background — dark with subtle gradient feel
    ctx.setFillColor(CGColor(red: bgColor.r, green: bgColor.g, blue: bgColor.b, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // Subtle radial gradient overlay for depth
    let gradientColors = [
        CGColor(red: 0x22/255.0, green: 0x22/255.0, blue: 0x28/255.0, alpha: 1.0),
        CGColor(red: bgColor.r, green: bgColor.g, blue: bgColor.b, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 1]) {
        ctx.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: s * 0.5, y: s * 0.4),
            startRadius: 0,
            endCenter: CGPoint(x: s * 0.5, y: s * 0.5),
            endRadius: s * 0.7,
            options: .drawsAfterEndLocation
        )
    }

    // Staff lines — 5 thin horizontal lines (like a musical staff)
    let staffTop = s * 0.35
    let staffSpacing = s * 0.065
    let staffLineWidth = max(1.0, unit * 2.0)
    let staffLeft = s * 0.15
    let staffRight = s * 0.85

    ctx.setStrokeColor(CGColor(red: lightColor.r, green: lightColor.g, blue: lightColor.b, alpha: 0.15))
    ctx.setLineWidth(staffLineWidth)

    for i in 0..<5 {
        let y = staffTop + CGFloat(i) * staffSpacing
        ctx.move(to: CGPoint(x: staffLeft, y: y))
        ctx.addLine(to: CGPoint(x: staffRight, y: y))
    }
    ctx.strokePath()

    // Main note — a stylized quarter note in accent color
    let noteHeadCenterX = s * 0.45
    let noteHeadCenterY = staffTop + 3 * staffSpacing  // sits on 4th staff line
    let noteHeadRx = s * 0.075 // horizontal radius (oval)
    let noteHeadRy = s * 0.055 // vertical radius

    // Note head (filled oval, slightly tilted)
    ctx.saveGState()
    ctx.translateBy(x: noteHeadCenterX, y: noteHeadCenterY)
    ctx.rotate(by: -0.3) // slight tilt like real notation
    ctx.setFillColor(CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 1))
    ctx.fillEllipse(in: CGRect(
        x: -noteHeadRx, y: -noteHeadRy,
        width: noteHeadRx * 2, height: noteHeadRy * 2
    ))
    ctx.restoreGState()

    // Stem — vertical line from note head going up
    let stemWidth = max(2.0, unit * 4.0)
    let stemX = noteHeadCenterX + noteHeadRx * 0.85
    let stemBottom = noteHeadCenterY - noteHeadRy * 0.3
    let stemTop = staffTop - s * 0.06

    ctx.setStrokeColor(CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 1))
    ctx.setLineWidth(stemWidth)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: stemX, y: stemBottom))
    ctx.addLine(to: CGPoint(x: stemX, y: stemTop))
    ctx.strokePath()

    // Flag — curved line from top of stem
    let flagStartY = stemTop
    let flagEndX = stemX + s * 0.1
    let flagEndY = stemTop + s * 0.12
    let flagCtrl1X = stemX + s * 0.12
    let flagCtrl1Y = stemTop + s * 0.02
    let flagCtrl2X = stemX + s * 0.08
    let flagCtrl2Y = stemTop + s * 0.10

    ctx.setLineWidth(max(2.0, unit * 3.5))
    ctx.move(to: CGPoint(x: stemX, y: flagStartY))
    ctx.addCurve(
        to: CGPoint(x: flagEndX, y: flagEndY),
        control1: CGPoint(x: flagCtrl1X, y: flagCtrl1Y),
        control2: CGPoint(x: flagCtrl2X, y: flagCtrl2Y)
    )
    ctx.strokePath()

    // Second smaller note — creates a pair (eighth note feel)
    let note2HeadCenterX = s * 0.58
    let note2HeadCenterY = staffTop + 1.5 * staffSpacing  // higher on staff
    let note2HeadRx = s * 0.06
    let note2HeadRy = s * 0.045

    ctx.saveGState()
    ctx.translateBy(x: note2HeadCenterX, y: note2HeadCenterY)
    ctx.rotate(by: -0.3)
    ctx.setFillColor(CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 0.7))
    ctx.fillEllipse(in: CGRect(
        x: -note2HeadRx, y: -note2HeadRy,
        width: note2HeadRx * 2, height: note2HeadRy * 2
    ))
    ctx.restoreGState()

    // Stem for second note
    let stem2X = note2HeadCenterX + note2HeadRx * 0.85
    let stem2Bottom = note2HeadCenterY - note2HeadRy * 0.3
    let stem2Top = note2HeadCenterY - s * 0.18

    ctx.setStrokeColor(CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 0.7))
    ctx.setLineWidth(max(1.5, unit * 3.0))
    ctx.move(to: CGPoint(x: stem2X, y: stem2Bottom))
    ctx.addLine(to: CGPoint(x: stem2X, y: stem2Top))
    ctx.strokePath()

    // Accent bar at bottom — subtle brand line
    let barHeight = s * 0.008
    let barY = s * 0.92
    let barLeft = s * 0.3
    let barRight = s * 0.7

    ctx.setFillColor(CGColor(red: accentColor.r, green: accentColor.g, blue: accentColor.b, alpha: 0.6))
    ctx.fill(CGRect(x: barLeft, y: barY, width: barRight - barLeft, height: barHeight))

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
