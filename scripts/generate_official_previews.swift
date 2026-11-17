#!/usr/bin/env swift

import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Paths & Metadata Models

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let wallpapersDir = repoRoot.appendingPathComponent("wallpapers", isDirectory: true)
let metadataURL = wallpapersDir.appendingPathComponent("metadata.json")
let packagesDir = wallpapersDir.appendingPathComponent("packages", isDirectory: true)
let previewsDir = wallpapersDir.appendingPathComponent("previews", isDirectory: true)

struct MetadataRoot: Decodable {
    let packs: [PackMeta]
}

struct PackMeta: Decodable {
    struct MotionConfig: Decodable {
        let style: String
        let fps: Int
        let frameCount: Int
        let duration: Double
    }
    let id: String
    let category: String
    let kind: String
    let transitionPreset: String
    let particlePreset: String
    let supportsClockDepth: Bool
    let accentHex: String?
    let motion: MotionConfig?
}

// MARK: - CoreGraphics / ImageIO / WebP Helpers

let previewWidth = 360
let previewHeight = 780

func resolveImg2WebPExecutable() throws -> URL {
    let candidates = [
        "/opt/homebrew/bin/img2webp",
        "/usr/local/bin/img2webp"
    ]
    for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
        return URL(fileURLWithPath: path)
    }
    let whichProc = Process()
    whichProc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    whichProc.arguments = ["img2webp"]
    let pipe = Pipe()
    whichProc.standardOutput = pipe
    try whichProc.run()
    whichProc.waitUntilExit()
    if whichProc.terminationStatus == 0 {
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !out.isEmpty, FileManager.default.isExecutableFile(atPath: out) {
            return URL(fileURLWithPath: out)
        }
    }
    throw NSError(domain: "GenPreviews", code: 20, userInfo: [NSLocalizedDescriptionKey: "img2webp executable not found"])
}

func makeRGBContext(width: Int = previewWidth, height: Int = previewHeight) throws -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: cs,
        bitmapInfo: info
    ) else {
        throw NSError(domain: "GenPreviews", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
    }
    ctx.interpolationQuality = .high
    return ctx
}

func loadCGImage(at url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func aspectFillRect(for image: CGImage, in targetRect: CGRect, extraScale: CGFloat = 1.0, offsetX: CGFloat = 0, offsetY: CGFloat = 0) -> CGRect {
    let srcW = max(1.0, CGFloat(image.width))
    let srcH = max(1.0, CGFloat(image.height))
    let baseScale = max(targetRect.width / srcW, targetRect.height / srcH) * extraScale
    let drawW = srcW * baseScale
    let drawH = srcH * baseScale
    let originX = targetRect.midX - drawW * 0.5 + offsetX
    let originY = targetRect.midY - drawH * 0.5 + offsetY
    return CGRect(x: originX, y: originY, width: drawW, height: drawH)
}

func drawAspectFill(
    _ image: CGImage,
    in ctx: CGContext,
    rect: CGRect,
    alpha: CGFloat = 1.0,
    scale: CGFloat = 1.0,
    offsetX: CGFloat = 0,
    offsetY: CGFloat = 0
) {
    guard alpha > 0.001 else { return }
    ctx.saveGState()
    ctx.setAlpha(alpha)
    let drawRect = aspectFillRect(for: image, in: rect, extraScale: scale, offsetX: offsetX, offsetY: offsetY)
    ctx.draw(image, in: drawRect)
    ctx.restoreGState()
}

func colorFromHex(_ hex: String?) -> NSColor {
    let cleaned = (hex ?? "#6A4DF5").trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let r = CGFloat((int >> 16) & 0xFF) / 255.0
    let g = CGFloat((int >> 8) & 0xFF) / 255.0
    let b = CGFloat(int & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
}

func easeInOut(_ t: CGFloat) -> CGFloat {
    let clamped = min(1.0, max(0.0, t))
    return clamped < 0.5
        ? 4.0 * clamped * clamped * clamped
        : 1.0 - pow(-2.0 * clamped + 2.0, 3.0) / 2.0
}

func drawLockClock(in ctx: CGContext, width: CGFloat, height: CGFloat, alpha: CGFloat, yShift: CGFloat = 0) {
    guard alpha > 0.02 else { return }
    ctx.saveGState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    let dateFont = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
    let dateAttr: [NSAttributedString.Key: Any] = [
        .font: dateFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.92 * alpha)
    ]
    let dateStr = NSAttributedString(string: "Tuesday, Nov 15", attributes: dateAttr)
    let dateSize = dateStr.size()
    let dateOrigin = NSPoint(
        x: (width - dateSize.width) * 0.5,
        y: height * 0.805 + yShift
    )
    dateStr.draw(at: dateOrigin)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28 * alpha)
    shadow.shadowBlurRadius = 5
    shadow.shadowOffset = NSSize(width: 0, height: -1)

    let clockFont = NSFont.systemFont(ofSize: 65, weight: .bold)
    let clockAttr: [NSAttributedString.Key: Any] = [
        .font: clockFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.95 * alpha),
        .shadow: shadow
    ]
    let clockStr = NSAttributedString(string: "09:41", attributes: clockAttr)
    let clockSize = clockStr.size()
    let clockOrigin = NSPoint(
        x: (width - clockSize.width) * 0.5,
        y: height * 0.675 + yShift
    )
    clockStr.draw(at: clockOrigin)

    NSGraphicsContext.restoreGraphicsState()
    ctx.restoreGState()
}

func drawLockChromeHints(in ctx: CGContext, width: CGFloat, height: CGFloat, alpha: CGFloat) {
    guard alpha > 0.03 else { return }
    ctx.saveGState()
    let barW: CGFloat = width * 0.34
    let barH: CGFloat = 3.5
    let barRect = CGRect(x: (width - barW) * 0.5, y: 9.0, width: barW, height: barH)
    let path = CGPath(roundedRect: barRect, cornerWidth: barH * 0.5, cornerHeight: barH * 0.5, transform: nil)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.68 * alpha).cgColor)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()
}

func drawParticleSprites(
    _ sprite: CGImage?,
    preset: String,
    phase: CGFloat,
    in ctx: CGContext,
    width: CGFloat,
    height: CGFloat,
    opacityScale: CGFloat = 1.0
) {
    guard let sprite, opacityScale > 0.02, preset != "none" else { return }
    ctx.saveGState()
    if preset == "sunbeamRays" {
        ctx.setBlendMode(.screen)
        for i in 0..<3 {
            let phaseShift = sin((phase + CGFloat(i) * 0.28) * .pi * 2.0)
            let x = width * (0.25 + CGFloat(i) * 0.24) + phaseShift * 14.0
            let beamW = width * 0.42
            let beamH = height * 0.86
            let alpha = (0.16 + 0.12 * (0.5 + 0.5 * phaseShift)) * opacityScale
            ctx.setAlpha(max(0, min(1, alpha)))
            ctx.draw(sprite, in: CGRect(x: x - beamW * 0.5, y: height * 0.14, width: beamW, height: beamH))
        }
        ctx.restoreGState()
        return
    }
    let count = (preset == "sakura" || preset == "embers" || preset == "starlight" || preset == "fireflies" || preset == "snowfall") ? 7 : 5
    for i in 0..<count {
        let seed = CGFloat(i)
        let normT = (phase + seed * 0.137).truncatingRemainder(dividingBy: 1.0)
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let alpha: CGFloat

        switch preset {
        case "embers":
            x = width * (0.12 + CGFloat((i * 29) % 76) / 100.0) + sin(normT * .pi * 2 + seed) * 12
            y = height * normT
            size = 10 + CGFloat(i % 4) * 3.5
            alpha = sin(normT * .pi) * 0.80 * opacityScale
        case "sakura", "snowfall":
            x = width * (0.08 + CGFloat((i * 31) % 84) / 100.0) + sin(normT * .pi * 2 + seed) * 14
            y = height * (1.0 - normT)
            size = (preset == "snowfall" ? 9 : 12) + CGFloat(i % 4) * 3.5
            alpha = sin(normT * .pi) * 0.78 * opacityScale
        case "meteorShower":
            let diag = normT
            x = width * (0.95 - diag * 0.85) - seed * 10
            y = height * (0.92 - diag * 0.55) - CGFloat(i % 3) * 40
            size = 20 + CGFloat(i % 3) * 6.5
            alpha = sin(diag * .pi) * 0.75 * opacityScale
        default:
            x = width * (0.10 + CGFloat((i * 23) % 80) / 100.0) + cos(normT * .pi * 2 + seed) * 8
            y = height * (0.15 + CGFloat((i * 19) % 75) / 100.0) + sin(normT * .pi * 2 + seed) * 10
            size = 9 + CGFloat(i % 3) * 3.2
            alpha = (0.28 + 0.44 * abs(sin((normT + seed * 0.2) * .pi))) * opacityScale
        }

        ctx.setAlpha(max(0, min(1, alpha)))
        ctx.draw(sprite, in: CGRect(x: x - size * 0.5, y: y - size * 0.5, width: size, height: size))
    }
    ctx.restoreGState()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "GenPreviews", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create PNG destination for \(url.path)"])
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "GenPreviews", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG at \(url.path)"])
    }
}

func verifyAnimatedWebP(at url: URL, minFrames: Int) throws -> Int {
    let data = try Data(contentsOf: url)
    guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
        throw NSError(domain: "GenPreviews", code: 21, userInfo: [NSLocalizedDescriptionKey: "CGImageSource failed to open \(url.lastPathComponent)"])
    }
    let count = CGImageSourceGetCount(src)
    guard count >= minFrames else {
        throw NSError(domain: "GenPreviews", code: 22, userInfo: [NSLocalizedDescriptionKey: "Expected >= \(minFrames) frames in \(url.lastPathComponent), got \(count)"])
    }
    guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
          let webpDict = props[kCGImagePropertyWebPDictionary] as? [CFString: Any],
          (webpDict[kCGImagePropertyWebPUnclampedDelayTime] as? Double ?? webpDict[kCGImagePropertyWebPDelayTime] as? Double ?? 0) > 0 else {
        throw NSError(domain: "GenPreviews", code: 23, userInfo: [NSLocalizedDescriptionKey: "Missing WebP delay dictionary in \(url.lastPathComponent)"])
    }
    return count
}

func writeAnimatedWebP(
    frames: [(image: CGImage, delayMs: Int)],
    to url: URL,
    workDir: URL,
    img2webp: URL,
    quality: Int = 68
) throws {
    guard !frames.isEmpty else {
        throw NSError(domain: "GenPreviews", code: 4, userInfo: [NSLocalizedDescriptionKey: "No frames to encode for \(url.lastPathComponent)"])
    }

    let pngDir = workDir.appendingPathComponent("frames_\(UUID().uuidString.prefix(6))", isDirectory: true)
    try FileManager.default.createDirectory(at: pngDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: pngDir) }

    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }

    var args: [String] = [
        "-loop", "0",
        "-lossy",
        "-q", "\(quality)",
        "-m", "4"
    ]

    for (idx, frame) in frames.enumerated() {
        let frameURL = pngDir.appendingPathComponent(String(format: "frame_%02d.png", idx))
        try writePNG(frame.image, to: frameURL)
        args.append(contentsOf: ["-d", "\(max(30, frame.delayMs))", frameURL.path])
    }

    args.append(contentsOf: ["-o", url.path])

    let proc = Process()
    proc.executableURL = img2webp
    proc.arguments = args
    proc.standardInput = FileHandle.nullDevice
    let errPipe = Pipe()
    proc.standardError = errPipe
    proc.standardOutput = FileHandle.nullDevice
    try proc.run()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    if proc.terminationStatus != 0 {
        let errText = String(data: errData, encoding: .utf8) ?? ""
        throw NSError(domain: "GenPreviews", code: 5, userInfo: [NSLocalizedDescriptionKey: "img2webp failed (\(proc.terminationStatus)) for \(url.lastPathComponent): \(errText)"])
    }

    _ = try verifyAnimatedWebP(at: url, minFrames: min(16, frames.count))
}

func unzipArchive(_ zipURL: URL, to destDir: URL) throws {
    try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    proc.arguments = ["-q", zipURL.path, "-d", destDir.path]
    proc.standardInput = FileHandle.nullDevice
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus != 0 {
        throw NSError(domain: "GenPreviews", code: 6, userInfo: [NSLocalizedDescriptionKey: "unzip failed with status \(proc.terminationStatus) for \(zipURL.lastPathComponent)"])
    }
}

func generateDuoPreview(
    pack: PackMeta,
    extractedDir: URL,
    outURL: URL,
    workDir: URL,
    img2webp: URL
) throws {
    guard let caDir = findDirectory(named: "wallpaper.ca", under: extractedDir) else {
        throw NSError(domain: "GenPreviews", code: 12, userInfo: [NSLocalizedDescriptionKey: "Missing wallpaper.ca for \(pack.id)"])
    }
    let assetsDir = caDir.appendingPathComponent("assets", isDirectory: true)
    let w: CGFloat = 560
    let h: CGFloat = 394
    let innerRect = CGRect(x: 0, y: 0, width: w, height: h)
    let pipRect = CGRect(x: 18, y: 18, width: 108, height: 157)
    let pipCorner: CGFloat = 16
    let accent = colorFromHex(pack.accentHex)

    let outerSprite: CGImage? = {
        let files = (try? FileManager.default.contentsOfDirectory(at: assetsDir, includingPropertiesForKeys: nil)) ?? []
        return files.first(where: { $0.pathExtension.lowercased() == "png" && $0.lastPathComponent.hasPrefix("particle_") }).flatMap { loadCGImage(at: $0) }
    }()

    var encodedFrames: [(CGImage, Int)] = []

    func drawBeveledPiP(_ outerImg: CGImage, scale: CGFloat, clockAlpha: CGFloat, cutout: CGImage?, in ctx: CGContext) {
        ctx.saveGState()
        let shadowRect = pipRect.insetBy(dx: -3, dy: -3)
        let shadowPath = CGPath(roundedRect: shadowRect, cornerWidth: pipCorner + 2, cornerHeight: pipCorner + 2, transform: nil)
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: NSColor.black.withAlphaComponent(0.65).cgColor)
        ctx.setFillColor(NSColor(white: 0.08, alpha: 1.0).cgColor)
        ctx.addPath(shadowPath)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        let clipPath = CGPath(roundedRect: pipRect, cornerWidth: pipCorner, cornerHeight: pipCorner, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()
        drawAspectFill(outerImg, in: ctx, rect: pipRect, alpha: 1.0, scale: scale)

        if clockAlpha > 0.04 {
            drawLockClock(in: ctx, width: pipRect.width, height: pipRect.height, alpha: clockAlpha * 0.9)
        }
        if let cutout {
            drawAspectFill(cutout, in: ctx, rect: pipRect, alpha: 1.0, scale: scale)
        }
        ctx.restoreGState()

        ctx.saveGState()
        let borderPath = CGPath(roundedRect: pipRect, cornerWidth: pipCorner, cornerHeight: pipCorner, transform: nil)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
        ctx.setLineWidth(2.0)
        ctx.addPath(borderPath)
        ctx.strokePath()
        ctx.restoreGState()
    }

    if pack.kind == "duoMotion" {
        let count = max(12, pack.motion?.frameCount ?? 16)
        let delayMs = Int(round(1000.0 / Double(max(8, pack.motion?.fps ?? 12))))
        for idx in 0..<count {
            guard let innerCG = loadCGImage(at: assetsDir.appendingPathComponent("inner_frame_\(idx).jpg")),
                  let outerCG = loadCGImage(at: assetsDir.appendingPathComponent("frame_\(idx).jpg")) else { continue }
            let ctx = try makeRGBContext(width: Int(w), height: Int(h))
            drawAspectFill(innerCG, in: ctx, rect: innerRect)
            let phase = CGFloat(idx) / CGFloat(max(1, count))
            drawParticleSprites(outerSprite, preset: pack.particlePreset, phase: phase, in: ctx, width: w, height: h, opacityScale: 0.80)
            drawLockClock(in: ctx, width: w, height: h, alpha: 0.85)
            // Subtle book crease
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
            ctx.fill(CGRect(x: w * 0.5 - 0.5, y: 0, width: 1, height: h))
            drawBeveledPiP(outerCG, scale: 1.0, clockAlpha: 0.0, cutout: nil, in: ctx)
            if let outImg = ctx.makeImage() {
                encodedFrames.append((outImg, delayMs))
            }
        }
    } else {
        guard let outerLock = loadCGImage(at: assetsDir.appendingPathComponent("locked.jpg")),
              let outerUnlock = loadCGImage(at: assetsDir.appendingPathComponent("unlock.jpg")),
              let innerLock = loadCGImage(at: assetsDir.appendingPathComponent("inner_locked.jpg")),
              let innerUnlock = loadCGImage(at: assetsDir.appendingPathComponent("inner_unlock.jpg")) else {
            throw NSError(domain: "GenPreviews", code: 13, userInfo: [NSLocalizedDescriptionKey: "Missing Duo morph images for \(pack.id)"])
        }
        let innerCutLock = loadCGImage(at: assetsDir.appendingPathComponent("inner_cutout_lock.png"))
        let innerCutUnlock = loadCGImage(at: assetsDir.appendingPathComponent("inner_cutout_unlock.png"))

        let totalFrames = 16
        for idx in 0..<totalFrames {
            let ctx = try makeRGBContext(width: Int(w), height: Int(h))
            let phase = CGFloat(idx) / CGFloat(totalFrames)
            let delayMs: Int
            let lockAlpha: CGFloat, unlockAlpha: CGFloat
            let clockAlpha: CGFloat
            let flashAlpha: CGFloat

            if idx == 0 {
                delayMs = 680; lockAlpha = 1.0; unlockAlpha = 0.0; clockAlpha = 0.94; flashAlpha = 0.0
            } else if idx <= 8 {
                delayMs = 80
                let t = easeInOut(CGFloat(idx) / 9.0)
                lockAlpha = 1.0 - t; unlockAlpha = t
                clockAlpha = max(0, (1.0 - t * 1.45) * 0.94)
                flashAlpha = (pack.transitionPreset == "flashAwaken" || pack.transitionPreset == "burstZoom") ? sin(t * .pi) * 0.14 : 0.0
            } else if idx == 9 {
                delayMs = 680; lockAlpha = 0.0; unlockAlpha = 1.0; clockAlpha = 0.0; flashAlpha = 0.0
            } else {
                delayMs = 85
                let b = easeInOut(CGFloat(idx - 9) / 7.0)
                unlockAlpha = 1.0 - b; lockAlpha = b; clockAlpha = b * 0.94; flashAlpha = 0.0
            }

            drawAspectFill(innerLock, in: ctx, rect: innerRect, alpha: lockAlpha)
            drawAspectFill(innerUnlock, in: ctx, rect: innerRect, alpha: unlockAlpha)
            if flashAlpha > 0.005 {
                ctx.setFillColor(accent.withAlphaComponent(flashAlpha).cgColor)
                ctx.fill(innerRect)
            }
            drawLockClock(in: ctx, width: w, height: h, alpha: clockAlpha)
            if let icl = innerCutLock, lockAlpha > 0.05 {
                drawAspectFill(icl, in: ctx, rect: innerRect, alpha: lockAlpha)
            }
            if let icu = innerCutUnlock, unlockAlpha > 0.05 && lockAlpha > 0.02 {
                drawAspectFill(icu, in: ctx, rect: innerRect, alpha: min(1.0, unlockAlpha * 0.85))
            }
            drawParticleSprites(outerSprite, preset: pack.particlePreset, phase: phase, in: ctx, width: w, height: h, opacityScale: 0.88)
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
            ctx.fill(CGRect(x: w * 0.5 - 0.5, y: 0, width: 1, height: h))

            // Draw matching outer screen inside PiP bezel
            let pipCtx = try makeRGBContext(width: Int(pipRect.width), height: Int(pipRect.height))
            let rP = CGRect(x: 0, y: 0, width: pipRect.width, height: pipRect.height)
            drawAspectFill(outerLock, in: pipCtx, rect: rP, alpha: lockAlpha)
            drawAspectFill(outerUnlock, in: pipCtx, rect: rP, alpha: unlockAlpha)
            if let pipImg = pipCtx.makeImage() {
                drawBeveledPiP(pipImg, scale: 1.0, clockAlpha: 0.0, cutout: nil, in: ctx)
            }

            if let outImg = ctx.makeImage() {
                encodedFrames.append((outImg, delayMs))
            }
        }
    }

    try writeAnimatedWebP(frames: encodedFrames, to: outURL, workDir: workDir, img2webp: img2webp, quality: 72)
}

func findDirectory(named suffix: String, under root: URL) -> URL? {
    guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else {
        return nil
    }
    for case let url as URL in en {
        if url.lastPathComponent.hasSuffix(suffix) {
            return url
        }
    }
    return nil
}

func findFirstParticleSprite(under root: URL) -> CGImage? {
    let candidateDir = findDirectory(named: "_Foreground-390w-844h@3x~iphone.ca", under: root)
        ?? findDirectory(named: "wallpaper.ca", under: root)
    guard let dir = candidateDir else {
        return nil
    }
    let assetsDir = dir.appendingPathComponent("assets", isDirectory: true)
    guard let files = try? FileManager.default.contentsOfDirectory(at: assetsDir, includingPropertiesForKeys: nil) else {
        return nil
    }
    if let png = files.first(where: { $0.lastPathComponent.hasPrefix("particle_") && $0.pathExtension.lowercased() == "png" })
        ?? files.first(where: { $0.pathExtension.lowercased() == "png" && !$0.lastPathComponent.hasPrefix("cutout_") }) {
        return loadCGImage(at: png)
    }
    return nil
}

func generateMotionLoopPreview(
    pack: PackMeta,
    extractedDir: URL,
    outURL: URL,
    workDir: URL,
    img2webp: URL
) throws {
    guard let bgDir = findDirectory(named: "_Background-390w-844h@3x~iphone.ca", under: extractedDir) else {
        throw NSError(domain: "GenPreviews", code: 7, userInfo: [NSLocalizedDescriptionKey: "Missing Background.ca for \(pack.id)"])
    }
    let assetsDir = bgDir.appendingPathComponent("assets", isDirectory: true)
    let files = (try? FileManager.default.contentsOfDirectory(at: assetsDir, includingPropertiesForKeys: nil)) ?? []

    let frameFiles = files
        .filter { $0.lastPathComponent.hasPrefix("frame_") && $0.pathExtension.lowercased() == "jpg" }
        .sorted { a, b in
            let nA = Int(a.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "frame_", with: "")) ?? 0
            let nB = Int(b.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "frame_", with: "")) ?? 0
            return nA < nB
        }

    guard !frameFiles.isEmpty else {
        throw NSError(domain: "GenPreviews", code: 8, userInfo: [NSLocalizedDescriptionKey: "No frame_*.jpg found for \(pack.id)"])
    }

    let fps = max(8, pack.motion?.fps ?? 14)
    let delayMs = Int(round(1000.0 / Double(fps)))
    let targetRect = CGRect(x: 0, y: 0, width: previewWidth, height: previewHeight)
    let particle = findFirstParticleSprite(under: extractedDir)

    var encodedFrames: [(CGImage, Int)] = []
    encodedFrames.reserveCapacity(frameFiles.count)

    for (idx, frameURL) in frameFiles.enumerated() {
        guard let srcImg = loadCGImage(at: frameURL) else { continue }
        let ctx = try makeRGBContext()
        drawAspectFill(srcImg, in: ctx, rect: targetRect)
        let phase = CGFloat(idx) / CGFloat(max(1, frameFiles.count))
        drawParticleSprites(particle, preset: pack.particlePreset, phase: phase, in: ctx, width: CGFloat(previewWidth), height: CGFloat(previewHeight), opacityScale: 0.72)
        drawLockClock(in: ctx, width: CGFloat(previewWidth), height: CGFloat(previewHeight), alpha: 0.90)
        drawLockChromeHints(in: ctx, width: CGFloat(previewWidth), height: CGFloat(previewHeight), alpha: 0.85)
        if let outImg = ctx.makeImage() {
            encodedFrames.append((outImg, delayMs))
        }
    }

    try writeAnimatedWebP(frames: encodedFrames, to: outURL, workDir: workDir, img2webp: img2webp, quality: 74)
}

func generateMorphPairPreview(
    pack: PackMeta,
    extractedDir: URL,
    outURL: URL,
    workDir: URL,
    img2webp: URL
) throws {
    let paramCADir = findDirectory(named: "wallpaper.ca", under: extractedDir)
    guard let bgDir = findDirectory(named: "_Background-390w-844h@3x~iphone.ca", under: extractedDir) ?? paramCADir else {
        throw NSError(domain: "GenPreviews", code: 9, userInfo: [NSLocalizedDescriptionKey: "Missing Background.ca for \(pack.id)"])
    }
    let bgAssets = bgDir.appendingPathComponent("assets", isDirectory: true)
    guard let lockedImg = loadCGImage(at: bgAssets.appendingPathComponent("locked.jpg")),
          let unlockImg = loadCGImage(at: bgAssets.appendingPathComponent("unlock.jpg")) else {
        throw NSError(domain: "GenPreviews", code: 10, userInfo: [NSLocalizedDescriptionKey: "Missing locked.jpg or unlock.jpg for \(pack.id)"])
    }

    let floatDir = findDirectory(named: "_Floating-390w-844h@3x~iphone.ca", under: extractedDir) ?? paramCADir
    let cutoutLock = floatDir.flatMap { loadCGImage(at: $0.appendingPathComponent("assets/cutout_lock.png")) }
    let cutoutUnlock = floatDir.flatMap { loadCGImage(at: $0.appendingPathComponent("assets/cutout_unlock.png")) }
    let particle = findFirstParticleSprite(under: extractedDir)

    let totalFrames = 16
    let w = CGFloat(previewWidth)
    let h = CGFloat(previewHeight)
    let targetRect = CGRect(x: 0, y: 0, width: w, height: h)
    let accent = colorFromHex(pack.accentHex)

    var encodedFrames: [(CGImage, Int)] = []
    encodedFrames.reserveCapacity(totalFrames)

    for idx in 0..<totalFrames {
        let ctx = try makeRGBContext()
        let phase = CGFloat(idx) / CGFloat(totalFrames)

        let delayMs: Int
        let lockAlpha: CGFloat
        let unlockAlpha: CGFloat
        var lockScale: CGFloat = 1.0
        var unlockScale: CGFloat = 1.0
        var lockShiftX: CGFloat = 0
        var lockShiftY: CGFloat = 0
        var unlockShiftX: CGFloat = 0
        var unlockShiftY: CGFloat = 0
        var clockAlpha: CGFloat = 0.0
        var clockShiftY: CGFloat = 0
        var cutoutLockAlpha: CGFloat = 0.0
        var cutoutUnlockAlpha: CGFloat = 0.0
        var flashOverlayAlpha: CGFloat = 0.0

        if idx == 0 {
            // Frame 0 (680ms): Locked Hold with AI Clock Depth occlusion
            delayMs = 680
            lockAlpha = 1.0
            unlockAlpha = 0.0
            clockAlpha = 0.96
            cutoutLockAlpha = 1.0
        } else if idx <= 8 {
            // Frames 1..8 (80ms each): Smooth 8-step Unlock Morph transition
            delayMs = 80
            let rawT = CGFloat(idx) / 9.0
            let t = easeInOut(rawT)
            lockAlpha = 1.0 - t
            unlockAlpha = t
            clockAlpha = max(0, (1.0 - t * 1.45) * 0.96)
            cutoutLockAlpha = 1.0 - t
            cutoutUnlockAlpha = min(1.0, t * 0.85) * (1.0 - max(0, (t - 0.72) / 0.28))

            switch pack.transitionPreset {
            case "burstZoom":
                lockScale = 1.0 + 0.10 * t
                unlockScale = 0.95 + 0.05 * t
                flashOverlayAlpha = sin(t * .pi) * 0.10
            case "curtainRise":
                lockShiftY = 22 * t
                unlockShiftY = -14 * (1.0 - t)
                clockShiftY = 16 * t
            case "holoCard":
                lockShiftX = -12 * t
                unlockShiftX = 12 * (1.0 - t)
                flashOverlayAlpha = sin(t * .pi) * 0.12
            case "aodGaze":
                lockScale = 1.0 + 0.03 * t
                unlockScale = 1.04 - 0.04 * t
            case "crossfade":
                lockScale = 1.0 + 0.03 * t
                unlockScale = 1.04 - 0.04 * t
            default: // flashAwaken
                let peak = sin(t * .pi)
                lockScale = 1.0 + 0.03 * peak
                unlockScale = 1.0 + 0.03 * (1.0 - t)
                flashOverlayAlpha = peak * 0.18
            }
        } else if idx == 9 {
            // Frame 9 (680ms): Unlocked Hero Hold
            delayMs = 680
            lockAlpha = 0.0
            unlockAlpha = 1.0
            clockAlpha = 0.0
        } else {
            // Frames 10..15 (85ms each): Seamless 6-step Return to Locked
            delayMs = 85
            let backT = easeInOut(CGFloat(idx - 9) / 7.0)
            unlockAlpha = 1.0 - backT
            lockAlpha = backT
            clockAlpha = backT * 0.96
            cutoutLockAlpha = backT
        }

        let gyroX: CGFloat = (pack.category == "anime") ? sin(phase * .pi * 2.0) : 0.0
        let gyroScale: CGFloat = (pack.category == "anime") ? 1.04 : 1.0
        let bgShiftL = lockShiftX + gyroX * 4.5
        let bgShiftU = unlockShiftX + gyroX * 4.5
        let fgShiftL = lockShiftX - gyroX * 6.5
        let fgShiftU = unlockShiftX - gyroX * 6.5

        // Base Locked layer
        drawAspectFill(lockedImg, in: ctx, rect: targetRect, alpha: lockAlpha, scale: lockScale * gyroScale, offsetX: bgShiftL, offsetY: lockShiftY)
        // Target Unlocked layer
        drawAspectFill(unlockImg, in: ctx, rect: targetRect, alpha: unlockAlpha, scale: unlockScale * gyroScale, offsetX: bgShiftU, offsetY: unlockShiftY)

        // Preset energy glow / flash
        if flashOverlayAlpha > 0.005 {
            ctx.saveGState()
            ctx.setFillColor(accent.withAlphaComponent(flashOverlayAlpha).cgColor)
            ctx.fill(targetRect)
            ctx.restoreGState()
        }

        // Lock Screen "09:41" clock sandwiched UNDER the subject cutout
        drawLockClock(in: ctx, width: w, height: h, alpha: clockAlpha, yShift: clockShiftY)

        // Foreground Clock Depth cutouts
        if let cutoutLock {
            drawAspectFill(cutoutLock, in: ctx, rect: targetRect, alpha: cutoutLockAlpha, scale: lockScale * gyroScale, offsetX: fgShiftL, offsetY: lockShiftY)
        }
        if let cutoutUnlock, cutoutUnlockAlpha > 0.01 {
            drawAspectFill(cutoutUnlock, in: ctx, rect: targetRect, alpha: cutoutUnlockAlpha, scale: unlockScale * gyroScale, offsetX: fgShiftU, offsetY: unlockShiftY)
        }

        // Foreground drifting particles + Lock Chrome hint
        drawParticleSprites(particle, preset: pack.particlePreset, phase: phase, in: ctx, width: w, height: h, opacityScale: 0.9)
        drawLockChromeHints(in: ctx, width: w, height: h, alpha: max(0.35, clockAlpha))

        if let outImg = ctx.makeImage() {
            encodedFrames.append((outImg, delayMs))
        }
    }

    try writeAnimatedWebP(frames: encodedFrames, to: outURL, workDir: workDir, img2webp: img2webp, quality: 74)
}

// MARK: - Main

func run() throws {
    let img2webp = try resolveImg2WebPExecutable()
    let metaData = try Data(contentsOf: metadataURL)
    let root = try JSONDecoder().decode(MetadataRoot.self, from: metaData)
    try FileManager.default.createDirectory(at: previewsDir, withIntermediateDirectories: true)

    let workTempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("camlo_preview_gen_\(UUID().uuidString.prefix(8))", isDirectory: true)
    try FileManager.default.createDirectory(at: workTempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workTempRoot) }

    let forceRebuild = CommandLine.arguments.contains("--force")

    for pack in root.packs {
        let outWebP = previewsDir.appendingPathComponent("\(pack.id).webp")
        if !forceRebuild, FileManager.default.fileExists(atPath: outWebP.path) {
            let existingFrames = try verifyAnimatedWebP(at: outWebP, minFrames: 16)
            print("[=] Skipping existing \(outWebP.lastPathComponent) (\(existingFrames) frames verified)")
            continue
        }

        let tendiesURL = packagesDir.appendingPathComponent("\(pack.id).tendies")
        guard FileManager.default.fileExists(atPath: tendiesURL.path) else {
            throw NSError(domain: "GenPreviews", code: 11, userInfo: [NSLocalizedDescriptionKey: "Missing package \(tendiesURL.path)"])
        }
        let unpackDir = workTempRoot.appendingPathComponent(pack.id, isDirectory: true)
        try unzipArchive(tendiesURL, to: unpackDir)

        if pack.category == "duo" {
            try generateDuoPreview(pack: pack, extractedDir: unpackDir, outURL: outWebP, workDir: workTempRoot, img2webp: img2webp)
        } else if pack.category == "motion" {
            try generateMotionLoopPreview(pack: pack, extractedDir: unpackDir, outURL: outWebP, workDir: workTempRoot, img2webp: img2webp)
        } else {
            try generateMorphPairPreview(pack: pack, extractedDir: unpackDir, outURL: outWebP, workDir: workTempRoot, img2webp: img2webp)
        }

        let sizeKB = ((try? FileManager.default.attributesOfItem(atPath: outWebP.path)[.size] as? Int) ?? 0) / 1024
        let frameCount = try verifyAnimatedWebP(at: outWebP, minFrames: 16)
        print("[+] Generated & verified \(outWebP.lastPathComponent) (\(sizeKB) KB, \(frameCount) frames)")
    }
}

try run()
