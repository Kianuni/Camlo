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
let presetBundleDir = repoRoot.appendingPathComponent("Camlo/Resources/PresetGallery.bundle")
let seedBundleDir = repoRoot.appendingPathComponent("Camlo/Resources/PosterSeed.bundle")

struct PackMetadata: Decodable {
    struct MotionConfig: Decodable {
        let style: String
        let fps: Int
        let frameCount: Int
        let duration: Double
    }
    let id: String
    let sourceBundlePrefix: String?
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
    let depthMaskMode: String?
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

/// Flood-fills upper sky from top border (y = 0...8%) to cleanly separate mountain peaks, arches,
/// dunes, and nebula pillars from the upper Clock zone (`09:41`), with soft feathered alpha edges.
func extractSkylineCutout(from source1170x2532: CGImage, outWidth: Int = 780, outHeight: Int = 1688) throws -> (CGImage, Double) {
    let fitted = try aspectFillCGImage(source1170x2532, width: outWidth, height: outHeight)
    guard let data = fitted.dataProvider?.data,
          let rawPtr = CFDataGetBytePtr(data) else {
        throw NSError(domain: "BuildWallpapers", code: 13, userInfo: [NSLocalizedDescriptionKey: "Missing pixel buffer for skyline mask"])
    }
    let w = fitted.width
    let h = fitted.height
    let bpp = max(4, fitted.bitsPerPixel / 8)
    let bpr = fitted.bytesPerRow

    @inline(__always)
    func pixelRGB(_ x: Int, _ y: Int) -> (Int, Int, Int) {
        let off = y * bpr + x * bpp
        return (Int(rawPtr[off]), Int(rawPtr[off + 1]), Int(rawPtr[off + 2]))
    }

    // Sample median/mean sky reference from top 6% band per column-bucket (16 buckets across width)
    let buckets = 16
    var refR = [Double](repeating: 0, count: buckets)
    var refG = [Double](repeating: 0, count: buckets)
    var refB = [Double](repeating: 0, count: buckets)
    let bandH = max(8, Int(Double(h) * 0.06))
    for b in 0..<buckets {
        let x0 = (b * w) / buckets
        let x1 = ((b + 1) * w) / buckets
        var sr = 0.0, sg = 0.0, sb = 0.0, cnt = 0.0
        for y in stride(from: 2, to: bandH, by: 2) {
            for x in stride(from: x0, to: x1, by: 2) {
                let (r, g, bl) = pixelRGB(x, y)
                sr += Double(r); sg += Double(g); sb += Double(bl); cnt += 1.0
            }
        }
        refR[b] = sr / max(1.0, cnt)
        refG[b] = sg / max(1.0, cnt)
        refB[b] = sb / max(1.0, cnt)
    }

    // 4-connected BFS flood fill from top 8% rows across pixels that remain close to upper sky color/luma
    // and lack strong high-frequency edge jump against their parent neighbor.
    var isSky = [UInt8](repeating: 0, count: w * h)
    var queue = [Int]()
    queue.reserveCapacity(w * h / 2)

    let topSeedRows = max(12, Int(Double(h) * 0.08))
    for y in 0..<topSeedRows {
        for x in 0..<w {
            let idx = y * w + x
            isSky[idx] = 1
            queue.append(idx)
        }
    }

    let maxStopY = Int(Double(h) * 0.88)
    var head = 0
    while head < queue.count {
        let cur = queue[head]
        head += 1
        let cx = cur % w
        let cy = cur / w
        let (cr, cg, cb) = pixelRGB(cx, cy)
        let bucket = min(buckets - 1, max(0, (cx * buckets) / w))
        let br = refR[bucket], bg = refG[bucket], bb = refB[bucket]

        let neighbors = [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]
        for (nx, ny) in neighbors {
            if nx < 0 || nx >= w || ny < 0 || ny >= maxStopY { continue }
            let nIdx = ny * w + nx
            if isSky[nIdx] != 0 { continue }
            let (nr, ng, nb) = pixelRGB(nx, ny)

            let stepDiff = abs(nr - cr) + abs(ng - cg) + abs(nb - cb)
            let refDiff = abs(Double(nr) - br) + abs(Double(ng) - bg) + abs(Double(nb) - bb)
            let localLuma = 0.299 * Double(nr) + 0.587 * Double(ng) + 0.114 * Double(nb)
            let refLuma = 0.299 * br + 0.587 * bg + 0.114 * bb
            // Allow gradual twilight sky gradient vertically, stop at sharp silhouettes or dark mountain faces
            let verticalAllowance = 42.0 + 45.0 * min(1.0, Double(ny) / Double(h))
            if stepDiff < 48 && (refDiff < verticalAllowance || abs(localLuma - refLuma) < 32.0) {
                isSky[nIdx] = 1
                queue.append(nIdx)
            }
        }
    }

    // Build 8-bit grayscale alpha buffer (0 = sky transparent, 255 = foreground opaque)
    var maskBytes = [UInt8](repeating: 0, count: w * h)
    let topClockSafeY = Int(Double(h) * 0.16)
    for y in topClockSafeY..<h {
        let rowOff = y * w
        for x in 0..<w {
            if isSky[rowOff + x] == 0 {
                maskBytes[rowOff + x] = 255
            }
        }
    }

    // Create CGImage from grayscale bytes and apply soft Gaussian feathering for clean edges
    let grayCS = CGColorSpaceCreateDeviceGray()
    let maskData = Data(maskBytes) as CFData
    guard let provider = CGDataProvider(data: maskData),
          let rawMask = CGImage(
              width: w,
              height: h,
              bitsPerComponent: 8,
              bitsPerPixel: 8,
              bytesPerRow: w,
              space: grayCS,
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
              provider: provider,
              decode: nil,
              shouldInterpolate: true,
              intent: .defaultIntent
          ) else {
        throw NSError(domain: "BuildWallpapers", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed creating skyline mask CGImage"])
    }

    let maskCI = CIImage(cgImage: rawMask)
        .clampedToExtent()
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.0])
        .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    let ciContext = CIContext(options: nil)
    guard let softMask = ciContext.createCGImage(maskCI, from: CGRect(x: 0, y: 0, width: w, height: h)) else {
        throw NSError(domain: "BuildWallpapers", code: 15, userInfo: [NSLocalizedDescriptionKey: "Failed softening skyline mask"])
    }

    let cutout = try compositeGrayscaleMaskCutout(source: fitted, grayscaleMask: softMask, outWidth: w, outHeight: h)
    let coverage = estimateOpaqueCoverage(cutout)
    return (cutout, coverage)
}

func compositeGrayscaleMaskCutout(
    source: CGImage,
    grayscaleMask: CGImage,
    outWidth: Int = 780,
    outHeight: Int = 1688
) throws -> CGImage {
    let fittedSource = try aspectFillCGImage(source, width: outWidth, height: outHeight)
    let ctx = try makeRGBContext(width: outWidth, height: outHeight)
    let rect = CGRect(x: 0, y: 0, width: outWidth, height: outHeight)
    ctx.clear(rect)
    ctx.clip(to: rect, mask: grayscaleMask)
    ctx.draw(fittedSource, in: rect)
    guard let outCG = ctx.makeImage() else {
        throw NSError(domain: "BuildWallpapers", code: 12, userInfo: [NSLocalizedDescriptionKey: "compositeGrayscaleMaskCutout makeImage failed"])
    }
    return outCG
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

    case "snowfall":
        let size = 64
        let ctx = try makeRGBContext(width: size, height: size)
        let cs = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 0.95),
                CGColor(red: 0.78, green: 0.90, blue: 1.0, alpha: 0.42),
                CGColor(red: 0.65, green: 0.85, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.45, 1.0]
        )!
        let c = CGPoint(x: 32, y: 32)
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 1, endCenter: c, endRadius: 26, options: [])
        let url = outDir.appendingPathComponent("particle_snow.png")
        try writePNG(ctx.makeImage()!, to: url)
        return [("particle_snow.png", size, size)]

    case "auroraRibbon", "sunbeamRays":
        let w = 256, h = 512
        let ctx = try makeRGBContext(width: w, height: h)
        let cs = CGColorSpaceCreateDeviceRGB()
        let tint: CGColor = (preset == "auroraRibbon")
            ? CGColor(red: 0.25, green: 0.95, blue: 0.82, alpha: 0.36)
            : CGColor(red: 1.0, green: 0.86, blue: 0.56, alpha: 0.34)
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
                CGColor(red: 0.78, green: 0.96, blue: 1.0, alpha: 0.92),
                CGColor(red: 0.45, green: 0.72, blue: 1.0, alpha: 0.45),
                CGColor(red: 0.25, green: 0.35, blue: 0.95, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.38, 1.0]
        )!
        let c = CGPoint(x: 32, y: 32)
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 1, endCenter: c, endRadius: 28, options: [])
        let url = outDir.appendingPathComponent("particle_firefly.png")
        try writePNG(ctx.makeImage()!, to: url)
        return [("particle_firefly.png", size, size)]

    default: // "none"
        return []
    }
}

// MARK: - Photorealistic Cinemagraph Loop Renderer (600x1300 @ 16 frames < 50MB RGBA8)

func renderMotionLoopFrames(pack: PackMetadata, width: Int, height: Int, assetsDir: URL) throws -> (frames: [String], heroThumbImage: CGImage) {
    let frameCount = pack.motion?.frameCount ?? 16
    let stateAURL = sourcesDir.appendingPathComponent("\(pack.id)_lock.jpg")
    let stateBURL = sourcesDir.appendingPathComponent("\(pack.id)_unlock.jpg")
    let rawA = try loadCGImage(at: stateAURL)
    let rawB = try loadCGImage(at: stateBURL)
    let cgA = try aspectFillCGImage(rawA, width: width, height: height)
    let cgB = try aspectFillCGImage(rawB, width: width, height: height)

    let extent = CGRect(x: 0, y: 0, width: width, height: height)
    let ciA = CIImage(cgImage: cgA)
    let ciB = CIImage(cgImage: cgB)
    let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var filenames: [String] = []
    for i in 0..<frameCount {
        let theta = 2.0 * Double.pi * Double(i) / Double(frameCount)
        let weightB = CGFloat(0.5 - 0.5 * cos(theta))
        let breathScale = CGFloat(1.008 + 0.008 * sin(theta))

        // Blend State A and State B with periodic cosine weighting + subtle highlight bloom
        let breathTransform = CGAffineTransform(translationX: extent.midX, y: extent.midY)
            .scaledBy(x: breathScale, y: breathScale)
            .translatedBy(x: -extent.midX, y: -extent.midY)
        let scaledA = ciA.clampedToExtent().transformed(by: breathTransform).cropped(to: extent)
        let scaledB = ciB.clampedToExtent().transformed(by: breathTransform).cropped(to: extent)

        let weightMask = CIImage(color: CIColor(red: weightB, green: weightB, blue: weightB, alpha: 1.0)).cropped(to: extent)
        let blended = scaledB.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: scaledA,
            kCIInputMaskImageKey: weightMask
        ]).cropped(to: extent)

        let softGlow = blended
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 14.0])
            .cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.06 * weightB)
            ])
        let finalCI = softGlow.applyingFilter("CIScreenBlendMode", parameters: [
            kCIInputBackgroundImageKey: blended
        ]).cropped(to: extent)

        guard let frameCG = ciContext.createCGImage(finalCI, from: extent) else {
            throw NSError(domain: "BuildWallpapers", code: 20, userInfo: [NSLocalizedDescriptionKey: "Failed rendering cinemagraph frame \(i) for \(pack.id)"])
        }
        let fname = String(format: "frame_%d.jpg", i)
        try writeJPEG(frameCG, to: assetsDir.appendingPathComponent(fname), quality: 0.86)
        filenames.append(fname)
    }

    let heroThumb = try aspectFillCGImage(rawB, width: 540, height: 1170)
    return (filenames, heroThumb)
}

func UnusedLegacyStubKeepNothing() {}

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
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.24, lockedVal: 1.18, unlockVal: 1.0, isInteger: false)
        ])
    case "holoCard":
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.rotation.y", sleepVal: -0.06, lockedVal: 0.0, unlockVal: 0.24, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "position.x", sleepVal: 195, lockedVal: 195, unlockVal: 215, isInteger: true),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.rotation.y", sleepVal: -0.24, lockedVal: -0.22, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "position.x", sleepVal: 175, lockedVal: 178, unlockVal: 195, isInteger: true),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.06, lockedVal: 1.05, unlockVal: 1.0, isInteger: false)
        ])
    case "aodGaze":
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 0.96, lockedVal: 1.0, unlockVal: 1.04, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false)
        ])
    case "crossfade":
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 1.04, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.06, lockedVal: 1.04, unlockVal: 1.0, isInteger: false)
        ])
    default: // flashAwaken
        overrides.append(contentsOf: [
            StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.06, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false)
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
            overrides.append(StateOverride(targetId: "camlo_volumetric_beam", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.48, unlockVal: 0.42, isInteger: false))
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
                birthRate = 7.5; velocity = 38; yAccel = 16; scale = 0.25; ePosY = 120; emLong = 1.57; emRange = 1.20; spin = 1.2
            case "sakura":
                birthRate = 4.5; velocity = 42; yAccel = -12; scale = 0.32; ePosY = 820; emLong = -1.57; emRange = 0.90; spin = 1.8
            case "snowfall":
                birthRate = 4.2; velocity = 26; yAccel = -8; scale = 0.24; ePosY = 820; emLong = -1.57; emRange = 0.70; spin = 0.4
            case "meteorShower":
                birthRate = 2.2; velocity = 260; yAccel = -36; scale = 0.38; ePosY = 740; emLong = -2.25; emRange = 0.22; spin = 0.0
            case "fireflies":
                birthRate = 4.5; velocity = 14; yAccel = 5; scale = 0.22; ePosY = 420; emLong = 1.57; emRange = 3.14; spin = 0.6
            default: // starlight
                birthRate = 5.0; velocity = 12; yAccel = 3; scale = 0.21; ePosY = 460; emLong = 1.57; emRange = 3.14; spin = 0.8
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
    let wallpaperBundleName = (pack.category == "duo" || pack.category == "anime")
        ? "7920.Camlo_3D-390w-844h@3x~iphone.wallpaper"
        : "7400.WWDC_2022-390w-844h@3x~iphone.wallpaper"
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

    let wallpaperPlist: [String: Any]
    if pack.category == "duo" || pack.category == "anime" {
        wallpaperPlist = [
            "appearanceAware": false,
            "contentVersion": 1.11,
            "family": "Marble",
            "identifier": pack.posterSeedId,
            "logicalScreenClass": "any",
            "name": "Lavender",
            "requiresLandscapeScaling": pack.category == "duo",
            "version": pack.category == "duo" ? 7 : 6,
            "wantsDeviceMotion": true,
            "assets": [
                "lockAndHome": [
                    "default": [
                        "assetFileName": "wallpaper.ca",
                        "identifier": 7920,
                        "name": "Lavender",
                        "type": "ParameterizedCA"
                    ]
                ]
            ]
        ]
    } else {
        wallpaperPlist = [
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
    }
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
    proc.standardInput = FileHandle.nullDevice
    let pipe = Pipe()
    proc.standardError = pipe
    try proc.run()
    let errData = pipe.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    if proc.terminationStatus != 0 {
        let errText = String(data: errData, encoding: .utf8) ?? "ditto failed"
        throw NSError(domain: "BuildWallpapers", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errText])
    }
}

// MARK: - iPhone Duo Dual-Screen ParameterizedCA Builder

private struct DuoOverride {
    let targetId: String
    let layerName: String
    let keyPath: String
    let sleepVal: Double
    let lockedVal: Double
    let unlockVal: Double
    let isInteger: Bool
}

private struct DuoCanvasSpec {
    let w: Int
    let h: Int
    let pixelW: Int
    let pixelH: Int
    let cutoutW: Int
    let cutoutH: Int
    let videoW: Int
    let videoH: Int
    let assetPrefix: String
    let idPrefix: String
    let namePrefix: String
    let bgParallaxName: String
    let bgOverscanName: String
    let fgParallaxName: String
    let fgOverscanName: String
    let fxParallaxName: String

    var cx: Int { w / 2 }
    var cy: Int { h / 2 }
    var sx: Double { Double(w) / 390.0 }
    var sy: Double { Double(h) / 844.0 }

    static let phone = DuoCanvasSpec(
        w: 390, h: 844, pixelW: 1170, pixelH: 2532,
        cutoutW: 780, cutoutH: 1688, videoW: 600, videoH: 1300,
        assetPrefix: "", idPrefix: "", namePrefix: "",
        bgParallaxName: "Camlo_BG_Parallax", bgOverscanName: "Camlo_BG_Overscan",
        fgParallaxName: "Camlo_FG_Parallax", fgOverscanName: "Camlo_FG_Overscan",
        fxParallaxName: "Camlo_FX_Parallax"
    )
    static let outer = DuoCanvasSpec(
        w: 466, h: 678, pixelW: 1164, pixelH: 1696,
        cutoutW: 776, cutoutH: 1130, videoW: 520, videoH: 758,
        assetPrefix: "", idPrefix: "", namePrefix: "",
        bgParallaxName: "Camlo_BG_Parallax", bgOverscanName: "Camlo_BG_Overscan",
        fgParallaxName: "Camlo_FG_Parallax", fgOverscanName: "Camlo_FG_Overscan",
        fxParallaxName: "Camlo_FX_Parallax"
    )
    static let inner = DuoCanvasSpec(
        w: 951, h: 669, pixelW: 1902, pixelH: 1338,
        cutoutW: 1268, cutoutH: 892, videoW: 860, videoH: 604,
        assetPrefix: "inner_", idPrefix: "inner_", namePrefix: "Inner ",
        bgParallaxName: "Camlo_Inner_BG_Parallax", bgOverscanName: "Camlo_Inner_BG_Overscan",
        fgParallaxName: "Camlo_Inner_FG_Parallax", fgOverscanName: "Camlo_Inner_FG_Overscan",
        fxParallaxName: "Camlo_Inner_FX_Parallax"
    )
}

private func duoParallaxXML(
    axis: String, keyPath: String, layerName: String,
    minVal: Int, maxVal: Int, title: String, view: String
) -> String {
    """
            <NSDictionary>
              <axis type="string" value="\(axis)"/>
              <image type="string" value="null"/>
              <keyPath type="string" value="\(keyPath)"/>
              <layerName type="string" value="\(layerName)"/>
              <mapMaxTo type="integer" value="\(maxVal)"/>
              <mapMinTo type="integer" value="\(minVal)"/>
              <title type="string" value="\(title)"/>
              <view type="string" value="\(view)"/>
            </NSDictionary>
    """
}

private func duoPropXML(
    keyPath: String, layerName: String,
    sleepVal: Double, lockVal: Double, homeVal: Double, view: String
) -> String {
    """
            <NSDictionary>
              <image type="null"/>
              <keyPath type="string" value="\(keyPath)"/>
              <layerName type="string" value="\(layerName)"/>
              <v_home type="real" value="\(String(format: "%.4f", homeVal))"/>
              <v_lock type="real" value="\(String(format: "%.4f", lockVal))"/>
              <v_sleep type="real" value="\(String(format: "%.4f", sleepVal))"/>
              <view type="string" value="\(view)"/>
            </NSDictionary>
    """
}

private func duoPropEntries(for ov: DuoOverride, view: String) -> [String] {
    if ov.keyPath == "transform.scale.xy" {
        let s = max(0.0, ov.sleepVal), l = max(0.0, ov.lockedVal), h = max(0.0, ov.unlockVal)
        return [
            duoPropXML(keyPath: "transform.scale.x", layerName: ov.layerName, sleepVal: s, lockVal: l, homeVal: h, view: view),
            duoPropXML(keyPath: "transform.scale.y", layerName: ov.layerName, sleepVal: s, lockVal: l, homeVal: h, view: view)
        ]
    }
    return [duoPropXML(keyPath: ov.keyPath, layerName: ov.layerName, sleepVal: ov.sleepVal, lockVal: ov.lockedVal, homeVal: ov.unlockVal, view: view)]
}

private func extractMorphCutoutPair(
    lockFit: CGImage,
    unlockFit: CGImage,
    cutoutW: Int,
    cutoutH: Int,
    maskMode: String
) -> (CGImage, CGImage, Double, Double, String)? {
    if maskMode == "skyline" {
        if let (cl, covL) = try? extractSkylineCutout(from: lockFit, outWidth: cutoutW, outHeight: cutoutH),
           let (cu, covU) = try? extractSkylineCutout(from: unlockFit, outWidth: cutoutW, outHeight: cutoutH),
           covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
            return (cl, cu, covL, covU, "Skyline")
        }
        if let (cl, covL) = try? extractForegroundCutout(from: lockFit, outWidth: cutoutW, outHeight: cutoutH),
           let (cu, covU) = try? extractForegroundCutout(from: unlockFit, outWidth: cutoutW, outHeight: cutoutH),
           covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
            return (cl, cu, covL, covU, "Vision-Fallback")
        }
    } else {
        if let (cl, covL) = try? extractForegroundCutout(from: lockFit, outWidth: cutoutW, outHeight: cutoutH),
           let (cu, covU) = try? extractForegroundCutout(from: unlockFit, outWidth: cutoutW, outHeight: cutoutH),
           covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
            return (cl, cu, covL, covU, "Vision")
        }
        if let (cl, covL) = try? extractSkylineCutout(from: lockFit, outWidth: cutoutW, outHeight: cutoutH),
           let (cu, covU) = try? extractSkylineCutout(from: unlockFit, outWidth: cutoutW, outHeight: cutoutH),
           covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
            return (cl, cu, covL, covU, "Skyline-Fallback")
        }
    }
    return nil
}

private func duoBuildMorphSurface(
    canvas: DuoCanvasSpec,
    lockRaw: CGImage,
    unlockRaw: CGImage,
    transitionPreset: String,
    supportsCutout: Bool,
    maskMode: String,
    assetsDir: URL,
    packId: String,
    jpegQuality: CGFloat = 0.84,
    requireCutout: Bool = false
) throws -> (bgXML: String, bgOvs: [DuoOverride], fgXML: String, fgOvs: [DuoOverride]) {
    let lockFit = try aspectFillCGImage(lockRaw, width: canvas.pixelW, height: canvas.pixelH)
    let unlockFit = try aspectFillCGImage(unlockRaw, width: canvas.pixelW, height: canvas.pixelH)
    let aP = canvas.assetPrefix
    let idP = canvas.idPrefix
    let nP = canvas.namePrefix

    try writeJPEG(lockFit, to: assetsDir.appendingPathComponent("\(aP)locked.jpg"), quality: jpegQuality)
    try writeJPEG(unlockFit, to: assetsDir.appendingPathComponent("\(aP)unlock.jpg"), quality: jpegQuality)

    let uId = "\(idP)unlock_layer", uName = "\(nP)Unlock Layer"
    let lId = "\(idP)locked_layer", lName = "\(nP)Locked Layer"
    let dId = "\(idP)sleep_dimmer", dName = "\(nP)Sleep Dimmer"
    let sleepAlpha = (transitionPreset == "aodGaze") ? 0.78 : 0.48

    let bgXML = """
                  <CALayer id="\(uId)" name="\(uName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents><CGImage src="assets/\(aP)unlock.jpg"/></contents>
                  </CALayer>
                  <CALayer id="\(lId)" name="\(lName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents><CGImage src="assets/\(aP)locked.jpg"/></contents>
                  </CALayer>
                  <CALayer id="\(dId)" name="\(dName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
    """

    let cy = Double(canvas.cy), cx = Double(canvas.cx)
    let lockExitY = (Double(canvas.h) * 1.1137).rounded()
    let uSleepY = (cy - 30.0 * canvas.sy).rounded()
    let uLockY = (cy - 18.0 * canvas.sy).rounded()
    var bgOvs: [DuoOverride] = [
        DuoOverride(targetId: dId, layerName: dName, keyPath: "opacity", sleepVal: sleepAlpha, lockedVal: 0.0, unlockVal: 0.0, isInteger: false)
    ]

    switch transitionPreset {
    case "curtainRise":
        bgOvs.append(contentsOf: [
            DuoOverride(targetId: lId, layerName: lName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            DuoOverride(targetId: lId, layerName: lName, keyPath: "position.y", sleepVal: cy, lockedVal: cy, unlockVal: lockExitY, isInteger: true),
            DuoOverride(targetId: lId, layerName: lName, keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 0.96, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "position.y", sleepVal: uSleepY, lockedVal: uLockY, unlockVal: cy, isInteger: true),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false)
        ])
    case "burstZoom":
        bgOvs.append(contentsOf: [
            DuoOverride(targetId: lId, layerName: lName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            DuoOverride(targetId: lId, layerName: lName, keyPath: "transform.scale.xy", sleepVal: 1.04, lockedVal: 1.0, unlockVal: 0.86, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "transform.scale.xy", sleepVal: 1.24, lockedVal: 1.18, unlockVal: 1.0, isInteger: false)
        ])
    case "aodGaze":
        bgOvs.append(contentsOf: [
            DuoOverride(targetId: lId, layerName: lName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            DuoOverride(targetId: lId, layerName: lName, keyPath: "transform.scale.xy", sleepVal: 0.96, lockedVal: 1.0, unlockVal: 1.04, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false)
        ])
    case "crossfade":
        bgOvs.append(contentsOf: [
            DuoOverride(targetId: lId, layerName: lName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            DuoOverride(targetId: lId, layerName: lName, keyPath: "transform.scale.xy", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 1.04, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "transform.scale.xy", sleepVal: 1.06, lockedVal: 1.04, unlockVal: 1.0, isInteger: false)
        ])
    default: // flashAwaken
        bgOvs.append(contentsOf: [
            DuoOverride(targetId: lId, layerName: lName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
            DuoOverride(targetId: lId, layerName: lName, keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.06, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
            DuoOverride(targetId: uId, layerName: uName, keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false)
        ])
    }
    _ = cx

    var fgXML = ""
    var fgOvs: [DuoOverride] = []
    if supportsCutout && maskMode != "none" {
        let cutPair = extractMorphCutoutPair(
            lockFit: lockFit,
            unlockFit: unlockFit,
            cutoutW: canvas.cutoutW,
            cutoutH: canvas.cutoutH,
            maskMode: maskMode
        )
        if let (cutL, cutU, covL, covU, tag) = cutPair {
            try writePNG(cutL, to: assetsDir.appendingPathComponent("\(aP)cutout_lock.png"))
            try writePNG(cutU, to: assetsDir.appendingPathComponent("\(aP)cutout_unlock.png"))
            let fuId = "\(idP)float_unlock", fuName = "\(nP)Floating Unlock Subject"
            let flId = "\(idP)float_lock", flName = "\(nP)Floating Lock Subject"
            let flExitY: Double = (transitionPreset == "curtainRise") ? (Double(canvas.h) * 1.137).rounded() : cy
            let flEndScale: Double = (transitionPreset == "burstZoom") ? 0.84 : 1.06
            fgXML = """
                  <CALayer id="\(fuId)" name="\(fuName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="1" opacity="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents><CGImage src="assets/\(aP)cutout_unlock.png"/></contents>
                  </CALayer>
                  <CALayer id="\(flId)" name="\(flName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="2" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents><CGImage src="assets/\(aP)cutout_lock.png"/></contents>
                  </CALayer>
            """
            fgOvs = [
                DuoOverride(targetId: fuId, layerName: fuName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                DuoOverride(targetId: fuId, layerName: fuName, keyPath: "transform.scale.xy", sleepVal: 1.16, lockedVal: 1.14, unlockVal: 1.0, isInteger: false),
                DuoOverride(targetId: flId, layerName: flName, keyPath: "opacity", sleepVal: 0.72, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                DuoOverride(targetId: flId, layerName: flName, keyPath: "position.y", sleepVal: cy, lockedVal: cy, unlockVal: flExitY, isInteger: true),
                DuoOverride(targetId: flId, layerName: flName, keyPath: "transform.scale.xy", sleepVal: 0.98, lockedVal: 1.0, unlockVal: flEndScale, isInteger: false)
            ]
            print(String(format: "    [%@-%@] %@ cutout cov=%.1f%%/%.1f%%", tag, canvas.idPrefix.isEmpty ? (canvas.w == 390 ? "phone" : "outer") : "inner", packId, covL * 100.0, covU * 100.0))
        } else if requireCutout {
            throw NSError(domain: "BuildWallpapers", code: 44, userInfo: [NSLocalizedDescriptionKey: "Failed required Clock-Depth foreground cutout extraction for \(packId)"])
        }
    } else if requireCutout {
        throw NSError(domain: "BuildWallpapers", code: 45, userInfo: [NSLocalizedDescriptionKey: "Anime pack \(packId) requires supportsClockDepth=true and maskMode != none"])
    }

    return (bgXML, bgOvs, fgXML, fgOvs)
}

private func duoBuildMotionSurface(
    canvas: DuoCanvasSpec,
    rawA: CGImage,
    rawB: CGImage,
    frameCount: Int,
    duration: Double,
    assetsDir: URL,
    packId: String
) throws -> (bgXML: String, bgOvs: [DuoOverride]) {
    let fittedA = try aspectFillCGImage(rawA, width: canvas.videoW, height: canvas.videoH)
    let fittedB = try aspectFillCGImage(rawB, width: canvas.videoW, height: canvas.videoH)
    let ciA = CIImage(cgImage: fittedA)
    let ciB = CIImage(cgImage: fittedB)
    let extent = CGRect(x: 0, y: 0, width: canvas.videoW, height: canvas.videoH)
    let ciCtx = CIContext(options: nil)
    let aP = canvas.assetPrefix
    let idP = canvas.idPrefix
    let nP = canvas.namePrefix

    var tags: [String] = []
    for i in 0..<frameCount {
        let phase = Double(i) / Double(max(1, frameCount - 1))
        let weightB = CGFloat(0.5 - 0.5 * cos(phase * .pi))
        let scaleAmt = 1.0 + 0.016 * sin(phase * .pi)
        let panY = CGFloat(4.0 * sin(phase * .pi))
        let cx = CGFloat(canvas.videoW) * 0.5
        let cy = CGFloat(canvas.videoH) * 0.5
        let tr = CGAffineTransform(translationX: cx, y: cy)
            .scaledBy(x: scaleAmt, y: scaleAmt)
            .translatedBy(x: -cx, y: -cy + panY)
        let sA = ciA.clampedToExtent().transformed(by: tr).cropped(to: extent)
        let sB = ciB.clampedToExtent().transformed(by: tr).cropped(to: extent)
        let wMask = CIImage(color: CIColor(red: weightB, green: weightB, blue: weightB, alpha: 1.0)).cropped(to: extent)
        let blended = sB.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: sA, kCIInputMaskImageKey: wMask]).cropped(to: extent)
        guard let cg = ciCtx.createCGImage(blended, from: extent) else {
            throw NSError(domain: "BuildWallpapers", code: 22, userInfo: [NSLocalizedDescriptionKey: "Failed Duo motion frame \(i) for \(packId)"])
        }
        let fname = "\(aP)frame_\(i).jpg"
        try writeJPEG(cg, to: assetsDir.appendingPathComponent(fname), quality: 0.80)
        tags.append("                    <CGImage src=\"assets/\(fname)\"/>")
    }

    let vidId = "\(idP)video_seq_layer", vidName = "\(nP)Video Sequence Layer"
    let dimId = "\(idP)video_sleep_dim", dimName = "\(nP)Sleep Dimmer"
    let bgXML = """
                  <CALayer id="\(vidId)" name="\(vidName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents><CGImage src="assets/\(aP)frame_0.jpg"/></contents>
                    <animations>
                      <animation type="CAKeyframeAnimation" calculationMode="discrete" fillMode="both" keyPath="contents" beginTime="1e-100" duration="\(String(format: "%.3f", max(0.5, duration)))" removedOnCompletion="0" repeatCount="inf" repeatDuration="0" speed="1" timeOffset="0" autoreverses="1">
                        <values>
    \(tags.joined(separator: "\n"))
                        </values>
                      </animation>
                    </animations>
                  </CALayer>
                  <CALayer id="\(dimId)" name="\(dimName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
    """
    let bgOvs = [
        DuoOverride(targetId: vidId, layerName: vidName, keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.04, isInteger: false),
        DuoOverride(targetId: dimId, layerName: dimName, keyPath: "opacity", sleepVal: 0.65, lockedVal: 0.0, unlockVal: 0.0, isInteger: false)
    ]
    return (bgXML, bgOvs)
}

private func duoFXLayers(preset: String, spriteName: String?, canvas: DuoCanvasSpec) -> (xml: String, ovs: [DuoOverride]) {
    guard preset != "none", let spriteName, !spriteName.isEmpty else { return ("", []) }
    let idP = canvas.idPrefix
    let nP = canvas.namePrefix
    let eId = "\(idP)camlo_emitter", eName = "\(nP)Camlo Emitter"
    let ePosX = Int((195.0 * canvas.sx).rounded())
    let eW = Int((390.0 * canvas.sx).rounded())
    let eH = Int((260.0 * canvas.sy).rounded())
    let ePosY: Int
    let birthRate: Double, velocity: Double, yAccel: Double, scale: Double, emLong: Double, emRange: Double, spin: Double
    switch preset {
    case "sakura":
        birthRate = 4.5; velocity = 42; yAccel = -12; scale = 0.32; ePosY = Int((820.0 * canvas.sy).rounded()); emLong = -1.57; emRange = 0.90; spin = 1.8
    case "embers":
        birthRate = 7.5; velocity = 38; yAccel = 16; scale = 0.25; ePosY = Int((120.0 * canvas.sy).rounded()); emLong = 1.57; emRange = 1.20; spin = 1.2
    case "snowfall":
        birthRate = 4.2; velocity = 26; yAccel = -8; scale = 0.24; ePosY = Int((820.0 * canvas.sy).rounded()); emLong = -1.57; emRange = 0.70; spin = 0.4
    case "meteorShower":
        birthRate = 2.2; velocity = 260; yAccel = -36; scale = 0.38; ePosY = Int((740.0 * canvas.sy).rounded()); emLong = -2.25; emRange = 0.22; spin = 0.0
    case "fireflies":
        birthRate = 4.5; velocity = 14; yAccel = 5; scale = 0.22; ePosY = Int((420.0 * canvas.sy).rounded()); emLong = 1.57; emRange = 3.14; spin = 0.6
    case "sunbeamRays":
        let bId = "\(idP)camlo_volumetric_beam", bName = "\(nP)Camlo Volumetric Beam"
        let bw = Int((520.0 * canvas.sx).rounded()), bh = Int((960.0 * canvas.sy).rounded())
        let bx = Int((175.0 * canvas.sx).rounded()), by = Int((460.0 * canvas.sy).rounded())
        let xml = """
                  <CALayer id="\(bId)" name="\(bName)" bounds="0 0 \(bw) \(bh)" position="\(bx) \(by)" zPosition="3" opacity="0.46" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents><CGImage src="assets/\(spriteName)"/></contents>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                  </CALayer>
        """
        return (xml, [
            DuoOverride(targetId: bId, layerName: bName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.46, unlockVal: 0.38, isInteger: false)
        ])
    default: // starlight
        birthRate = 5.0; velocity = 12; yAccel = 3; scale = 0.21; ePosY = Int((460.0 * canvas.sy).rounded()); emLong = 1.57; emRange = 3.14; spin = 0.8
    }
    let xml = """
              <CAEmitterLayer id="\(eId)" name="\(eName)" bounds="0 0 \(canvas.w) \(canvas.h)" position="\(canvas.cx) \(canvas.cy)" zPosition="4" emitterPosition="\(ePosX) \(ePosY)" emitterSize="\(eW) \(eH)" emitterShape="rectangle" emitterMode="volume" renderMode="additive" birthRate="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <emitterCells>
                  <CAEmitterCell id="\(idP)camlo_cell_main" name="\(idP)camlo_cell_main" contentsScale="2" birthRate="\(birthRate)" lifetime="6.2" velocity="\(velocity)" velocityRange="24" emissionRange="\(emRange)" emissionLongitude="\(emLong)" emissionLatitude="0" scale="\(scale)" scaleRange="0.14" scaleSpeed="-0.01" alphaRange="0.25" alphaSpeed="-0.12" spin="\(spin)" spinRange="1.2" yAcceleration="\(yAccel)">
                    <color value="1 1 1" opacity="0.94"/>
                    <contents><CGImage src="assets/\(spriteName)"/></contents>
                  </CAEmitterCell>
                </emitterCells>
              </CAEmitterLayer>
    """
    return (xml, [
        DuoOverride(targetId: eId, layerName: eName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 0.88, isInteger: false),
        DuoOverride(targetId: eId, layerName: eName, keyPath: "birthRate", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false)
    ])
}

func buildDuoDualPack(pack: PackMetadata, wpDir: URL, thumbOutURL: URL) throws {
    let fm = FileManager.default
    let caURL = wpDir.appendingPathComponent("wallpaper.ca", isDirectory: true)
    let assetsDir = caURL.appendingPathComponent("assets", isDirectory: true)
    try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
    let outer = DuoCanvasSpec.outer
    let inner = DuoCanvasSpec.inner
    try standardIndexXML(width: outer.w, height: outer.h).write(to: caURL.appendingPathComponent("index.xml"), atomically: true, encoding: .utf8)
    try standardAssetManifestXML().write(to: caURL.appendingPathComponent("assetManifest.caml"), atomically: true, encoding: .utf8)

    let outerLockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_lock.jpg"))
    let outerUnlockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_unlock.jpg"))
    let innerLockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_inner_lock.jpg"))
    let innerUnlockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_inner_unlock.jpg"))

    let thumbCG = try aspectFillCGImage(outerUnlockRaw, width: 540, height: 1170)
    try writeJPEG(thumbCG, to: thumbOutURL, quality: 0.88)

    let fgSprites = try renderParticleSprite(pack.particlePreset, outDir: assetsDir)
    let spriteName = fgSprites.first?.filename
    let outerFX = duoFXLayers(preset: pack.particlePreset, spriteName: spriteName, canvas: outer)
    let innerFX = duoFXLayers(preset: pack.particlePreset, spriteName: spriteName, canvas: inner)

    let oBgXML: String, iBgXML: String, oFgXML: String, iFgXML: String
    let oBgOvs: [DuoOverride], iBgOvs: [DuoOverride]
    let oFgOvs: [DuoOverride], iFgOvs: [DuoOverride]

    if pack.kind == "duoMotion" {
        let count = max(12, pack.motion?.frameCount ?? 16)
        let dur = max(1.0, pack.motion?.duration ?? 2.667)
        let oMot = try duoBuildMotionSurface(canvas: outer, rawA: outerLockRaw, rawB: outerUnlockRaw, frameCount: count, duration: dur, assetsDir: assetsDir, packId: pack.id)
        let iMot = try duoBuildMotionSurface(canvas: inner, rawA: innerLockRaw, rawB: innerUnlockRaw, frameCount: count, duration: dur, assetsDir: assetsDir, packId: pack.id)
        oBgXML = oMot.bgXML; oBgOvs = oMot.bgOvs; oFgXML = ""; oFgOvs = []
        iBgXML = iMot.bgXML; iBgOvs = iMot.bgOvs; iFgXML = ""; iFgOvs = []
    } else {
        let mode = (pack.depthMaskMode ?? (pack.supportsClockDepth ? "vision" : "none")).lowercased()
        let oM = try duoBuildMorphSurface(canvas: outer, lockRaw: outerLockRaw, unlockRaw: outerUnlockRaw, transitionPreset: pack.transitionPreset, supportsCutout: pack.supportsClockDepth, maskMode: mode, assetsDir: assetsDir, packId: pack.id)
        let iM = try duoBuildMorphSurface(canvas: inner, lockRaw: innerLockRaw, unlockRaw: innerUnlockRaw, transitionPreset: pack.transitionPreset, supportsCutout: pack.supportsClockDepth, maskMode: mode, assetsDir: assetsDir, packId: pack.id)
        oBgXML = oM.bgXML; oBgOvs = oM.bgOvs; oFgXML = oM.fgXML; oFgOvs = oM.fgOvs
        iBgXML = iM.bgXML; iBgOvs = iM.bgOvs; iFgXML = iM.fgXML; iFgOvs = iM.fgOvs
    }

    func parallaxFor(_ c: DuoCanvasSpec) -> (bg: [String], fg: [String]) {
        let bx = Int((16.0 * c.sx).rounded()), by = Int((22.0 * c.sy).rounded())
        let fx = Int((22.0 * c.sx).rounded()), fy = Int((28.0 * c.sy).rounded())
        let xx = Int((30.0 * c.sx).rounded()), xy = Int((36.0 * c.sy).rounded())
        return (
            [
                duoParallaxXML(axis: "x", keyPath: "transform.translation.x", layerName: c.bgParallaxName, minVal: -bx, maxVal: bx, title: "\(c.namePrefix)Camlo BG X", view: "Background"),
                duoParallaxXML(axis: "y", keyPath: "transform.translation.y", layerName: c.bgParallaxName, minVal: -by, maxVal: by, title: "\(c.namePrefix)Camlo BG Y", view: "Background")
            ],
            [
                duoParallaxXML(axis: "x", keyPath: "transform.translation.x", layerName: c.fgParallaxName, minVal: fx, maxVal: -fx, title: "\(c.namePrefix)Camlo FG X", view: "Floating"),
                duoParallaxXML(axis: "y", keyPath: "transform.translation.y", layerName: c.fgParallaxName, minVal: fy, maxVal: -fy, title: "\(c.namePrefix)Camlo FG Y", view: "Floating"),
                duoParallaxXML(axis: "x", keyPath: "transform.translation.x", layerName: c.fxParallaxName, minVal: xx, maxVal: -xx, title: "\(c.namePrefix)Camlo FX X", view: "Floating"),
                duoParallaxXML(axis: "y", keyPath: "transform.translation.y", layerName: c.fxParallaxName, minVal: xy, maxVal: -xy, title: "\(c.namePrefix)Camlo FX Y", view: "Floating")
            ]
        )
    }

    let oPx = parallaxFor(outer)
    let iPx = parallaxFor(inner)
    let oBgProps = oBgOvs.flatMap { duoPropEntries(for: $0, view: "Background") }
    let oFgProps = (oFgOvs + outerFX.ovs).flatMap { duoPropEntries(for: $0, view: "Floating") }
    let iBgProps = iBgOvs.flatMap { duoPropEntries(for: $0, view: "Background") }
    let iFgProps = (iFgOvs + innerFX.ovs).flatMap { duoPropEntries(for: $0, view: "Floating") }

    func variantDict(screen: String, bgName: String, flName: String, c: DuoCanvasSpec, px: (bg: [String], fg: [String]), bp: [String], fp: [String]) -> String {
        let bpXML = bp.isEmpty ? "          <backgroundPropertyGroups type=\"NSArray\"/>" : "          <backgroundPropertyGroups type=\"NSArray\">\n\(bp.joined(separator: "\n"))\n          </backgroundPropertyGroups>"
        let fpXML = fp.isEmpty ? "          <floatingPropertyGroups type=\"NSArray\"/>" : "          <floatingPropertyGroups type=\"NSArray\">\n\(fp.joined(separator: "\n"))\n          </floatingPropertyGroups>"
        return """
                <NSDictionary>
                  <screenName type="string" value="\(screen)"/>
                  <backgroundLayerName type="string" value="\(bgName)"/>
                  <floatingLayerName type="string" value="\(flName)"/>
                  <idealWidth type="integer" value="\(c.w)"/>
                  <idealHeight type="integer" value="\(c.h)"/>
                  <retinaMultiplier type="integer" value="3"/>
                  <backgroundParallaxGroups type="NSArray">
        \(px.bg.joined(separator: "\n"))
                  </backgroundParallaxGroups>
                  <floatingParallaxGroups type="NSArray">
        \(px.fg.joined(separator: "\n"))
                  </floatingParallaxGroups>
        \(bpXML)
        \(fpXML)
                </NSDictionary>
        """
    }

    func planePair(c: DuoCanvasSpec, bgId: String, bgN: String, flId: String, flN: String, bgZ: Int, flZ: Int, bgXML: String, flXML: String, fxXML: String) -> String {
        let bIn = bgXML.isEmpty ? "" : "\n                <sublayers>\n\(bgXML)\n                </sublayers>"
        let fIn = flXML.isEmpty ? "" : "\n                <sublayers>\n\(flXML)\n                </sublayers>"
        let xIn = fxXML.isEmpty ? "" : "\n              <sublayers>\n\(fxXML)\n              </sublayers>"
        return """
              <CALayer id="\(bgId)" name="\(bgN)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="\(bgZ)" geometryFlipped="0" masksToBounds="1" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="\(c.idPrefix)camlo_bg_parallax" name="\(c.bgParallaxName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <sublayers>
                      <CALayer id="\(c.idPrefix)camlo_bg_overscan" name="\(c.bgOverscanName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" opacity="1" transform="scale(1.1040, 1.1040, 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(bIn)
                      </CALayer>
                    </sublayers>
                  </CALayer>
                </sublayers>
              </CALayer>
              <CALayer id="\(flId)" name="\(flN)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="\(flZ)" geometryFlipped="0" masksToBounds="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="\(c.idPrefix)camlo_fg_parallax" name="\(c.fgParallaxName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="10" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <sublayers>
                      <CALayer id="\(c.idPrefix)camlo_fg_overscan" name="\(c.fgOverscanName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" opacity="1" transform="scale(1.0400, 1.0400, 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(fIn)
                      </CALayer>
                    </sublayers>
                  </CALayer>
                  <CALayer id="\(c.idPrefix)camlo_fx_parallax" name="\(c.fxParallaxName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="20" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(xIn)
                  </CALayer>
                </sublayers>
              </CALayer>
        """
    }

    let allOvs = oBgOvs + oFgOvs + outerFX.ovs + iBgOvs + iFgOvs + innerFX.ovs
    func stElements(_ stage: String) -> String {
        guard !allOvs.isEmpty else { return "        <elements/>" }
        var lns = ["        <elements>"]
        for ov in allOvs {
            let v = (stage == "Unlock") ? ov.unlockVal : (stage == "Sleep" ? ov.sleepVal : ov.lockedVal)
            let tStr = ov.isInteger ? "integer" : "real"
            let vStr = ov.isInteger ? String(Int(v.rounded())) : String(format: "%.4f", v)
            lns.append("          <LKStateSetValue targetId=\"\(ov.targetId)\" keyPath=\"\(ov.keyPath)\"><value type=\"\(tStr)\" value=\"\(vStr)\"/></LKStateSetValue>")
        }
        lns.append("        </elements>")
        return lns.joined(separator: "\n")
    }
    var trLines = ["        <elements>"]
    for ov in allOvs {
        trLines.append("          <LKStateTransitionElement targetId=\"\(ov.targetId)\" key=\"\(ov.keyPath)\"><animation type=\"CASpringAnimation\" damping=\"28\" mass=\"1\" stiffness=\"306\" velocity=\"0\" duration=\"0.85\" fillMode=\"backwards\" keyPath=\"\(ov.keyPath)\" mica_autorecalculatesDuration=\"1\"/></LKStateTransitionElement>")
    }
    trLines.append("        </elements>")
    let trEls = trLines.joined(separator: "\n")

    let wallpapersXML = [
        variantDict(screen: "Outer", bgName: "BACKGROUND", flName: "FLOATING", c: outer, px: oPx, bp: oBgProps, fp: oFgProps),
        variantDict(screen: "Inner", bgName: "BACKGROUND_INNER", flName: "FLOATING_INNER", c: inner, px: iPx, bp: iBgProps, fp: iFgProps)
    ].joined(separator: "\n")

    let allTopProps = oBgProps + oFgProps
    let topPropsXML = allTopProps.isEmpty ? "      <wallpaperPropertyGroups type=\"NSArray\"/>" : "      <wallpaperPropertyGroups type=\"NSArray\">\n\(allTopProps.joined(separator: "\n"))\n      </wallpaperPropertyGroups>"

    let caml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- Generated by Camlo Cloud Builder (iPhone Duo Dual-Screen) -->
    <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
      <CALayer id="__capRootLayer__" name="Root Layer" bounds="0 0 \(outer.w) \(outer.h)" position="\(outer.cx) \(outer.cy)" zPosition="0" geometryFlipped="0" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
        <style>
          <wallpaperBackgroundAssetNames type="NSArray"/>
          <wallpaperFloatingAssetNames type="NSArray"/>
          <wallpaperParallaxGroups type="NSArray">
    \((oPx.bg + oPx.fg).joined(separator: "\n"))
          </wallpaperParallaxGroups>
    \(topPropsXML)
          <wallpapers type="NSArray">
    \(wallpapersXML)
          </wallpapers>
        </style>
        <sublayers>
    \(planePair(c: inner, bgId: "background_inner", bgN: "BACKGROUND_INNER", flId: "floating_inner", flN: "FLOATING_INNER", bgZ: -10, flZ: -9, bgXML: iBgXML, flXML: iFgXML, fxXML: innerFX.xml))
    \(planePair(c: outer, bgId: "background", bgN: "BACKGROUND", flId: "floating", flN: "FLOATING", bgZ: 0, flZ: 10, bgXML: oBgXML, flXML: oFgXML, fxXML: outerFX.xml))
        </sublayers>
        <modules/>
        <states>
          <LKState name="Locked">
    \(stElements("Locked"))
          </LKState>
          <LKState name="Unlock">
    \(stElements("Unlock"))
          </LKState>
          <LKState name="Sleep">
    \(stElements("Sleep"))
          </LKState>
        </states>
        <stateTransitions>
          <LKStateTransition fromState="*" toState="Unlock">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="Unlock" toState="*">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="*" toState="Locked">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="Locked" toState="*">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="*" toState="Sleep">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="Sleep" toState="*">\(trEls)</LKStateTransition>
        </stateTransitions>
      </CALayer>
    </caml>
    """

    try caml.write(to: caURL.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)
    try verifyCAPackage(at: caURL)
}

func buildAnime3DMorphPack(pack: PackMetadata, wpDir: URL, thumbOutURL: URL) throws {
    let fm = FileManager.default
    let c = DuoCanvasSpec.phone
    let caURL = wpDir.appendingPathComponent("wallpaper.ca", isDirectory: true)
    let assetsDir = caURL.appendingPathComponent("assets", isDirectory: true)
    try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
    try standardIndexXML(width: c.w, height: c.h).write(to: caURL.appendingPathComponent("index.xml"), atomically: true, encoding: .utf8)
    try standardAssetManifestXML().write(to: caURL.appendingPathComponent("assetManifest.caml"), atomically: true, encoding: .utf8)

    let lockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_lock.jpg"))
    let unlockRaw = try loadCGImage(at: sourcesDir.appendingPathComponent("\(pack.id)_unlock.jpg"))
    let thumbCG = try aspectFillCGImage(unlockRaw, width: 540, height: 1170)
    try writeJPEG(thumbCG, to: thumbOutURL, quality: 0.88)

    let fgSprites = try renderParticleSprite(pack.particlePreset, outDir: assetsDir)
    let spriteName = fgSprites.first?.filename
    let fxBuilt = duoFXLayers(preset: pack.particlePreset, spriteName: spriteName, canvas: c)
    let maskMode = (pack.depthMaskMode ?? "vision").lowercased()
    let morph = try duoBuildMorphSurface(
        canvas: c,
        lockRaw: lockRaw,
        unlockRaw: unlockRaw,
        transitionPreset: pack.transitionPreset,
        supportsCutout: pack.supportsClockDepth,
        maskMode: maskMode,
        assetsDir: assetsDir,
        packId: pack.id,
        jpegQuality: 0.86,
        requireCutout: true
    )

    let parallaxXML = [
        duoParallaxXML(axis: "x", keyPath: "transform.translation.x", layerName: c.bgParallaxName, minVal: -17, maxVal: 17, title: "Camlo BG X", view: "Background"),
        duoParallaxXML(axis: "y", keyPath: "transform.translation.y", layerName: c.bgParallaxName, minVal: -22, maxVal: 22, title: "Camlo BG Y", view: "Background"),
        duoParallaxXML(axis: "x", keyPath: "transform.translation.x", layerName: c.fgParallaxName, minVal: 22, maxVal: -22, title: "Camlo FG X", view: "Floating"),
        duoParallaxXML(axis: "y", keyPath: "transform.translation.y", layerName: c.fgParallaxName, minVal: 29, maxVal: -29, title: "Camlo FG Y", view: "Floating"),
        duoParallaxXML(axis: "x", keyPath: "transform.translation.x", layerName: c.fxParallaxName, minVal: 30, maxVal: -30, title: "Camlo FX X", view: "Floating"),
        duoParallaxXML(axis: "y", keyPath: "transform.translation.y", layerName: c.fxParallaxName, minVal: 38, maxVal: -38, title: "Camlo FX Y", view: "Floating")
    ].joined(separator: "\n")

    let propEntries = morph.bgOvs.flatMap { duoPropEntries(for: $0, view: "Background") }
        + (morph.fgOvs + fxBuilt.ovs).flatMap { duoPropEntries(for: $0, view: "Floating") }
    let propGroupsXML = propEntries.isEmpty
        ? "      <wallpaperPropertyGroups type=\"NSArray\"/>"
        : "      <wallpaperPropertyGroups type=\"NSArray\">\n\(propEntries.joined(separator: "\n"))\n      </wallpaperPropertyGroups>"

    let allOvs = morph.bgOvs + morph.fgOvs + fxBuilt.ovs
    func stElements(_ stage: String) -> String {
        guard !allOvs.isEmpty else { return "        <elements/>" }
        var lns = ["        <elements>"]
        for ov in allOvs {
            let v = (stage == "Unlock") ? ov.unlockVal : (stage == "Sleep" ? ov.sleepVal : ov.lockedVal)
            let tStr = ov.isInteger ? "integer" : "real"
            let vStr = ov.isInteger ? String(Int(v.rounded())) : String(format: "%.4f", v)
            lns.append("          <LKStateSetValue targetId=\"\(ov.targetId)\" keyPath=\"\(ov.keyPath)\"><value type=\"\(tStr)\" value=\"\(vStr)\"/></LKStateSetValue>")
        }
        lns.append("        </elements>")
        return lns.joined(separator: "\n")
    }
    var trLines = ["        <elements>"]
    for ov in allOvs {
        trLines.append("          <LKStateTransitionElement targetId=\"\(ov.targetId)\" key=\"\(ov.keyPath)\"><animation type=\"CASpringAnimation\" damping=\"28\" mass=\"1\" stiffness=\"306\" velocity=\"0\" duration=\"0.85\" fillMode=\"backwards\" keyPath=\"\(ov.keyPath)\" mica_autorecalculatesDuration=\"1\"/></LKStateTransitionElement>")
    }
    trLines.append("        </elements>")
    let trEls = trLines.joined(separator: "\n")

    let bgIn = morph.bgXML.isEmpty ? "" : "\n                <sublayers>\n\(morph.bgXML)\n                </sublayers>"
    let fgIn = morph.fgXML.isEmpty ? "" : "\n                <sublayers>\n\(morph.fgXML)\n                </sublayers>"
    let fxIn = fxBuilt.xml.isEmpty ? "" : "\n              <sublayers>\n\(fxBuilt.xml)\n              </sublayers>"

    let caml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- Generated by Camlo Cloud Builder (ParameterizedCA 3D Anime Engine) -->
    <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
      <CALayer id="__capRootLayer__" name="Root Layer" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" geometryFlipped="0" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
        <style>
          <wallpaperBackgroundAssetNames type="NSArray"/>
          <wallpaperFloatingAssetNames type="NSArray"/>
          <wallpaperParallaxGroups type="NSArray">
    \(parallaxXML)
          </wallpaperParallaxGroups>
    \(propGroupsXML)
        </style>
        <sublayers>
          <CALayer id="background" name="BACKGROUND" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" geometryFlipped="0" masksToBounds="1" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
            <sublayers>
              <CALayer id="camlo_bg_parallax" name="\(c.bgParallaxName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="camlo_bg_overscan" name="\(c.bgOverscanName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" opacity="1" transform="scale(1.1040, 1.1040, 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(bgIn)
                  </CALayer>
                </sublayers>
              </CALayer>
            </sublayers>
          </CALayer>
          <CALayer id="floating" name="FLOATING" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="10" geometryFlipped="0" masksToBounds="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
            <sublayers>
              <CALayer id="camlo_fg_parallax" name="\(c.fgParallaxName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="10" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="camlo_fg_overscan" name="\(c.fgOverscanName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="0" opacity="1" transform="scale(1.0520, 1.0520, 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(fgIn)
                  </CALayer>
                </sublayers>
              </CALayer>
              <CALayer id="camlo_fx_parallax" name="\(c.fxParallaxName)" bounds="0 0 \(c.w) \(c.h)" position="\(c.cx) \(c.cy)" zPosition="20" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(fxIn)
              </CALayer>
            </sublayers>
          </CALayer>
        </sublayers>
        <modules/>
        <states>
          <LKState name="Locked">
    \(stElements("Locked"))
          </LKState>
          <LKState name="Unlock">
    \(stElements("Unlock"))
          </LKState>
          <LKState name="Sleep">
    \(stElements("Sleep"))
          </LKState>
        </states>
        <stateTransitions>
          <LKStateTransition fromState="*" toState="Unlock">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="Unlock" toState="*">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="*" toState="Locked">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="Locked" toState="*">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="*" toState="Sleep">\(trEls)</LKStateTransition>
          <LKStateTransition fromState="Sleep" toState="*">\(trEls)</LKStateTransition>
        </stateTransitions>
      </CALayer>
    </caml>
    """

    try caml.write(to: caURL.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)
    try verifyCAPackage(at: caURL)
}

// MARK: - Build Pipeline

func buildAll() throws {
    let fm = FileManager.default
    try fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: thumbsDir, withIntermediateDirectories: true)

    let metaData = try Data(contentsOf: metadataURL)
    let rootMeta = try JSONDecoder().decode(RootMetadata.self, from: metaData)
    let forceRebuild = CommandLine.arguments.contains("--force")
    print("[*] Loaded \(rootMeta.packs.count) pack definitions from \(metadataURL.path)")

    for pack in rootMeta.packs {
        let thumbOutURL = thumbsDir.appendingPathComponent("\(pack.id).jpg")
        let tendiesOutURL = packagesDir.appendingPathComponent("\(pack.id).tendies")
        if !forceRebuild, fm.fileExists(atPath: tendiesOutURL.path), fm.fileExists(atPath: thumbOutURL.path) {
            print("[=] Skipping existing \(pack.id).tendies")
            continue
        }

        let workRoot = fm.temporaryDirectory.appendingPathComponent("camlo_wp_build_\(pack.id)_\(UUID().uuidString.prefix(6))", isDirectory: true)
        defer { try? fm.removeItem(at: workRoot) }

        let wpDir = try scaffoldDescriptor(pack: pack, in: workRoot)
        if pack.category == "duo" {
            try buildDuoDualPack(pack: pack, wpDir: wpDir, thumbOutURL: thumbOutURL)
            try runDittoZip(sourceDir: workRoot, outputTendies: tendiesOutURL)
            let pkgSize = (try? fm.attributesOfItem(atPath: tendiesOutURL.path)[.size] as? Int) ?? 0
            print(String(format: "[+] Built Duo %@.tendies (%d KB) · ParameterizedCA CAPackage verified", pack.id, pkgSize / 1024))
            continue
        }
        if pack.category == "anime" {
            try buildAnime3DMorphPack(pack: pack, wpDir: wpDir, thumbOutURL: thumbOutURL)
            try runDittoZip(sourceDir: workRoot, outputTendies: tendiesOutURL)
            let pkgSize = (try? fm.attributesOfItem(atPath: tendiesOutURL.path)[.size] as? Int) ?? 0
            print(String(format: "[+] Built Anime3D %@.tendies (%d KB) · ParameterizedCA CAPackage verified", pack.id, pkgSize / 1024))
            continue
        }

        let bgCA = wpDir.appendingPathComponent("7400.WWDC_2022_Background-390w-844h@3x~iphone.ca", isDirectory: true)
        let flCA = wpDir.appendingPathComponent("7400.WWDC_2022_Floating-390w-844h@3x~iphone.ca", isDirectory: true)
        let fgCA = wpDir.appendingPathComponent("7400.WWDC_2022_Foreground-390w-844h@3x~iphone.ca", isDirectory: true)
        for ca in [bgCA, flCA, fgCA] {
            try fm.createDirectory(at: ca.appendingPathComponent("assets", isDirectory: true), withIntermediateDirectories: true)
            try standardIndexXML().write(to: ca.appendingPathComponent("index.xml"), atomically: true, encoding: .utf8)
            try standardAssetManifestXML().write(to: ca.appendingPathComponent("assetManifest.caml"), atomically: true, encoding: .utf8)
        }

        if pack.kind == "motionLoop" {
            let w = 600, h = 1300
            let (frameNames, heroThumb) = try renderMotionLoopFrames(pack: pack, width: w, height: h, assetsDir: bgCA.appendingPathComponent("assets"))
            try writeJPEG(heroThumb, to: thumbOutURL, quality: 0.88)

            let fps = pack.motion?.fps ?? 8
            let dur = pack.motion?.duration ?? (Double(frameNames.count) / Double(fps))
            try camlMotionBackgroundXML(frameNames: frameNames, duration: dur).write(to: bgCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)
            try camlFloatingCutoutXML(hasCutout: false, transitionPreset: pack.transitionPreset).write(to: flCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)

            let fgAssets = try renderParticleSprite(pack.particlePreset, outDir: fgCA.appendingPathComponent("assets"))
            try camlForegroundXML(preset: pack.particlePreset, spriteName: fgAssets.first?.filename, includeFlashPulse: false).write(to: fgCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)
        } else {
            // Morph Pair + Vision / Skyline Clock Depth Cutout
            let lockSourceURL: URL
            let unlockSourceURL: URL
            let bundleLockMaskURL: URL?
            let bundleUnlockMaskURL: URL?
            if let prefix = pack.sourceBundlePrefix, !prefix.isEmpty {
                lockSourceURL = presetBundleDir.appendingPathComponent("\(prefix)_lock.jpg")
                unlockSourceURL = presetBundleDir.appendingPathComponent("\(prefix)_unlock.jpg")
                bundleLockMaskURL = presetBundleDir.appendingPathComponent("\(prefix)_mask_lock.png")
                bundleUnlockMaskURL = presetBundleDir.appendingPathComponent("\(prefix)_mask_unlock.png")
            } else {
                lockSourceURL = sourcesDir.appendingPathComponent("\(pack.id)_lock.jpg")
                unlockSourceURL = sourcesDir.appendingPathComponent("\(pack.id)_unlock.jpg")
                bundleLockMaskURL = nil
                bundleUnlockMaskURL = nil
            }

            let lockRaw = try loadCGImage(at: lockSourceURL)
            let unlockRaw = try loadCGImage(at: unlockSourceURL)
            let lock1170 = try aspectFillCGImage(lockRaw, width: 1170, height: 2532)
            let unlock1170 = try aspectFillCGImage(unlockRaw, width: 1170, height: 2532)

            try writeJPEG(lock1170, to: bgCA.appendingPathComponent("assets/locked.jpg"), quality: 0.87)
            try writeJPEG(unlock1170, to: bgCA.appendingPathComponent("assets/unlock.jpg"), quality: 0.87)
            let thumbCG = try aspectFillCGImage(unlockRaw, width: 540, height: 1170)
            try writeJPEG(thumbCG, to: thumbOutURL, quality: 0.88)

            try camlMorphBackgroundXML(transitionPreset: pack.transitionPreset).write(to: bgCA.appendingPathComponent("main.caml"), atomically: true, encoding: .utf8)

            var hasCutout = false
            let maskMode = (pack.depthMaskMode ?? (pack.supportsClockDepth ? "vision" : "none")).lowercased()
            if pack.supportsClockDepth && maskMode != "none" {
                if let maskLURL = bundleLockMaskURL,
                   let maskUURL = bundleUnlockMaskURL,
                   fm.fileExists(atPath: maskLURL.path),
                   fm.fileExists(atPath: maskUURL.path),
                   let maskL = try? loadCGImage(at: maskLURL),
                   let maskU = try? loadCGImage(at: maskUURL) {
                    let cutLock = try compositeGrayscaleMaskCutout(source: lock1170, grayscaleMask: maskL)
                    let cutUnlock = try compositeGrayscaleMaskCutout(source: unlock1170, grayscaleMask: maskU)
                    try writePNG(cutLock, to: flCA.appendingPathComponent("assets/cutout_lock.png"))
                    try writePNG(cutUnlock, to: flCA.appendingPathComponent("assets/cutout_unlock.png"))
                    hasCutout = true
                    let covLock = estimateOpaqueCoverage(cutLock)
                    let covUnlock = estimateOpaqueCoverage(cutUnlock)
                    print(String(format: "    [Mask] %@ composite cutout coverage: lock=%.1f%% unlock=%.1f%%", pack.id, covLock * 100.0, covUnlock * 100.0))
                } else {
                    func attemptCutout(mode: String) -> (CGImage, CGImage, Double, Double, String)? {
                        if mode == "skyline" {
                            if let (cl, covL) = try? extractSkylineCutout(from: lock1170, outWidth: 780, outHeight: 1688),
                               let (cu, covU) = try? extractSkylineCutout(from: unlock1170, outWidth: 780, outHeight: 1688),
                               covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
                                return (cl, cu, covL, covU, "Skyline")
                            }
                            if let (cl, covL) = try? extractForegroundCutout(from: lock1170, outWidth: 780, outHeight: 1688),
                               let (cu, covU) = try? extractForegroundCutout(from: unlock1170, outWidth: 780, outHeight: 1688),
                               covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
                                return (cl, cu, covL, covU, "Vision-Fallback")
                            }
                        } else {
                            if let (cl, covL) = try? extractForegroundCutout(from: lock1170, outWidth: 780, outHeight: 1688),
                               let (cu, covU) = try? extractForegroundCutout(from: unlock1170, outWidth: 780, outHeight: 1688),
                               covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
                                return (cl, cu, covL, covU, "Vision")
                            }
                            if let (cl, covL) = try? extractSkylineCutout(from: lock1170, outWidth: 780, outHeight: 1688),
                               let (cu, covU) = try? extractSkylineCutout(from: unlock1170, outWidth: 780, outHeight: 1688),
                               covL >= 0.04 && covL <= 0.78 && covU >= 0.04 && covU <= 0.78 {
                                return (cl, cu, covL, covU, "Skyline-Fallback")
                            }
                        }
                        return nil
                    }

                    if let (cutLock, cutUnlock, covLock, covUnlock, tag) = attemptCutout(mode: maskMode) {
                        try writePNG(cutLock, to: flCA.appendingPathComponent("assets/cutout_lock.png"))
                        try writePNG(cutUnlock, to: flCA.appendingPathComponent("assets/cutout_unlock.png"))
                        hasCutout = true
                        print(String(format: "    [%@] %@ cutout coverage: lock=%.1f%% unlock=%.1f%%", tag, pack.id, covLock * 100.0, covUnlock * 100.0))
                    } else {
                        print("    [Cutout] \(pack.id) skipped Floating layer (coverage outside 4%...78% safe Clock-Depth band)")
                    }
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
