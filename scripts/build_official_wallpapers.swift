#!/usr/bin/env swift

import Foundation
import AppKit
import CoreGraphics
import ImageIO
import Vision
import CoreImage
import QuartzCore
import UniformTypeIdentifiers

// MARK: - Paths & Config

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let wallpapersDir = repoRoot.appendingPathComponent("wallpapers")
let metadataURL = wallpapersDir.appendingPathComponent("metadata.json")
let packagesDir = wallpapersDir.appendingPathComponent("packages")
let thumbsDir = wallpapersDir.appendingPathComponent("thumbs")
let sourcesDir = URL(fileURLWithPath: "/tmp/camlo_wp_sources")
let seedBundleDir = repoRoot.appendingPathComponent("Camlo/Resources/PosterSeed.bundle")

struct PackMetadata: Decodable {
    struct MotionConfig: Decodable {
        let style: String
        let fps: Int
        let frameCount: Int
        let duration: Double
    }
    let id: String
    let posterSeedId: Int
    let category: String
    let kind: String
    let titleZh: String
    let titleEn: String
    let subtitleZh: String
    let subtitleEn: String
    let transitionPreset: String
    let particlePreset: String
    let supportsClockDepth: Bool
    let motion: MotionConfig?
}

struct RootMetadata: Decodable {
    let packs: [PackMetadata]
}

// MARK: - Image Utilities (Pure CoreGraphics + ImageIO)

func loadCGImage(at url: URL) throws -> CGImage {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        throw NSError(domain: "BuildWallpapers", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image at \(url.path)"])
    }
    return img
}

func makeRGBContext(width: Int, height: Int) throws -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: cs, bitmapInfo: info) else {
        throw NSError(domain: "BuildWallpapers", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext \(width)x\(height)"])
    }
    ctx.interpolationQuality = .high
    return ctx
}

func aspectFillCGImage(_ source: CGImage, width: Int, height: Int) throws -> CGImage {
    let ctx = try makeRGBContext(width: width, height: height)
    let srcW = CGFloat(source.width)
    let srcH = CGFloat(source.height)
    let dstW = CGFloat(width)
    let dstH = CGFloat(height)
    let scale = max(dstW / srcW, dstH / srcH)
    let drawW = srcW * scale
    let drawH = srcH * scale
    let originX = (dstW - drawW) * 0.5
    let originY = (dstH - drawH) * 0.5
    ctx.draw(source, in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
    guard let out = ctx.makeImage() else {
        throw NSError(domain: "BuildWallpapers", code: 3, userInfo: [NSLocalizedDescriptionKey: "aspectFill makeImage failed"])
    }
    return out
}

func writeJPEG(_ image: CGImage, to url: URL, quality: CGFloat) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        throw NSError(domain: "BuildWallpapers", code: 4, userInfo: [NSLocalizedDescriptionKey: "JPEG destination failed for \(url.path)"])
    }
    let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "BuildWallpapers", code: 5, userInfo: [NSLocalizedDescriptionKey: "JPEG finalize failed for \(url.path)"])
    }
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "BuildWallpapers", code: 6, userInfo: [NSLocalizedDescriptionKey: "PNG destination failed for \(url.path)"])
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "BuildWallpapers", code: 7, userInfo: [NSLocalizedDescriptionKey: "PNG finalize failed for \(url.path)"])
    }
}

// MARK: - Vision Foreground Cutout (Clock Depth)

func extractForegroundCutout(from source1170x2532: CGImage, outWidth: Int = 780, outHeight: Int = 1688) throws -> (CGImage, Double) {
    guard #available(macOS 14.0, *) else {
        throw NSError(domain: "BuildWallpapers", code: 8, userInfo: [NSLocalizedDescriptionKey: "macOS 14+ required for Vision foreground mask"])
    }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: source1170x2532, options: [:])
    try handler.perform([request])

    guard let observation = request.results?.first,
          !observation.allInstances.isEmpty else {
        throw NSError(domain: "BuildWallpapers", code: 9, userInfo: [NSLocalizedDescriptionKey: "No foreground instance detected by Vision"])
    }

    let maskBuffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
    let inputCI = CIImage(cgImage: source1170x2532)
    let maskCI = CIImage(cvPixelBuffer: maskBuffer)
    let clearBG = CIImage(color: .clear).cropped(to: inputCI.extent)

    guard let blend = CIFilter(name: "CIBlendWithMask") else {
        throw NSError(domain: "BuildWallpapers", code: 10, userInfo: [NSLocalizedDescriptionKey: "CIBlendWithMask missing"])
    }
    blend.setValue(inputCI, forKey: kCIInputImageKey)
    blend.setValue(clearBG, forKey: kCIInputBackgroundImageKey)
    blend.setValue(maskCI, forKey: kCIInputMaskImageKey)

    let ciContext = CIContext(options: nil)
    guard let outputCI = blend.outputImage,
          let fullCutout = ciContext.createCGImage(outputCI, from: inputCI.extent) else {
        throw NSError(domain: "BuildWallpapers", code: 11, userInfo: [NSLocalizedDescriptionKey: "Cutout CIContext render failed"])
    }

    let downscaled = try aspectFillCGImage(fullCutout, width: outWidth, height: outHeight)
    let coverage = estimateOpaqueCoverage(downscaled)
    return (downscaled, coverage)
}

func estimateOpaqueCoverage(_ img: CGImage) -> Double {
    guard let dataProvider = img.dataProvider,
          let cfData = dataProvider.data,
          let ptr = CFDataGetBytePtr(cfData) else {
        return 0
    }
    let bpp = max(4, img.bitsPerPixel / 8)
    let totalBytes = CFDataGetLength(cfData)
    let bpr = img.bytesPerRow
    var sampleCount = 0
    var opaqueCount = 0
    let stepY = max(1, img.height / 64)
    let stepX = max(1, img.width / 64)
    for y in stride(from: 0, to: img.height, by: stepY) {
        for x in stride(from: 0, to: img.width, by: stepX) {
            let offset = y * bpr + x * bpp + 3
            if offset < totalBytes {
                sampleCount += 1
                if ptr[offset] > 40 {
                    opaqueCount += 1
                }
            }
        }
    }
    return sampleCount > 0 ? Double(opaqueCount) / Double(sampleCount) : 0
}

// MARK: - Procedural Particle Sprites (CoreGraphics)

func renderParticleSprite(_ preset: String, outDir: URL) throws -> [(filename: String, width: Int, height: Int)] {
    switch preset {
    case "embers":
        let size = 64
        let ctx = try makeRGBContext(width: size, height: size)
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(red: 1.0, green: 0.92, blue: 0.65, alpha: 1.0),
            CGColor(red: 1.0, green: 0.35, blue: 0.16, alpha: 0.85),
            CGColor(red: 0.95, green: 0.12, blue: 0.25, alpha: 0.0)
        ] as CFArray
        let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 0.35, 1.0])!
        let center = CGPoint(x: size / 2, y: size / 2)
        ctx.drawRadialGradient(grad, startCenter: center, startRadius: 1, endCenter: center, endRadius: 30, options: [])
        let url = outDir.appendingPathComponent("particle_ember.png")
        try writePNG(ctx.makeImage()!, to: url)
        return [("particle_ember.png", size, size)]

    case "starlight":
        let size = 64
        let ctx = try makeRGBContext(width: size, height: size)
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            CGColor(red: 0.72, green: 0.88, blue: 1.0, alpha: 0.55),
            CGColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 0.0)
        ] as CFArray
        let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 0.30, 1.0])!
        let c = CGPoint(x: 32, y: 32)
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: 28, options: [])
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))
        let crossH = CGMutablePath()
        crossH.move(to: CGPoint(x: 6, y: 32))
        crossH.addQuadCurve(to: CGPoint(x: 58, y: 32), control: CGPoint(x: 32, y: 30))
        crossH.addQuadCurve(to: CGPoint(x: 6, y: 32), control: CGPoint(x: 32, y: 34))
        ctx.addPath(crossH)
        ctx.fillPath()
        let crossV = CGMutablePath()
        crossV.move(to: CGPoint(x: 32, y: 6))
        crossV.addQuadCurve(to: CGPoint(x: 32, y: 58), control: CGPoint(x: 30, y: 32))
        crossV.addQuadCurve(to: CGPoint(x: 32, y: 6), control: CGPoint(x: 34, y: 32))
        ctx.addPath(crossV)
        ctx.fillPath()
        let url = outDir.appendingPathComponent("particle_star.png")
        try writePNG(ctx.makeImage()!, to: url)
        return [("particle_star.png", size, size)]

    case "sakura":
        let size = 72
        let ctx = try makeRGBContext(width: size, height: size)
        ctx.translateBy(x: 36, y: 36)
        ctx.rotate(by: 0.35)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -22))
        path.addCurve(to: CGPoint(x: 20, y: 6), control1: CGPoint(x: 16, y: -20), control2: CGPoint(x: 24, y: -6))
        path.addCurve(to: CGPoint(x: 0, y: 24), control1: CGPoint(x: 15, y: 18), control2: CGPoint(x: 4, y: 18))
        path.addLine(to: CGPoint(x: 0, y: 15))
        path.addLine(to: CGPoint(x: -4, y: 24))
        path.addCurve(to: CGPoint(x: -20, y: 6), control1: CGPoint(x: -14, y: 18), control2: CGPoint(x: -22, y: 15))
        path.addCurve(to: CGPoint(x: 0, y: -22), control1: CGPoint(x: -20, y: -8), control2: CGPoint(x: -12, y: -20))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.clip()
        let cs = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.94, blue: 0.97, alpha: 1.0),
                CGColor(red: 0.99, green: 0.67, blue: 0.80, alpha: 0.94)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: -24), end: CGPoint(x: 0, y: 24), options: [])
        let url = outDir.appendingPathComponent("particle_sakura.png")
        try writePNG(ctx.makeImage()!, to: url)
        return [("particle_sakura.png", size, size)]

    case "meteorShower":
        let w = 96, h = 24
        let ctx = try makeRGBContext(width: w, height: h)
        let cs = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0),
                CGColor(red: 0.62, green: 0.86, blue: 1.0, alpha: 0.72),
                CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            ] as CFArray,
            locations: [0.0, 0.72, 1.0]
        )!
        ctx.addPath(CGPath(roundedRect: CGRect(x: 4, y: 9, width: 88, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(grad, start: CGPoint(x: 4, y: 12), end: CGPoint(x: 92, y: 12), options: [])
        let url = outDir.appendingPathComponent("particle_meteor.png")
        try writePNG(ctx.makeImage()!, to: url)
        return [("particle_meteor.png", w, h)]

    case "auroraRibbon", "sunbeamRays":
        let w = 256, h = 512
        let ctx = try makeRGBContext(width: w, height: h)
        let cs = CGColorSpaceCreateDeviceRGB()
        let tint: CGColor = (preset == "auroraRibbon")
            ? CGColor(red: 0.25, green: 0.95, blue: 0.82, alpha: 0.45)
            : CGColor(red: 1.0, green: 0.84, blue: 0.48, alpha: 0.42)
        let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                tint,
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        let ray = CGMutablePath()
        ray.move(to: CGPoint(x: 112, y: 512))
        ray.addLine(to: CGPoint(x: 144, y: 512))
        ray.addLine(to: CGPoint(x: 244, y: 0))
        ray.addLine(to: CGPoint(x: 12, y: 0))
        ray.closeSubpath()
        ctx.addPath(ray)
        ctx.clip()
        ctx.drawLinearGradient(grad, start: CGPoint(x: 128, y: 512), end: CGPoint(x: 128, y: 0), options: [])
        let fname = preset == "auroraRibbon" ? "particle_aurora.png" : "particle_ray.png"
        try writePNG(ctx.makeImage()!, to: outDir.appendingPathComponent(fname))
        return [(fname, w, h)]

    case "fireflies":
        let size = 64
        let ctx = try makeRGBContext(width: size, height: size)
        let cs = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.78, green: 0.96, blue: 1.0, alpha: 1.0),
                CGColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 0.55),
                CGColor(red: 0.25, green: 0.35, blue: 0.95, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.38, 1.0]
        )!
        let c = CGPoint(x: 32, y: 32)
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 1, endCenter: c, endRadius: 28, options: [])
        let url = outDir.appendingPathComponent("particle_firefly.png")
        try writePNG(ctx.makeImage()!, to: url)
        return [("particle_firefly.png", size, size)]

    default:
        return []
    }
}

// MARK: - Procedural Seamless Loop Frame Renderers (468x1014 @ 20 frames)

func renderMotionLoopFrames(pack: PackMetadata, width: Int, height: Int, assetsDir: URL) throws -> (frames: [String], heroThumbImage: CGImage) {
    let style = pack.motion?.style ?? "titaniumSilk"
    let frameCount = pack.motion?.frameCount ?? 20
    let baseCG: CGImage?
    let basePath = sourcesDir.appendingPathComponent("\(pack.id)_base.jpg")
    if style != "titaniumSilk" && FileManager.default.fileExists(atPath: basePath.path) {
        let raw = try loadCGImage(at: basePath)
        baseCG = try aspectFillCGImage(raw, width: width, height: height)
    } else {
        baseCG = nil
    }

    var filenames: [String] = []
    var heroFrame: CGImage?

    for i in 0..<frameCount {
        let theta = 2.0 * Double.pi * Double(i) / Double(frameCount)
        let unitProgress = Double(i) / Double(frameCount)
        let ctx = try makeRGBContext(width: width, height: height)
        let w = CGFloat(width)
        let h = CGFloat(height)

        if let bg = baseCG {
            ctx.draw(bg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }

        switch style {
        case "titaniumSilk":
            drawTitaniumSilkFrame(ctx: ctx, w: w, h: h, theta: theta)
        case "auroraCurtain":
            drawAuroraCurtainOverlay(ctx: ctx, w: w, h: h, theta: theta)
        case "oceanShimmer":
            drawOceanShimmerOverlay(ctx: ctx, w: w, h: h, theta: theta)
        case "neonRain":
            drawNeonRainOverlay(ctx: ctx, w: w, h: h, theta: theta, unitProgress: unitProgress)
        case "jellyfishPulse":
            drawJellyfishOverlay(ctx: ctx, w: w, h: h, theta: theta, unitProgress: unitProgress)
        default:
            break
        }

        guard let frameCG = ctx.makeImage() else {
            throw NSError(domain: "BuildWallpapers", code: 20, userInfo: [NSLocalizedDescriptionKey: "Failed frame \(i)"])
        }
        let fname = String(format: "frame_%d.jpg", i)
        try writeJPEG(frameCG, to: assetsDir.appendingPathComponent(fname), quality: 0.78)
        filenames.append(fname)

        if i == 5 {
            if baseCG != nil {
                // Use full crisp base photo enhanced slightly for thumbnail if available
                let raw = try loadCGImage(at: basePath)
                heroFrame = try aspectFillCGImage(raw, width: 360, height: 780)
            } else {
                heroFrame = try aspectFillCGImage(frameCG, width: 360, height: 780)
            }
        }
    }

    return (filenames, heroFrame!)
}

func drawTitaniumSilkFrame(ctx: CGContext, w: CGFloat, h: CGFloat, theta: Double) {
    let cs = CGColorSpaceCreateDeviceRGB()
    // Deep Titanium Slate Base
    let bgGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1.0),
            CGColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1.0),
            CGColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1.0)
        ] as CFArray,
        locations: [0.0, 0.52, 1.0]
    )!
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])

    ctx.saveGState()
    ctx.setBlendMode(.screen)

    // Six sculpted metallic silk wave ribbons sweeping continuously across periodic phase
    let bands: [(yBase: CGFloat, amp: CGFloat, phase: Double, r: CGFloat, g: CGFloat, b: CGFloat, thick: CGFloat)] = [
        (0.68, 52, 0.0, 0.62, 0.68, 0.78, 120),
        (0.56, 65, 1.1, 0.86, 0.76, 0.68, 105),
        (0.46, 58, 2.2, 0.74, 0.78, 0.86, 95),
        (0.36, 48, 3.4, 0.52, 0.60, 0.74, 110),
        (0.24, 38, 4.3, 0.82, 0.74, 0.69, 80),
        (0.79, 44, 5.1, 0.48, 0.54, 0.64, 130)
    ]

    for (idx, band) in bands.enumerated() {
        let p = CGMutablePath()
        let y0 = h * band.yBase
        let step: CGFloat = 24
        p.move(to: CGPoint(x: -160, y: y0))
        var x: CGFloat = -160
        while x <= w + 160 {
            let nx = Double(x / w)
            let wave1 = sin(nx * 3.6 + theta + band.phase) * Double(band.amp)
            let wave2 = cos(nx * 2.1 - theta + Double(idx) * 0.7) * Double(band.amp * 0.45)
            p.addLine(to: CGPoint(x: x, y: y0 + CGFloat(wave1 + wave2)))
            x += step
        }

        // Glow under-stroke + crisp specular silk edge
        ctx.saveGState()
        ctx.addPath(p)
        ctx.setLineWidth(band.thick)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(CGColor(red: band.r * 0.42, green: band.g * 0.42, blue: band.b * 0.45, alpha: 0.24))
        ctx.strokePath()

        ctx.addPath(p)
        ctx.setLineWidth(band.thick * 0.45)
        ctx.setStrokeColor(CGColor(red: band.r * 0.72, green: band.g * 0.72, blue: band.b * 0.75, alpha: 0.28))
        ctx.strokePath()

        ctx.addPath(p)
        ctx.setLineWidth(2.6)
        ctx.setStrokeColor(CGColor(red: min(1.0, band.r + 0.14), green: min(1.0, band.g + 0.14), blue: min(1.0, band.b + 0.12), alpha: 0.65))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Traveling soft volumetric champagne sheen
    let sweepX = w * CGFloat(0.5 + 0.35 * sin(theta))
    let sheen = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.94, green: 0.88, blue: 0.82, alpha: 0.22),
            CGColor(red: 0.72, green: 0.76, blue: 0.85, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: sweepX, y: h * 0.48), startRadius: 8, endCenter: CGPoint(x: sweepX, y: h * 0.48), endRadius: w * 0.82, options: [])
    ctx.restoreGState()
}

func drawAuroraCurtainOverlay(ctx: CGContext, w: CGFloat, h: CGFloat, theta: Double) {
    let cs = CGColorSpaceCreateDeviceRGB()
    ctx.saveGState()
    ctx.setBlendMode(.screen)

    // Gentle emerald & violet aurora wave curtains across the upper night sky
    let curtains: [(yFrac: Double, xShiftAmp: Double, r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat)] = [
        (0.68, 28, 0.12, 0.96, 0.62, 0.22),
        (0.60, 22, 0.42, 0.85, 0.98, 0.16),
        (0.75, 34, 0.68, 0.32, 0.96, 0.14)
    ]

    for (idx, c) in curtains.enumerated() {
        let p = theta + Double(idx) * 2.1
        let cx = w * CGFloat(0.5 + 0.14 * sin(p))
        let cy = h * CGFloat(c.yFrac + 0.03 * cos(p))
        let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: c.r, green: c.g, blue: c.b, alpha: c.alpha),
                CGColor(red: c.r, green: c.g, blue: c.b, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: 1.5, y: 0.48)
        ctx.drawRadialGradient(grad, startCenter: .zero, startRadius: 6, endCenter: .zero, endRadius: w * 0.56, options: [])
        ctx.restoreGState()
    }

    // Vertical aurora ray streaks shimmering gently
    for k in 0..<14 {
        let kf = Double(k) / 14.0
        let x = w * CGFloat(0.10 + 0.80 * kf + 0.04 * sin(theta + kf * 6.0))
        let alpha = CGFloat(0.06 + 0.11 * pow(0.5 + 0.5 * sin(theta + Double(k) * 1.3), 2))
        let rayGrad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.18, green: 0.98, blue: 0.68, alpha: 0.0),
                CGColor(red: 0.20, green: 0.98, blue: 0.72, alpha: alpha),
                CGColor(red: 0.55, green: 0.42, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.42, 1.0]
        )!
        ctx.drawLinearGradient(
            rayGrad,
            start: CGPoint(x: x, y: h * 0.48),
            end: CGPoint(x: x + 18, y: h * 0.88),
            options: []
        )
    }

    // Lower fjord reflection shimmer
    for r in 0..<10 {
        let rf = Double(r) / 10.0
        let y = h * CGFloat(0.08 + rf * 0.20)
        let drift = CGFloat(sin(theta + rf * 5.2) * 22.0)
        let barAlpha = CGFloat(0.05 + 0.08 * (0.5 + 0.5 * cos(theta + rf * 3.7)))
        ctx.setFillColor(CGColor(red: 0.24, green: 0.94, blue: 0.72, alpha: barAlpha))
        ctx.fill(CGRect(x: w * 0.24 + drift, y: y, width: w * 0.52, height: 3.5))
    }

    // Twinkling stars in upper sky
    for s in 0..<26 {
        let sx = CGFloat(((s * 97 + 31) % 100)) / 100.0 * w
        let sy = h * (0.64 + CGFloat(((s * 53 + 17) % 34)) / 100.0)
        let tw = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(theta + Double(s) * 1.9), 3)
        let r = CGFloat(1.1 + (Double(s % 3) * 0.5))
        ctx.setFillColor(CGColor(red: 0.95, green: 0.98, blue: 1.0, alpha: CGFloat(tw * 0.85)))
        ctx.fillEllipse(in: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2))
    }
    ctx.restoreGState()
}

func drawOceanShimmerOverlay(ctx: CGContext, w: CGFloat, h: CGFloat, theta: Double) {
    let cs = CGColorSpaceCreateDeviceRGB()
    ctx.saveGState()
    ctx.setBlendMode(.screen)

    // Warm sun horizon halo gently breathing
    let glowAlpha = CGFloat(0.16 + 0.08 * sin(theta))
    let sunGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 1.0, green: 0.82, blue: 0.42, alpha: glowAlpha),
            CGColor(red: 1.0, green: 0.52, blue: 0.28, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(sunGrad, startCenter: CGPoint(x: w * 0.5, y: h * 0.50), startRadius: 6, endCenter: CGPoint(x: w * 0.5, y: h * 0.50), endRadius: w * 0.62, options: [])

    // Shimmering ocean specular glints on lower half (y in 0.06...0.48 in bottom-up CG coords)
    for row in 0..<32 {
        let rf = Double(row) / 32.0
        let y = h * CGFloat(0.06 + rf * 0.40)
        let spread = 0.08 + (1.0 - rf) * 0.34
        let shift = sin(theta * 2.0 + rf * 9.0) * 18.0 * (1.0 - rf * 0.5)
        let glintAlpha = CGFloat(0.14 + 0.26 * pow(0.5 + 0.5 * sin(theta + Double(row) * 1.6), 2))
        let bw = w * CGFloat(spread * (0.55 + 0.45 * sin(Double(row) * 2.3 + theta)))
        let bx = w * 0.5 - bw * 0.5 + CGFloat(shift)
        ctx.setFillColor(CGColor(red: 1.0, green: 0.86, blue: 0.54, alpha: glintAlpha))
        ctx.fill(CGRect(x: bx, y: y, width: bw, height: CGFloat(1.6 + (1.0 - rf) * 2.4)))
    }
    ctx.restoreGState()
}

func drawNeonRainOverlay(ctx: CGContext, w: CGFloat, h: CGFloat, theta: Double, unitProgress: Double) {
    let cs = CGColorSpaceCreateDeviceRGB()
    ctx.saveGState()
    ctx.setBlendMode(.screen)

    // Pulsing neon reflections on wet ground (bottom 35% -> y in 0...0.35 in CG bottom-up)
    let cyanPulse = CGFloat(0.14 + 0.10 * sin(theta))
    let magPulse = CGFloat(0.12 + 0.10 * cos(theta))

    let g1 = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.15, green: 0.86, blue: 1.0, alpha: cyanPulse),
        CGColor(red: 0.15, green: 0.86, blue: 1.0, alpha: 0.0)
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(g1, startCenter: CGPoint(x: w * 0.34, y: h * 0.18), startRadius: 4, endCenter: CGPoint(x: w * 0.34, y: h * 0.18), endRadius: w * 0.48, options: [])

    let g2 = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 1.0, green: 0.20, blue: 0.65, alpha: magPulse),
        CGColor(red: 1.0, green: 0.20, blue: 0.65, alpha: 0.0)
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(g2, startCenter: CGPoint(x: w * 0.68, y: h * 0.24), startRadius: 4, endCenter: CGPoint(x: w * 0.68, y: h * 0.24), endRadius: w * 0.46, options: [])

    // Seamless falling rain streaks using exact periodic modular wrap
    ctx.setLineCap(.round)
    for drop in 0..<42 {
        let baseX = Double((drop * 73 + 19) % 100) / 100.0
        let baseY = Double((drop * 41 + 7) % 100) / 100.0
        let cycles = Double((drop % 2) + 1)
        let yf = (baseY - unitProgress * cycles).truncatingRemainder(dividingBy: 1.0)
        let normY = yf < 0 ? yf + 1.0 : yf
        let xf = (baseX + unitProgress * 0.15 * cycles).truncatingRemainder(dividingBy: 1.0)

        let px = CGFloat(xf) * w
        let py = CGFloat(normY) * h
        let len = CGFloat(22 + (drop % 4) * 9)
        let edgeFade = min(normY * 6.0, (1.0 - normY) * 6.0, 1.0)
        let isCyan = drop % 3 != 0
        ctx.setLineWidth(1.3)
        ctx.setStrokeColor(CGColor(
            red: isCyan ? 0.55 : 0.98,
            green: isCyan ? 0.92 : 0.55,
            blue: 1.0,
            alpha: CGFloat(0.45 * edgeFade)
        ))
        ctx.move(to: CGPoint(x: px, y: py))
        ctx.addLine(to: CGPoint(x: px - len * 0.16, y: py + len))
        ctx.strokePath()
    }
    ctx.restoreGState()
}

func drawJellyfishOverlay(ctx: CGContext, w: CGFloat, h: CGFloat, theta: Double, unitProgress: Double) {
    let cs = CGColorSpaceCreateDeviceRGB()
    ctx.saveGState()
    ctx.setBlendMode(.screen)

    // Bioluminescent jellyfish bell glow pulse around upper-middle frame
    let pulse = 0.14 + 0.12 * (0.5 + 0.5 * sin(theta))
    let center = CGPoint(x: w * 0.5, y: h * 0.56)
    let glow = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.32, green: 0.88, blue: 1.0, alpha: CGFloat(pulse)),
            CGColor(red: 0.48, green: 0.42, blue: 1.0, alpha: CGFloat(pulse * 0.55)),
            CGColor(red: 0.10, green: 0.15, blue: 0.55, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 0.45, 1.0]
    )!
    ctx.drawRadialGradient(glow, startCenter: center, startRadius: 8, endCenter: center, endRadius: w * 0.68, options: [])

    // Rising glowing abyssal plankton bokeh orbs (seamless periodic loop)
    for p in 0..<28 {
        let bx = Double((p * 67 + 13) % 100) / 100.0
        let by = Double((p * 43 + 29) % 100) / 100.0
        let yf = (by + unitProgress).truncatingRemainder(dividingBy: 1.0)
        let drift = 0.03 * sin(theta + Double(p) * 1.4)
        let px = CGFloat(bx + drift) * w
        let py = CGFloat(yf) * h
        let fade = sin(yf * Double.pi) // smooth 0 -> 1 -> 0 wrap fade
        let radius = CGFloat(2.0 + Double(p % 4) * 1.4)
        let orbGrad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.52, green: 0.94, blue: 1.0, alpha: CGFloat(0.68 * fade)),
                CGColor(red: 0.32, green: 0.55, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        let pt = CGPoint(x: px, y: py)
        ctx.drawRadialGradient(orbGrad, startCenter: pt, startRadius: 0, endCenter: pt, endRadius: radius * 2.5, options: [])
    }
    ctx.restoreGState()
}

// MARK: - CAML 1.0 XML Generators (100% Aligned with Camlo CAMLCompiler & Apple CAPackage)

func standardIndexXML(width: Int = 390, height: Int = 844) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \t<key>assetManifest</key>
    \t<string>assetManifest.caml</string>
    \t<key>documentHeight</key>
    \t<real>\(height)</real>
    \t<key>documentResizesToView</key>
    \t<false/>
    \t<key>documentWidth</key>
    \t<real>\(width)</real>
    \t<key>geometryFlipped</key>
    \t<false/>
    \t<key>loopEnd</key>
    \t<real>+infinity</real>
    \t<key>loopStart</key>
    \t<real>0.0</real>
    \t<key>loopingEnabled</key>
    \t<true/>
    \t<key>rootDocument</key>
    \t<string>main.caml</string>
    \t<key>scalesToFitInPlayer</key>
    \t<true/>
    </dict>
    </plist>
    """
}

func standardAssetManifestXML() -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>

    <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
      <MicaAssetManifest>
        <modules type="NSArray"/>
      </MicaAssetManifest>
    </caml>
    """
}

struct StateOverride {
    let targetId: String
    let keyPath: String
    let sleepVal: Double
    let lockedVal: Double
    let unlockVal: Double
    let isInteger: Bool
}

func wrapRootCAML(
    opaqueBlackBackground: Bool,
    sublayersXML: String,
    overrides: [StateOverride],
    duration: Double = 0.85,
    bounce: Double = 0.35
) -> String {
    let clampedDur = max(0.25, min(duration, 2.0))
    let clampedBounce = max(0.0, min(bounce, 1.0))
    let mass = 1.0
    let stiffness = (260.0 / max(0.35, clampedDur)).rounded()
    let criticalDamping = 2.0 * sqrt(stiffness * mass)
    let dampingRatio = 1.02 - (clampedBounce * 0.48)
    let damping = max(12.0, (criticalDamping * dampingRatio).rounded())
    let durAttr = String(format: "%.2f", clampedDur)

    func stateElements(stage: String) -> String {
        guard !overrides.isEmpty else { return "        <elements/>" }
        var lines: [String] = ["        <elements>"]
        for ov in overrides {
            let raw: Double
            switch stage {
            case "Sleep": raw = ov.sleepVal
            case "Locked": raw = ov.lockedVal
            default: raw = ov.unlockVal
            }
            let typeStr = ov.isInteger ? "integer" : "real"
            let valStr = ov.isInteger ? String(Int(raw.rounded())) : String(format: "%.4f", raw)
            lines.append("""
                      <LKStateSetValue targetId="\(ov.targetId)" keyPath="\(ov.keyPath)">
                        <value type="\(typeStr)" value="\(valStr)"/>
                      </LKStateSetValue>
            """)
        }
        lines.append("        </elements>")
        return lines.joined(separator: "\n")
    }

    func transitionElements() -> String {
        guard !overrides.isEmpty else { return "        <elements/>" }
        var lines: [String] = ["        <elements>"]
        for ov in overrides {
            lines.append("""
                      <LKStateTransitionElement targetId="\(ov.targetId)" key="\(ov.keyPath)">
                        <animation type="CASpringAnimation" damping="\(Int(damping))" mass="1" stiffness="\(Int(stiffness))" velocity="0" duration="\(durAttr)" fillMode="backwards" keyPath="\(ov.keyPath)" mica_autorecalculatesDuration="1"/>
                      </LKStateTransitionElement>
            """)
        }
        lines.append("        </elements>")
        return lines.joined(separator: "\n")
    }

    let lockedEls = stateElements(stage: "Locked")
    let unlockEls = stateElements(stage: "Unlock")
    let sleepEls = stateElements(stage: "Sleep")
    let transEls = transitionElements()
    let bgAttr = opaqueBlackBackground ? " backgroundColor=\"0 0 0\"" : ""
    let innerSublayers = sublayersXML.isEmpty ? "" : "\n      <sublayers>\n\(sublayersXML)\n      </sublayers>"

    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- Generated by Camlo Cloud Builder -->
    <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
      <CALayer id="__capRootLayer__" name="CAPlayground Root Layer" bounds="0 0 390 844" position="195 422" zPosition="0" geometryFlipped="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
        <sublayers>
          <CALayer id="camlo_root" name="Root Layer" bounds="0 0 390 844" position="195 422" zPosition="0" geometryFlipped="0" opacity="1"\(bgAttr) allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(innerSublayers)
          </CALayer>
        </sublayers>
        <modules/>
        <states>
          <LKState name="Locked">
    \(lockedEls)
          </LKState>
          <LKState name="Unlock">
    \(unlockEls)
          </LKState>
          <LKState name="Sleep">
    \(sleepEls)
          </LKState>
        </states>
        <stateTransitions>
          <LKStateTransition fromState="*" toState="Unlock">
    \(transEls)
          </LKStateTransition>
          <LKStateTransition fromState="Unlock" toState="*">
    \(transEls)
          </LKStateTransition>
          <LKStateTransition fromState="*" toState="Locked">
    \(transEls)
          </LKStateTransition>
          <LKStateTransition fromState="Locked" toState="*">
    \(transEls)
          </LKStateTransition>
          <LKStateTransition fromState="*" toState="Sleep">
    \(transEls)
          </LKStateTransition>
          <LKStateTransition fromState="Sleep" toState="*">
    \(transEls)
          </LKStateTransition>
        </stateTransitions>
      </CALayer>
    </caml>
    """
}

func camlMotionBackgroundXML(frameNames: [String], duration: Double) -> String {
    let frameValues = frameNames.map { "                  <CGImage src=\"assets/\($0)\"/>" }.joined(separator: "\n")
    let durStr = String(format: "%.3f", max(0.2, duration))
    let firstFrame = frameNames.first ?? "frame_0.jpg"

    let sublayers = """
              <CALayer id="video_seq_layer" name="Video Sequence Layer" bounds="0 0 390 844" position="195 422" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <contents><CGImage src="assets/\(firstFrame)"/></contents>
                <animations>
                  <animation type="CAKeyframeAnimation" calculationMode="discrete" fillMode="both" keyPath="contents" beginTime="1e-100" duration="\(durStr)" removedOnCompletion="0" repeatCount="inf" repeatDuration="0" speed="1" timeOffset="0" autoreverses="0">
                    <values>
    \(frameValues)
                    </values>
                  </animation>
                </animations>
              </CALayer>
              <CALayer id="video_sleep_dim" name="Sleep Dimmer" bounds="0 0 390 844" position="195 422" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
    """

    let overrides = [
        StateOverride(targetId: "video_seq_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.04, isInteger: false),
        StateOverride(targetId: "video_sleep_dim", keyPath: "opacity", sleepVal: 0.65, lockedVal: 0.0, unlockVal: 0.0, isInteger: false)
    ]

    return wrapRootCAML(opaqueBlackBackground: true, sublayersXML: sublayers, overrides: overrides, duration: 0.75, bounce: 0.35)
}

func camlMorphBackgroundXML(transitionPreset: String) -> String {
    let unlockLayer = """
              <CALayer id="unlock_layer" name="Unlock Layer" bounds="0 0 390 844" position="195 422" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <contents>
                  <CGImage src="assets/unlock.jpg"/>
                </contents>
              </CALayer>
    """
    let lockedLayer = """
              <CALayer id="locked_layer" name="Locked Layer" bounds="0 0 390 844" position="195 422" zPosition="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <contents>
                  <CGImage src="assets/locked.jpg"/>
                </contents>
              </CALayer>
    """
    let sleepAlpha = (transitionPreset == "aodGaze") ? 0.78 : 0.48
    let dimmerLayer = """
              <CALayer id="sleep_dimmer" name="Sleep Dimmer" bounds="0 0 390 844" position="195 422" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
    """

    var overrides = [
        StateOverride(targetId: "sleep_dimmer", keyPath: "opacity", sleepVal: sleepAlpha, lockedVal: 0.0, unlockVal: 0.0, isInteger: false)
    ]

    switch transitionPreset {
    case "curtainRise":
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "position.y", sleepVal: 422, lockedVal: 422, unlockVal: 940, isInteger: true),
            StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 0.96, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "position.y", sleepVal: 392, lockedVal: 404, unlockVal: 422, isInteger: true),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false)
        ])
    case "burstZoom":
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.04, lockedVal: 1.0, unlockVal: 0.86, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.24, lockedVal: 1.22, unlockVal: 1.0, isInteger: false)
        ])
    case "holoCard":
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.rotation.y", sleepVal: -0.06, lockedVal: 0.0, unlockVal: 0.24, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "position.x", sleepVal: 195, lockedVal: 195, unlockVal: 215, isInteger: true),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.rotation.y", sleepVal: -0.24, lockedVal: -0.22, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "position.x", sleepVal: 175, lockedVal: 178, unlockVal: 195, isInteger: true),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.06, lockedVal: 1.05, unlockVal: 1.0, isInteger: false)
        ])
    case "aodGaze":
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 0.94, lockedVal: 1.0, unlockVal: 1.06, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.14, lockedVal: 1.12, unlockVal: 1.0, isInteger: false)
        ])
    default: // flashAwaken / crossfade
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.08, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.12, lockedVal: 1.10, unlockVal: 1.0, isInteger: false)
        ])
    }

    return wrapRootCAML(
        opaqueBlackBackground: true,
        sublayersXML: [unlockLayer, lockedLayer, dimmerLayer].joined(separator: "\n"),
        overrides: overrides,
        duration: 0.85,
        bounce: 0.35
    )
}

func camlFloatingCutoutXML(hasCutout: Bool, transitionPreset: String) -> String {
    guard hasCutout else {
        return wrapRootCAML(opaqueBlackBackground: false, sublayersXML: "", overrides: [], duration: 0.70, bounce: 0.30)
    }

    let floatUnlock = """
              <CALayer id="float_unlock" name="Floating Unlock Subject" bounds="0 0 390 844" position="195 422" zPosition="1" opacity="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <contents>
                  <CGImage src="assets/cutout_unlock.png"/>
                </contents>
              </CALayer>
    """
    let floatLock = """
              <CALayer id="float_lock" name="Floating Lock Subject" bounds="0 0 390 844" position="195 422" zPosition="2" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <contents>
                  <CGImage src="assets/cutout_lock.png"/>
                </contents>
              </CALayer>
    """

    let unlockY: Double = (transitionPreset == "curtainRise") ? 960 : 422
    let lockEndScale: Double = (transitionPreset == "burstZoom") ? 0.84 : 1.06

    let overrides = [
        StateOverride(targetId: "float_unlock", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
        StateOverride(targetId: "float_unlock", keyPath: "transform.scale.xy", sleepVal: 1.16, lockedVal: 1.14, unlockVal: 1.0, isInteger: false),
        StateOverride(targetId: "float_lock", keyPath: "opacity", sleepVal: 0.72, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
        StateOverride(targetId: "float_lock", keyPath: "position.y", sleepVal: 422, lockedVal: 422, unlockVal: unlockY, isInteger: true),
        StateOverride(targetId: "float_lock", keyPath: "transform.scale.xy", sleepVal: 0.98, lockedVal: 1.0, unlockVal: lockEndScale, isInteger: false)
    ]

    return wrapRootCAML(
        opaqueBlackBackground: false,
        sublayersXML: [floatUnlock, floatLock].joined(separator: "\n"),
        overrides: overrides,
        duration: 0.85,
        bounce: 0.35
    )
}

func camlForegroundXML(preset: String, spriteName: String?, includeFlashPulse: Bool) -> String {
    guard spriteName != nil || includeFlashPulse else {
        return wrapRootCAML(opaqueBlackBackground: false, sublayersXML: "", overrides: [], duration: 0.65, bounce: 0.25)
    }

    var sublayers: [String] = []
    var overrides: [StateOverride] = []

    if includeFlashPulse {
        sublayers.append("""
                  <CALayer id="flash_veil" name="Flash Veil" bounds="0 0 390 844" position="195 422" zPosition="1" opacity="0" backgroundColor="1 0.98 0.94" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
        """)
        overrides.append(StateOverride(targetId: "flash_veil", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 0.06, isInteger: false))
    }

    if let spriteName {
        if preset == "auroraRibbon" || preset == "sunbeamRays" {
            sublayers.append("""
                  <CALayer id="camlo_volumetric_beam" name="Volumetric Light" bounds="0 0 480 920" position="195 520" zPosition="2" opacity="0.62" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents type="CGImage" src="assets/\(spriteName)"/>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                    <animations>
                      <animation type="CAKeyframeAnimation" keyPath="opacity" autoreverses="1" beginTime="1e-100" duration="5.6" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="0.28"/>
                          <real value="0.68"/>
                        </values>
                      </animation>
                    </animations>
                  </CALayer>
            """)
            overrides.append(StateOverride(targetId: "camlo_volumetric_beam", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.62, unlockVal: 0.55, isInteger: false))
            overrides.append(StateOverride(targetId: "camlo_volumetric_beam", keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false))
        } else {
            let birthRate: Double
            let velocity: Double
            let yAccel: Double
            let scale: Double
            let ePosY: Int
            let emLong: Double
            let emRange: Double
            let spin: Double
            switch preset {
            case "embers":
                birthRate = 9.0; velocity = 42; yAccel = 18; scale = 0.28; ePosY = 120; emLong = 1.57; emRange = 1.20; spin = 1.2
            case "sakura":
                birthRate = 5.5; velocity = 48; yAccel = -14; scale = 0.36; ePosY = 820; emLong = -1.57; emRange = 0.90; spin = 1.8
            case "meteorShower":
                birthRate = 3.0; velocity = 280; yAccel = -40; scale = 0.45; ePosY = 740; emLong = -2.25; emRange = 0.22; spin = 0.0
            case "fireflies":
                birthRate = 6.0; velocity = 18; yAccel = 6; scale = 0.26; ePosY = 420; emLong = 1.57; emRange = 3.14; spin = 0.6
            default: // starlight
                birthRate = 7.0; velocity = 14; yAccel = 4; scale = 0.25; ePosY = 460; emLong = 1.57; emRange = 3.14; spin = 0.8
            }

            sublayers.append("""
                  <CAEmitterLayer id="camlo_emitter" name="Camlo Emitter" bounds="0 0 390 844" position="195 422" zPosition="4" emitterPosition="195 \(ePosY)" emitterSize="390 220" emitterShape="rectangle" emitterMode="volume" renderMode="additive" birthRate="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <emitterCells>
                      <CAEmitterCell id="camlo_cell_main" name="camlo_cell_main" contentsScale="2" birthRate="\(birthRate)" lifetime="6.2" velocity="\(velocity)" velocityRange="24" emissionRange="\(emRange)" emissionLongitude="\(emLong)" emissionLatitude="0" scale="\(scale)" scaleRange="0.14" scaleSpeed="-0.01" alphaRange="0.25" alphaSpeed="-0.12" spin="\(spin)" spinRange="1.2" yAcceleration="\(yAccel)">
                        <color value="1 1 1" opacity="0.94"/>
                        <contents>
                          <CGImage src="assets/\(spriteName)"/>
                        </contents>
                      </CAEmitterCell>
                    </emitterCells>
                  </CAEmitterLayer>
            """)
            overrides.append(StateOverride(targetId: "camlo_emitter", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 0.88, isInteger: false))
            overrides.append(StateOverride(targetId: "camlo_emitter", keyPath: "birthRate", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false))
        }
    }

    return wrapRootCAML(opaqueBlackBackground: false, sublayersXML: sublayers.joined(separator: "\n"), overrides: overrides, duration: 0.65, bounce: 0.25)
}

// MARK: - CAPackage Validation (macOS QuartzCore SPI via ObjC runtime)

func verifyCAPackage(at caURL: URL) throws {
    _ = try XMLDocument(contentsOf: caURL.appendingPathComponent("main.caml"), options: [])
    _ = try XMLDocument(contentsOf: caURL.appendingPathComponent("assetManifest.caml"), options: [])
    _ = try PropertyListSerialization.propertyList(from: Data(contentsOf: caURL.appendingPathComponent("index.xml")), format: nil)

    guard let pkgClass: AnyClass = NSClassFromString("CAPackage") else {
        throw NSError(domain: "BuildWallpapers", code: 29, userInfo: [NSLocalizedDescriptionKey: "CAPackage runtime class missing"])
    }
    let sel = NSSelectorFromString("packageWithContentsOfURL:type:options:error:")
    guard let method = class_getClassMethod(pkgClass, sel) else {
        throw NSError(domain: "BuildWallpapers", code: 31, userInfo: [NSLocalizedDescriptionKey: "CAPackage selector missing"])
    }
    typealias PackageFn = @convention(c) (AnyClass, Selector, NSURL, NSString, NSDictionary?, AutoreleasingUnsafeMutablePointer<NSError?>?) -> AnyObject?
    let fn = unsafeBitCast(method_getImplementation(method), to: PackageFn.self)
    var err: NSError?
    let pkg = fn(pkgClass, sel, caURL as NSURL, "com.apple.coreanimation-bundle" as NSString, nil, &err)
    let fallbackPkg: AnyObject?
    if pkg == nil {
        err = nil
        fallbackPkg = fn(pkgClass, sel, caURL.appendingPathComponent("main.caml") as NSURL, "com.apple.coreanimation-xml" as NSString, nil, &err)
    } else {
        fallbackPkg = pkg
    }
    if let err {
        throw err
    }
    guard let validPkg = fallbackPkg as? NSObject,
          validPkg.value(forKey: "rootLayer") != nil else {
        throw NSError(domain: "BuildWallpapers", code: 30, userInfo: [NSLocalizedDescriptionKey: "CAPackage rootLayer nil at \(caURL.path)"])
    }
}

// MARK: - Descriptor & Tendies Assembly

func scaffoldDescriptor(pack: PackMetadata, in workRoot: URL) throws -> URL {
    let fm = FileManager.default
    let descriptorUUID = UUID().uuidString.uppercased()
    let descrDir = workRoot
        .appendingPathComponent("descriptors", isDirectory: true)
        .appendingPathComponent(descriptorUUID, isDirectory: true)
    let ver1Dir = descrDir.appendingPathComponent("versions/1", isDirectory: true)
    let contentsDir = ver1Dir.appendingPathComponent("contents", isDirectory: true)
    let suppDir = ver1Dir.appendingPathComponent("supplements/0", isDirectory: true)
    let wallpaperBundleName = "7400.WWDC_2022-390w-844h@3x~iphone.wallpaper"
    let wallpaperBundleDir = contentsDir.appendingPathComponent(wallpaperBundleName, isDirectory: true)

    try fm.createDirectory(at: wallpaperBundleDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: suppDir, withIntermediateDirectories: true)

    // Root descriptor metadata matching TendiesPackager
    try String(pack.posterSeedId).write(to: descrDir.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier"), atomically: true, encoding: .utf8)
    try "PRPosterRoleLockScreen".write(to: descrDir.appendingPathComponent("com.apple.posterkit.role.identifier"), atomically: true, encoding: .utf8)

    let seedFiles: [(String, URL)] = [
        ("providerInfo.plist", descrDir.appendingPathComponent("providerInfo.plist")),
        ("RuntimeSnapshotMetadata-home.plist", ver1Dir.appendingPathComponent("RuntimeSnapshotMetadata-home.plist")),
        ("RuntimeSnapshotMetadata-lock.plist", ver1Dir.appendingPathComponent("RuntimeSnapshotMetadata-lock.plist")),
        ("complicationLayout.plist", ver1Dir.appendingPathComponent("com.apple.posterkit.provider.instance.complicationLayout.plist")),
        ("titleStyleConfiguration.plist", ver1Dir.appendingPathComponent("com.apple.posterkit.provider.instance.titleStyleConfiguration.plist")),
        ("homescreenConfiguration.plist", suppDir.appendingPathComponent("com.apple.posterkit.provider.supplementURL.homescreenConfiguration.plist")),
        ("configurableOptions.plist", contentsDir.appendingPathComponent(".com.apple.posterkit.provider.contents.configurableOptions.plist")),
        ("otherMetadata.plist", contentsDir.appendingPathComponent("com.apple.posterkit.provider.contents.otherMetadata.plist"))
    ]
    for (seedName, destURL) in seedFiles {
        let src = seedBundleDir.appendingPathComponent(seedName)
        guard fm.fileExists(atPath: src.path) else {
            throw NSError(domain: "BuildWallpapers", code: 40, userInfo: [NSLocalizedDescriptionKey: "Missing PosterSeed plist: \(src.path)"])
        }
        if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
        try fm.copyItem(at: src, to: destURL)
    }

    let userInfoDict: [String: Any] = [
        "wallpaperRepresentingIdentifier": pack.posterSeedId,
        "wallpaperRepresentingFileName": wallpaperBundleName,
        "posterEnvironmentOverrides": Data("{}".utf8)
    ]
    let userInfoData = try PropertyListSerialization.data(fromPropertyList: userInfoDict, format: .binary, options: 0)
    try userInfoData.write(to: contentsDir.appendingPathComponent("com.apple.posterkit.provider.contents.userInfo"), options: .atomic)

    let wallpaperPlist: [String: Any] = [
        "appearanceAware": false,
        "family": "WWDC22",
        "identifier": pack.posterSeedId,
        "logicalScreenClass": "390w-844h@3x~iphone",
        "name": "WWDC 2022",
        "version": 1,
        "assets": [
            "lockAndHome": [
                "default": [
                    "backgroundAnimationFileName": "7400.WWDC_2022_Background-390w-844h@3x~iphone.ca",
                    "floatingAnimationFileNameKey": "7400.WWDC_2022_Floating-390w-844h@3x~iphone.ca",
                    "foregroundAnimationFileName": "7400.WWDC_2022_Foreground-390w-844h@3x~iphone.ca",
                    "identifier": 7400,
                    "name": "WWDC 2022",
                    "type": "LayeredAnimation"
                ]
            ]
        ]
    ]
    let wpData = try PropertyListSerialization.data(fromPropertyList: wallpaperPlist, format: .binary, options: 0)
    try wpData.write(to: wallpaperBundleDir.appendingPathComponent("Wallpaper.plist"), options: .atomic)

    return wallpaperBundleDir
}

func runDittoZip(sourceDir: URL, outputTendies: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: outputTendies.path) {
        try fm.removeItem(at: outputTendies)
    }
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    proc.arguments = ["-c", "-k", "--norsrc", sourceDir.path, outputTendies.path]
    let pipe = Pipe()
    proc.standardError = pipe
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus != 0 {
        let errText = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "ditto failed"
        throw NSError(domain: "BuildWallpapers", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errText])
    }
}

// MARK: - Build Pipeline

func buildAll() throws {
    let fm = FileManager.default
    try fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: thumbsDir, withIntermediateDirectories: true)

    let metaData = try Data(contentsOf: metadataURL)
    let rootMeta = try JSONDecoder().decode(RootMetadata.self, from: metaData)
    print("[*] Loaded \(rootMeta.packs.count) pack definitions from \(metadataURL.path)")

    for pack in rootMeta.packs {
        let workRoot = fm.temporaryDirectory.appendingPathComponent("camlo_wp_build_\(pack.id)_\(UUID().uuidString.prefix(6))", isDirectory: true)
        defer { try? fm.removeItem(at: workRoot) }

        let wpDir = try scaffoldDescriptor(pack: pack, in: workRoot)
        let bgCA = wpDir.appendingPathComponent("7400.WWDC_2022_Background-390w-844h@3x~iphone.ca", isDirectory: true)
        let flCA = wpDir.appendingPathComponent("7400.WWDC_2022_Floating-390w-844h@3x~iphone.ca", isDirectory: true)
        let fgCA = wpDir.appendingPathComponent("7400.WWDC_2022_Foreground-390w-844h@3x~iphone.ca", isDirectory: true)
        for ca in [bgCA, flCA, fgCA] {
            try fm.createDirectory(at: ca.appendingPathComponent("assets", isDirectory: true), withIntermediateDirectories: true)
            try standardIndexXML().write(to: ca.appendingPathComponent("index.xml"), atomically: true, encoding: .utf8)
            try standardAssetManifestXML().write(to: ca.appendingPathComponent("assetManifest.caml"), atomically: true, encoding: .utf8)
        }

        let thumbOutURL = thumbsDir.appendingPathComponent("\(pack.id).jpg")
        let tendiesOutURL = packagesDir.appendingPathComponent("\(pack.id).tendies")

        if pack.kind == "motionLoop" {
            let w = 468, h = 1014
            let (frameNames, heroThumb) = try renderMotionLoopFrames(pack: pack, width: w, height: h, assetsDir: bgCA.appendingPathComponent("assets"))
            try writeJPEG(heroThumb, to: thumbOutURL, quality: 0.86)

            let fps = pack.motion?.fps ?? 14
            let dur = pack.motion?.duration ?? (Double(frameNames.count) / Double(fps) * 2.0)
            try camlMotionBackgroundXML(frameNames: frameNames, duration: dur).write(to: bgCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)
            try camlFloatingCutoutXML(hasCutout: false, transitionPreset: pack.transitionPreset).write(to: flCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)

            let fgAssets = try renderParticleSprite(pack.particlePreset, outDir: fgCA.appendingPathComponent("assets"))
            try camlForegroundXML(preset: pack.particlePreset, spriteName: fgAssets.first?.filename, includeFlashPulse: false).write(to: fgCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)
        } else {
            // Morph Pair + Vision Clock Depth Cutout
            let lockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_lock.jpg"))
            let unlockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_unlock.jpg"))
            let lock1170 = try aspectFillCGImage(lockRaw, width: 1170, height: 2532)
            let unlock1170 = try aspectFillCGImage(unlockRaw, width: 1170, height: 2532)

            try writeJPEG(lock1170, to: bgCA.appendingPathComponent("assets/locked.jpg"), quality: 0.85)
            try writeJPEG(unlock1170, to: bgCA.appendingPathComponent("assets/unlock.jpg"), quality: 0.85)
            let thumbCG = try aspectFillCGImage(unlockRaw, width: 360, height: 780)
            try writeJPEG(thumbCG, to: thumbOutURL, quality: 0.86)

            try camlMorphBackgroundXML(transitionPreset: pack.transitionPreset).write(to: bgCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)

            var hasCutout = false
            if pack.supportsClockDepth {
                do {
                    let (cutLock, covLock) = try extractForegroundCutout(from: lock1170, outWidth: 780, outHeight: 1688)
                    let (cutUnlock, covUnlock) = try extractForegroundCutout(from: unlock1170, outWidth: 780, outHeight: 1688)
                    if covLock > 0.04 && covUnlock > 0.04 {
                        try writePNG(cutLock, to: flCA.appendingPathComponent("assets/cutout_lock.png"))
                        try writePNG(cutUnlock, to: flCA.appendingPathComponent("assets/cutout_unlock.png"))
                        hasCutout = true
                        print(String(format: "    [Vision] %@ cutout coverage: lock=%.1f%% unlock=%.1f%%", pack.id, covLock * 100.0, covUnlock * 100.0))
                    } else {
                        print(String(format: "    [Vision] %@ low cutout coverage (lock=%.1f%%, unlock=%.1f%%), skipping Floating layer", pack.id, covLock * 100.0, covUnlock * 100.0))
                    }
                } catch {
                    print("    [Vision] \(pack.id) cutout skipped: \(error.localizedDescription)")
                }
            }
            try camlFloatingCutoutXML(hasCutout: hasCutout, transitionPreset: pack.transitionPreset).write(to: flCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)

            let fgAssets = try renderParticleSprite(pack.particlePreset, outDir: fgCA.appendingPathComponent("assets"))
            try camlForegroundXML(preset: pack.particlePreset, spriteName: fgAssets.first?.filename, includeFlashPulse: pack.transitionPreset == "flashAwaken").write(to: fgCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)
        }

        // Strict QuartzCore CAPackage parse validation on all three .ca bundles!
        try verifyCAPackage(at: bgCA)
        try verifyCAPackage(at: flCA)
        try verifyCAPackage(at: fgCA)

        try runDittoZip(sourceDir: workRoot, outputTendies: tendiesOutURL)
        let pkgSize = (try? fm.attributesOfItem(atPath: tendiesOutURL.path)[.size] as? Int) ?? 0
        print(String(format: "[+] Built %@.tendies (%d KB) · CAPackage verified", pack.id, pkgSize / 1024))
    }

    print("[✓] All \(rootMeta.packs.count) official .tendies packs built & verified!")
}

do {
    try buildAll()
} catch {
    fputs("[!] Error: \(error)\n", stderr)
    exit(1)
}
