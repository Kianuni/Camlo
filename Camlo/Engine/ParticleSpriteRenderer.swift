//
//  ParticleSpriteRenderer.swift
//  Camlo · 开幕
//
//  Procedurally renders multi-shape anti-aliased vector sprites and volumetric light veils
//  via CoreGraphics for CAEmitterLayer, animated CAML layers, and live Simulator preview.
//

import UIKit
import CoreGraphics

struct ParticleSpriteAsset: @unchecked Sendable {
    let filename: String
    let image: UIImage
    let data: Data
}

enum ParticleSpriteRenderer {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var cache: [ParticlePreset: [ParticleSpriteAsset]] = [:]

    static func assets(for preset: ParticlePreset) -> [ParticleSpriteAsset] {
        guard preset != .none else { return [] }

        lock.lock()
        if let cached = cache[preset] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let rendered = buildAssets(for: preset)

        lock.lock()
        cache[preset] = rendered
        lock.unlock()
        return rendered
    }

    private static func buildAssets(for preset: ParticlePreset) -> [ParticleSpriteAsset] {
        switch preset {
        case .none:
            return []

        case .meteorShower:
            return [
                makeAsset(filename: "particle_meteor_streak.png", size: CGSize(width: 220, height: 220), draw: drawMeteorStreak),
                makeAsset(filename: "particle_meteor_star.png", size: CGSize(width: 128, height: 128), draw: drawMeteorStar)
            ].compactMap { $0 }

        case .sunbeamRays:
            return [
                makeAsset(filename: "particle_sunbeam_veil.png", size: CGSize(width: 420, height: 760), draw: drawSunbeamVeil),
                makeAsset(filename: "particle_sunbeam_mote.png", size: CGSize(width: 96, height: 96), draw: drawSunbeamMote)
            ].compactMap { $0 }

        case .auroraRibbon:
            return [
                makeAsset(filename: "particle_aurora_silk_a.png", size: CGSize(width: 440, height: 520), draw: drawAuroraSilk),
                makeAsset(filename: "particle_aurora_flare.png", size: CGSize(width: 112, height: 112), draw: drawAuroraFlare)
            ].compactMap { $0 }

        case .sakura:
            return [
                makeAsset(filename: "particle_sakura_a.png", size: CGSize(width: 128, height: 128), draw: drawSakuraFrontPetal),
                makeAsset(filename: "particle_sakura_b.png", size: CGSize(width: 128, height: 128), draw: drawSakuraCurledPetal),
                makeAsset(filename: "particle_sakura_bokeh.png", size: CGSize(width: 128, height: 128), draw: drawSakuraBokehPetal)
            ].compactMap { $0 }

        case .snowfall:
            return [
                makeAsset(filename: "particle_snow_crystal_a.png", size: CGSize(width: 128, height: 128), draw: drawSnowDendriteCrystal),
                makeAsset(filename: "particle_snow_crystal_b.png", size: CGSize(width: 128, height: 128), draw: drawSnowStarPlateCrystal)
            ].compactMap { $0 }

        case .starlight:
            return [
                makeAsset(filename: "particle_star_cross.png", size: CGSize(width: 144, height: 144), draw: drawAnamorphicCrossFlare),
                makeAsset(filename: "particle_star_octa.png", size: CGSize(width: 128, height: 128), draw: drawOctaJewelFlare)
            ].compactMap { $0 }

        case .embers:
            return [
                makeAsset(filename: "particle_ember_streak.png", size: CGSize(width: 128, height: 160), draw: drawEmberStreak),
                makeAsset(filename: "particle_ember_shard.png", size: CGSize(width: 96, height: 96), draw: drawEmberShard)
            ].compactMap { $0 }

        case .fireflies:
            return [
                makeAsset(filename: "particle_firefly_wisp.png", size: CGSize(width: 128, height: 128), draw: drawFireflyWisp),
                makeAsset(filename: "particle_firefly_hex.png", size: CGSize(width: 128, height: 128), draw: drawHexagonalBokeh)
            ].compactMap { $0 }
        }
    }

    private static func makeAsset(filename: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> ParticleSpriteAsset? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setAllowsAntialiasing(true)
            cg.setShouldAntialias(true)
            draw(cg, size)
        }
        guard let data = image.pngData() else { return nil }
        return ParticleSpriteAsset(filename: filename, image: image, data: data)
    }

    // MARK: - 1. Shooting Meteors & Cross Stars

    /// Drawn with head near bottom-left `(44, 176)` and tail tapering to top-right `(204, 16)`,
    /// matching CAML `emissionLongitude="-2.3562"` (-135 deg: left & downward in screen space).
    private static func drawMeteorStreak(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let head = CGPoint(x: 44, y: 176)
        let tail = CGPoint(x: 204, y: 16)
        // Normal perpendicular to head->tail (160, -160) normalized is (+0.7071, +0.7071)
        let nx: CGFloat = 0.7071
        let ny: CGFloat = 0.7071

        // Outer soft cyan-violet atmospheric trail wedge
        cg.saveGState()
        let outerPath = CGMutablePath()
        outerPath.move(to: CGPoint(x: head.x - nx * 8.5, y: head.y - ny * 8.5))
        outerPath.addLine(to: CGPoint(x: head.x + nx * 8.5, y: head.y + ny * 8.5))
        outerPath.addLine(to: tail)
        outerPath.closeSubpath()
        cg.addPath(outerPath)
        cg.clip()
        if let outerGrad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.78, green: 0.94, blue: 1.0, alpha: 0.44),
                CGColor(red: 0.46, green: 0.74, blue: 1.0, alpha: 0.22),
                CGColor(red: 0.52, green: 0.42, blue: 1.0, alpha: 0.08),
                CGColor(red: 0.52, green: 0.42, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.28, 0.65, 1.0]
        ) {
            cg.drawLinearGradient(outerGrad, start: head, end: tail, options: [.drawsBeforeStartLocation])
        }
        cg.restoreGState()

        // Inner bright white-cyan tapered lance
        cg.saveGState()
        let corePath = CGMutablePath()
        corePath.move(to: CGPoint(x: head.x - nx * 2.8, y: head.y - ny * 2.8))
        corePath.addLine(to: CGPoint(x: head.x + nx * 2.8, y: head.y + ny * 2.8))
        corePath.addLine(to: CGPoint(x: tail.x - 16, y: tail.y + 16))
        corePath.closeSubpath()
        cg.addPath(corePath)
        cg.clip()
        if let coreGrad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98),
                CGColor(red: 0.74, green: 0.95, blue: 1.0, alpha: 0.72),
                CGColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.40, 1.0]
        ) {
            cg.drawLinearGradient(coreGrad, start: head, end: CGPoint(x: tail.x - 16, y: tail.y + 16), options: [])
        }
        cg.restoreGState()

        // Head radial glow & crisp 4-point optical needle flare
        if let glow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92),
                CGColor(red: 0.60, green: 0.88, blue: 1.0, alpha: 0.42),
                CGColor(red: 0.50, green: 0.75, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.35, 1.0]
        ) {
            cg.drawRadialGradient(glow, startCenter: head, startRadius: 0, endCenter: head, endRadius: 20, options: [])
        }
        drawFourPointNeedleStar(in: cg, center: head, rx: 28, ry: 28, waist: 1.8, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
    }

    private static func drawMeteorStar(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        if let glow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.60),
                CGColor(red: 0.62, green: 0.88, blue: 1.0, alpha: 0.22),
                CGColor(red: 0.62, green: 0.88, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.40, 1.0]
        ) {
            cg.drawRadialGradient(glow, startCenter: c, startRadius: 0, endCenter: c, endRadius: 24, options: [])
        }
        drawFourPointNeedleStar(in: cg, center: c, rx: 52, ry: 44, waist: 2.2, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.98))
    }

    // MARK: - 2. Volumetric Sunbeams (Tyndall Rays) & Gold Prism Motes

    private static func drawSunbeamVeil(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let w = size.width
        let h = size.height

        struct RaySpec {
            let xTop: CGFloat
            let xBot: CGFloat
            let halfWTop: CGFloat
            let halfWBot: CGFloat
            let alpha: CGFloat
            let warmth: CGFloat
        }

        let rays: [RaySpec] = [
            RaySpec(xTop: 95, xBot: 215, halfWTop: 22, halfWBot: 58, alpha: 0.28, warmth: 1.0),
            RaySpec(xTop: 145, xBot: 305, halfWTop: 30, halfWBot: 74, alpha: 0.34, warmth: 0.94),
            RaySpec(xTop: 205, xBot: 365, halfWTop: 18, halfWBot: 46, alpha: 0.24, warmth: 0.88),
            RaySpec(xTop: 65, xBot: 165, halfWTop: 16, halfWBot: 44, alpha: 0.22, warmth: 0.90),
            RaySpec(xTop: 248, xBot: 382, halfWTop: 14, halfWBot: 36, alpha: 0.20, warmth: 1.0)
        ]

        // Render feathered shafts using dense layered translucent bands so shafts look volumetric without hard edges
        for ray in rays {
            for step in stride(from: -14, through: 14, by: 2) {
                let frac = CGFloat(step) / 14.0
                let falloff = pow(max(0, 1.0 - frac * frac), 1.6)
                let sliceWTop = ray.halfWTop * (abs(frac) + 0.14)
                let sliceWBot = ray.halfWBot * (abs(frac) + 0.14)
                let offsetTop = frac * ray.halfWTop * 0.55
                let offsetBot = frac * ray.halfWBot * 0.55

                let path = CGMutablePath()
                path.move(to: CGPoint(x: ray.xTop + offsetTop - sliceWTop * 0.35, y: 28))
                path.addLine(to: CGPoint(x: ray.xTop + offsetTop + sliceWTop * 0.35, y: 28))
                path.addLine(to: CGPoint(x: ray.xBot + offsetBot + sliceWBot * 0.35, y: h - 28))
                path.addLine(to: CGPoint(x: ray.xBot + offsetBot - sliceWBot * 0.35, y: h - 28))
                path.closeSubpath()

                cg.saveGState()
                cg.addPath(path)
                cg.clip()
                let a = ray.alpha * falloff * 0.24
                let r: CGFloat = 1.0
                let g: CGFloat = 0.88 + 0.08 * ray.warmth
                let b: CGFloat = 0.56 + 0.24 * ray.warmth
                if let beamGrad = CGGradient(
                    colorsSpace: cs,
                    colors: [
                        CGColor(red: r, green: g, blue: b, alpha: 0.0),
                        CGColor(red: r, green: g, blue: b, alpha: a * 1.15),
                        CGColor(red: r, green: g, blue: b, alpha: a * 0.72),
                        CGColor(red: r, green: g, blue: b, alpha: 0.0)
                    ] as CFArray,
                    locations: [0.0, 0.18, 0.65, 1.0]
                ) {
                    cg.drawLinearGradient(
                        beamGrad,
                        start: CGPoint(x: ray.xTop, y: 28),
                        end: CGPoint(x: ray.xBot, y: h - 28),
                        options: []
                    )
                }
                cg.restoreGState()
            }
        }

        applySoftBorderEnvelope(cg: cg, size: size, insetX: min(44, w * 0.11), insetY: min(56, h * 0.08))
    }

    private static func drawSunbeamMote(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

        if let halo = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.94, blue: 0.72, alpha: 0.65),
                CGColor(red: 1.0, green: 0.84, blue: 0.44, alpha: 0.24),
                CGColor(red: 1.0, green: 0.84, blue: 0.44, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.42, 1.0]
        ) {
            cg.drawRadialGradient(halo, startCenter: c, startRadius: 0, endCenter: c, endRadius: 24, options: [])
        }

        // Subtle hexagonal prism shimmer ring + warm diamond glint
        let hex = regularHexagonPath(center: c, radius: 22, cornerSoftness: 2.0)
        cg.saveGState()
        cg.addPath(hex)
        cg.setStrokeColor(CGColor(red: 1.0, green: 0.90, blue: 0.60, alpha: 0.28))
        cg.setLineWidth(1.6)
        cg.strokePath()
        cg.restoreGState()

        drawFourPointNeedleStar(in: cg, center: c, rx: 32, ry: 32, waist: 2.4, color: CGColor(red: 1.0, green: 0.97, blue: 0.86, alpha: 0.96))
    }

    // MARK: - 3. Aurora Prism Silk Ribbons & 6-Ray Flares

    private static func drawAuroraSilk(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let w = size.width
        let h = size.height
        let steps = 96
        let startX: CGFloat = 34
        let endX: CGFloat = w - 34

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = startX + (endX - startX) * t
            let waveA = sin(t * .pi * 1.9 + 0.4)
            let waveB = cos(t * .pi * 3.2 - 0.5)
            let spineY = h * 0.64 - waveA * 68.0 + waveB * 22.0
            let heightUp: CGFloat = 148.0 + 46.0 * sin(t * .pi * 2.7 + 1.1)
            let tiltX: CGFloat = -22.0 + 10.0 * waveA

            // Smooth horizontal bell & ripple modulation so silk curtain shimmers like folded fabric
            let edgeFade = sin(t * .pi)
            let ripple = 0.45 + 0.55 * pow(abs(sin(t * .pi * 5.2 + 0.7)), 1.3)
            let intensity = pow(edgeFade, 0.75) * ripple

            // Color interpolation: Emerald (0.18, 0.98, 0.74) -> Cyan (0.24, 0.86, 1.0) -> Violet (0.76, 0.42, 1.0)
            let r: CGFloat
            let g: CGFloat
            let b: CGFloat
            if t < 0.52 {
                let u = t / 0.52
                r = 0.18 + (0.24 - 0.18) * u
                g = 0.98 + (0.86 - 0.98) * u
                b = 0.74 + (1.00 - 0.74) * u
            } else {
                let u = (t - 0.52) / 0.48
                r = 0.24 + (0.78 - 0.24) * u
                g = 0.86 + (0.42 - 0.86) * u
                b = 1.00
            }

            let topPt = CGPoint(x: x + tiltX, y: max(36, spineY - heightUp))
            let botPt = CGPoint(x: x - tiltX * 0.12, y: min(h - 36, spineY + 26))

            let band = CGMutablePath()
            let bandW: CGFloat = 11.5
            band.move(to: CGPoint(x: topPt.x - bandW, y: topPt.y))
            band.addLine(to: CGPoint(x: topPt.x + bandW, y: topPt.y))
            band.addLine(to: CGPoint(x: botPt.x + bandW * 0.7, y: botPt.y))
            band.addLine(to: CGPoint(x: botPt.x - bandW * 0.7, y: botPt.y))
            band.closeSubpath()

            cg.saveGState()
            cg.addPath(band)
            cg.clip()
            let peakA = 0.26 * intensity
            if let grad = CGGradient(
                colorsSpace: cs,
                colors: [
                    CGColor(red: r, green: g, blue: b, alpha: 0.0),
                    CGColor(red: r, green: g, blue: b, alpha: peakA * 0.55),
                    CGColor(red: r, green: g, blue: b, alpha: peakA),
                    CGColor(red: r, green: g, blue: b, alpha: 0.0)
                ] as CFArray,
                locations: [0.0, 0.48, 0.84, 1.0]
            ) {
                cg.drawLinearGradient(grad, start: topPt, end: botPt, options: [])
            }
            cg.restoreGState()
        }

        applySoftBorderEnvelope(cg: cg, size: size, insetX: 46, insetY: 46)
    }

    private static func drawAuroraFlare(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        if let halo = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.90, green: 1.0, blue: 1.0, alpha: 0.65),
                CGColor(red: 0.42, green: 0.90, blue: 1.0, alpha: 0.28),
                CGColor(red: 0.68, green: 0.48, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.42, 1.0]
        ) {
            cg.drawRadialGradient(halo, startCenter: c, startRadius: 0, endCenter: c, endRadius: 24, options: [])
        }
        // 6-ray star flare (3 axes separated by 60 deg)
        for deg in [0.0, 60.0, 120.0] {
            cg.saveGState()
            cg.translateBy(x: c.x, y: c.y)
            cg.rotate(by: CGFloat(deg * .pi / 180.0))
            let blade = CGMutablePath()
            blade.move(to: CGPoint(x: -44, y: 0))
            blade.addQuadCurve(to: CGPoint(x: 44, y: 0), control: CGPoint(x: 0, y: -2.6))
            blade.addQuadCurve(to: CGPoint(x: -44, y: 0), control: CGPoint(x: 0, y: 2.6))
            blade.closeSubpath()
            cg.addPath(blade)
            cg.setFillColor(CGColor(red: 0.96, green: 1.0, blue: 1.0, alpha: 0.92))
            cg.fillPath()
            cg.restoreGState()
        }
    }

    // MARK: - 4. Sakura Petals (Front Detailed, 3D Side-Curled, Soft Bokeh)

    private static func drawSakuraFrontPetal(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        cg.saveGState()
        cg.translateBy(x: 64, y: 64)
        cg.rotate(by: -0.16)

        let petal = CGMutablePath()
        petal.move(to: CGPoint(x: 0, y: 44))
        petal.addCurve(to: CGPoint(x: 33, y: -20), control1: CGPoint(x: 34, y: 30), control2: CGPoint(x: 44, y: -2))
        petal.addQuadCurve(to: CGPoint(x: 10, y: -40), control: CGPoint(x: 24, y: -38))
        petal.addLine(to: CGPoint(x: 0, y: -26))
        petal.addLine(to: CGPoint(x: -10, y: -40))
        petal.addQuadCurve(to: CGPoint(x: -33, y: -20), control: CGPoint(x: -24, y: -38))
        petal.addCurve(to: CGPoint(x: 0, y: 44), control1: CGPoint(x: -44, y: -2), control2: CGPoint(x: -34, y: 30))
        petal.closeSubpath()

        cg.saveGState()
        cg.addPath(petal)
        cg.clip()
        if let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.48, blue: 0.70, alpha: 0.96),
                CGColor(red: 1.0, green: 0.78, blue: 0.88, alpha: 0.96),
                CGColor(red: 1.0, green: 0.95, blue: 0.97, alpha: 0.98)
            ] as CFArray,
            locations: [0.0, 0.50, 1.0]
        ) {
            cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 44), end: CGPoint(x: 0, y: -42), options: [])
        }

        // Delicate petal veins
        cg.setStrokeColor(CGColor(red: 0.96, green: 0.36, blue: 0.62, alpha: 0.30))
        cg.setLineWidth(1.4)
        cg.setLineCap(.round)
        for dx in [-14.0, 0.0, 14.0] {
            let vein = CGMutablePath()
            vein.move(to: CGPoint(x: 0, y: 36))
            vein.addQuadCurve(to: CGPoint(x: dx, y: -18), control: CGPoint(x: dx * 0.7, y: 12))
            cg.addPath(vein)
            cg.strokePath()
        }
        cg.restoreGState()
        cg.restoreGState()
    }

    private static func drawSakuraCurledPetal(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        cg.saveGState()
        cg.translateBy(x: 64, y: 64)
        cg.rotate(by: 0.36)

        let body = CGMutablePath()
        body.move(to: CGPoint(x: -6, y: 46))
        body.addCurve(to: CGPoint(x: 16, y: -42), control1: CGPoint(x: 34, y: 20), control2: CGPoint(x: 34, y: -22))
        body.addQuadCurve(to: CGPoint(x: 4, y: -44), control: CGPoint(x: 10, y: -48))
        body.addCurve(to: CGPoint(x: -6, y: 46), control1: CGPoint(x: -10, y: -12), control2: CGPoint(x: -18, y: 22))
        body.closeSubpath()

        cg.saveGState()
        cg.addPath(body)
        cg.clip()
        if let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.96, green: 0.42, blue: 0.66, alpha: 0.95),
                CGColor(red: 1.0, green: 0.76, blue: 0.87, alpha: 0.95),
                CGColor(red: 1.0, green: 0.95, blue: 0.98, alpha: 0.98)
            ] as CFArray,
            locations: [0.0, 0.55, 1.0]
        ) {
            cg.drawLinearGradient(grad, start: CGPoint(x: -8, y: 46), end: CGPoint(x: 16, y: -44), options: [])
        }
        cg.restoreGState()

        // Inner bright curled edge rim
        let rim = CGMutablePath()
        rim.move(to: CGPoint(x: -4, y: 38))
        rim.addCurve(to: CGPoint(x: 6, y: -38), control1: CGPoint(x: 8, y: 12), control2: CGPoint(x: 12, y: -16))
        cg.addPath(rim)
        cg.setStrokeColor(CGColor(red: 1.0, green: 0.96, blue: 0.98, alpha: 0.85))
        cg.setLineWidth(2.4)
        cg.setLineCap(.round)
        cg.strokePath()
        cg.restoreGState()
    }

    private static func drawSakuraBokehPetal(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        cg.saveGState()
        cg.translateBy(x: 64, y: 64)
        cg.rotate(by: 0.24)
        let center = CGPoint.zero

        let bokeh = CGMutablePath()
        bokeh.move(to: CGPoint(x: 0, y: 50))
        bokeh.addCurve(to: CGPoint(x: 40, y: -22), control1: CGPoint(x: 42, y: 36), control2: CGPoint(x: 52, y: -2))
        bokeh.addQuadCurve(to: CGPoint(x: 12, y: -46), control: CGPoint(x: 28, y: -44))
        bokeh.addLine(to: CGPoint(x: 0, y: -30))
        bokeh.addLine(to: CGPoint(x: -12, y: -46))
        bokeh.addQuadCurve(to: CGPoint(x: -40, y: -22), control: CGPoint(x: -28, y: -44))
        bokeh.addCurve(to: CGPoint(x: 0, y: 50), control1: CGPoint(x: -52, y: -2), control2: CGPoint(x: -42, y: 36))
        bokeh.closeSubpath()

        cg.setShadow(offset: .zero, blur: 10, color: CGColor(red: 1.0, green: 0.72, blue: 0.84, alpha: 0.45))
        cg.addPath(bokeh)
        cg.clip()
        if let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.88, blue: 0.93, alpha: 0.44),
                CGColor(red: 1.0, green: 0.70, blue: 0.84, alpha: 0.26),
                CGColor(red: 1.0, green: 0.70, blue: 0.84, alpha: 0.04)
            ] as CFArray,
            locations: [0.0, 0.58, 1.0]
        ) {
            cg.drawRadialGradient(grad, startCenter: center, startRadius: 4, endCenter: center, endRadius: 54, options: [])
        }
        cg.restoreGState()
    }

    // MARK: - 5. Detailed Dendritic Snow Crystals & Star Plates

    private static func drawSnowDendriteCrystal(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: 64, y: 64)
        if let frost = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.92, green: 0.97, blue: 1.0, alpha: 0.34),
                CGColor(red: 0.86, green: 0.94, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        ) {
            cg.drawRadialGradient(frost, startCenter: c, startRadius: 0, endCenter: c, endRadius: 46, options: [])
        }

        cg.setStrokeColor(CGColor(red: 0.96, green: 0.99, blue: 1.0, alpha: 0.98))
        cg.setLineCap(.round)
        cg.setLineJoin(.round)

        // Inner crisp hexagon
        cg.addPath(regularHexagonPath(center: c, radius: 10.5, cornerSoftness: 0))
        cg.setLineWidth(2.0)
        cg.strokePath()

        // 6 fractal dendritic arms
        for k in 0..<6 {
            cg.saveGState()
            cg.translateBy(x: c.x, y: c.y)
            cg.rotate(by: CGFloat(k) * (.pi / 3.0))

            // Primary crystal spine
            cg.setLineWidth(2.8)
            cg.move(to: .zero)
            cg.addLine(to: CGPoint(x: 0, y: 51))
            cg.strokePath()

            // Three tiers of symmetric 60-degree crystal side branches
            let twigs: [(r: CGFloat, len: CGFloat, w: CGFloat)] = [
                (17, 15, 2.2),
                (30, 12.5, 2.0),
                (41, 8, 1.7)
            ]
            for twig in twigs {
                cg.setLineWidth(twig.w)
                let dx = twig.len * 0.866
                let dy = twig.len * 0.50
                cg.move(to: CGPoint(x: 0, y: twig.r))
                cg.addLine(to: CGPoint(x: -dx, y: twig.r + dy))
                cg.move(to: CGPoint(x: 0, y: twig.r))
                cg.addLine(to: CGPoint(x: dx, y: twig.r + dy))
                cg.strokePath()
            }
            cg.restoreGState()
        }
    }

    private static func drawSnowStarPlateCrystal(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: 64, y: 64)
        if let frost = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.94, green: 0.98, blue: 1.0, alpha: 0.36),
                CGColor(red: 0.88, green: 0.95, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        ) {
            cg.drawRadialGradient(frost, startCenter: c, startRadius: 0, endCenter: c, endRadius: 42, options: [])
        }

        for k in 0..<6 {
            cg.saveGState()
            cg.translateBy(x: c.x, y: c.y)
            cg.rotate(by: CGFloat(k) * (.pi / 3.0))
            let needle = CGMutablePath()
            needle.move(to: CGPoint(x: 0, y: 4))
            needle.addLine(to: CGPoint(x: -6.5, y: 24))
            needle.addLine(to: CGPoint(x: 0, y: 45))
            needle.addLine(to: CGPoint(x: 6.5, y: 24))
            needle.closeSubpath()
            cg.addPath(needle)
            cg.setFillColor(CGColor(red: 0.96, green: 0.99, blue: 1.0, alpha: 0.94))
            cg.fillPath()
            cg.restoreGState()

            // Interleaved short 30-degree crystal teeth
            cg.saveGState()
            cg.translateBy(x: c.x, y: c.y)
            cg.rotate(by: CGFloat(k) * (.pi / 3.0) + (.pi / 6.0))
            cg.setStrokeColor(CGColor(red: 0.92, green: 0.97, blue: 1.0, alpha: 0.85))
            cg.setLineWidth(2.2)
            cg.setLineCap(.round)
            cg.move(to: CGPoint(x: 0, y: 6))
            cg.addLine(to: CGPoint(x: 0, y: 22))
            cg.strokePath()
            cg.restoreGState()
        }
    }

    // MARK: - 6. Anamorphic Cross-Flares & 8-Point Starlights

    private static func drawAnamorphicCrossFlare(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        if let halo = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.72),
                CGColor(red: 0.66, green: 0.88, blue: 1.0, alpha: 0.28),
                CGColor(red: 0.66, green: 0.88, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.36, 1.0]
        ) {
            cg.drawRadialGradient(halo, startCenter: c, startRadius: 0, endCenter: c, endRadius: 24, options: [])
        }
        // Horizontal wide cinema spike + shorter vertical spike + faint diagonal X micro-rays
        drawFourPointNeedleStar(in: cg, center: c, rx: 66, ry: 46, waist: 2.0, color: CGColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 0.98))

        cg.saveGState()
        cg.translateBy(x: c.x, y: c.y)
        cg.rotate(by: .pi / 4.0)
        drawFourPointNeedleStar(in: cg, center: .zero, rx: 22, ry: 22, waist: 1.1, color: CGColor(red: 0.88, green: 0.95, blue: 1.0, alpha: 0.75))
        cg.restoreGState()
    }

    private static func drawOctaJewelFlare(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        if let halo = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.99, blue: 0.94, alpha: 0.68),
                CGColor(red: 1.0, green: 0.88, blue: 0.72, alpha: 0.24),
                CGColor(red: 0.82, green: 0.90, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.38, 1.0]
        ) {
            cg.drawRadialGradient(halo, startCenter: c, startRadius: 0, endCenter: c, endRadius: 24, options: [])
        }
        drawFourPointNeedleStar(in: cg, center: c, rx: 54, ry: 54, waist: 2.2, color: CGColor(red: 1, green: 0.99, blue: 0.96, alpha: 0.98))

        cg.saveGState()
        cg.translateBy(x: c.x, y: c.y)
        cg.rotate(by: .pi / 4.0)
        drawFourPointNeedleStar(in: cg, center: .zero, rx: 34, ry: 34, waist: 1.8, color: CGColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 0.88))
        cg.restoreGState()
    }

    // MARK: - 7. Upward-Streaking Fire Sparks & Ember Shards

    /// Head at top-right `(68, 22)` tapering to bottom-left `(54, 144)` for `emissionLongitude="1.45"` rad (~83 deg upward).
    private static func drawEmberStreak(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let head = CGPoint(x: 68, y: 22)
        let tail = CGPoint(x: 54, y: 144)

        // Outer molten orange glow along tapered wake
        cg.saveGState()
        let outer = CGMutablePath()
        outer.move(to: CGPoint(x: head.x - 6.5, y: head.y))
        outer.addLine(to: CGPoint(x: head.x + 6.5, y: head.y))
        outer.addQuadCurve(to: tail, control: CGPoint(x: 66, y: 84))
        outer.addQuadCurve(to: CGPoint(x: head.x - 6.5, y: head.y), control: CGPoint(x: 56, y: 84))
        outer.closeSubpath()
        cg.addPath(outer)
        cg.clip()
        if let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.95, blue: 0.70, alpha: 0.75),
                CGColor(red: 1.0, green: 0.48, blue: 0.12, alpha: 0.45),
                CGColor(red: 0.92, green: 0.20, blue: 0.04, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.35, 1.0]
        ) {
            cg.drawLinearGradient(grad, start: head, end: tail, options: [.drawsBeforeStartLocation])
        }
        cg.restoreGState()

        // Inner sharp spark core
        cg.saveGState()
        let core = CGMutablePath()
        core.move(to: CGPoint(x: head.x - 2.4, y: head.y))
        core.addLine(to: CGPoint(x: head.x + 2.4, y: head.y))
        core.addQuadCurve(to: CGPoint(x: tail.x + 2, y: tail.y - 14), control: CGPoint(x: 64, y: 78))
        core.closeSubpath()
        cg.addPath(core)
        cg.clip()
        if let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.99, blue: 0.90, alpha: 1.0),
                CGColor(red: 1.0, green: 0.72, blue: 0.22, alpha: 0.85),
                CGColor(red: 1.0, green: 0.36, blue: 0.08, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.45, 1.0]
        ) {
            cg.drawLinearGradient(grad, start: head, end: CGPoint(x: tail.x + 2, y: tail.y - 14), options: [])
        }
        cg.restoreGState()

        if let headGlow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.98, blue: 0.88, alpha: 0.96),
                CGColor(red: 1.0, green: 0.62, blue: 0.20, alpha: 0.45),
                CGColor(red: 1.0, green: 0.35, blue: 0.05, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.40, 1.0]
        ) {
            cg.drawRadialGradient(headGlow, startCenter: head, startRadius: 0, endCenter: head, endRadius: 13, options: [])
        }
    }

    private static func drawEmberShard(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let c = CGPoint(x: 48, y: 48)
        if let glow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.56, blue: 0.14, alpha: 0.52),
                CGColor(red: 1.0, green: 0.34, blue: 0.06, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        ) {
            cg.drawRadialGradient(glow, startCenter: c, startRadius: 0, endCenter: c, endRadius: 28, options: [])
        }

        // Irregular polygonal glowing ember flake
        let shard = CGMutablePath()
        let pts = [
            CGPoint(x: 48, y: 26),
            CGPoint(x: 68, y: 38),
            CGPoint(x: 62, y: 63),
            CGPoint(x: 41, y: 69),
            CGPoint(x: 29, y: 47)
        ]
        shard.move(to: pts[0])
        for pt in pts.dropFirst() { shard.addLine(to: pt) }
        shard.closeSubpath()

        cg.saveGState()
        cg.addPath(shard)
        cg.clip()
        if let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.96, blue: 0.72, alpha: 1.0),
                CGColor(red: 1.0, green: 0.54, blue: 0.14, alpha: 0.95),
                CGColor(red: 0.85, green: 0.22, blue: 0.06, alpha: 0.90)
            ] as CFArray,
            locations: [0.0, 0.50, 1.0]
        ) {
            cg.drawLinearGradient(grad, start: CGPoint(x: 66, y: 32), end: CGPoint(x: 34, y: 66), options: [])
        }
        cg.restoreGState()
    }

    // MARK: - 8. Bioluminescent Firefly Wisps & Hexagonal Aperture Bokeh

    private static func drawFireflyWisp(_ cg: CGContext, _ size: CGSize) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let head = CGPoint(x: 80, y: 40)
        let tail = CGPoint(x: 24, y: 102)

        // S-curve glowing wake behind firefly orb
        cg.saveGState()
        let wake = CGMutablePath()
        wake.move(to: CGPoint(x: head.x - 4, y: head.y - 4))
        wake.addCurve(to: tail, control1: CGPoint(x: 66, y: 74), control2: CGPoint(x: 40, y: 74))
        wake.addCurve(to: CGPoint(x: head.x + 5, y: head.y + 5), control1: CGPoint(x: 46, y: 80), control2: CGPoint(x: 72, y: 78))
        wake.closeSubpath()
        cg.addPath(wake)
        cg.clip()
        if let grad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.96, green: 1.0, blue: 0.62, alpha: 0.85),
                CGColor(red: 0.72, green: 0.98, blue: 0.36, alpha: 0.42),
                CGColor(red: 0.55, green: 0.92, blue: 0.28, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.45, 1.0]
        ) {
            cg.drawLinearGradient(grad, start: head, end: tail, options: [.drawsBeforeStartLocation])
        }
        cg.restoreGState()

        if let glow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 1.0, blue: 0.88, alpha: 0.98),
                CGColor(red: 0.86, green: 1.0, blue: 0.48, alpha: 0.52),
                CGColor(red: 0.64, green: 0.94, blue: 0.32, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.32, 1.0]
        ) {
            cg.drawRadialGradient(glow, startCenter: head, startRadius: 0, endCenter: head, endRadius: 24, options: [])
        }
    }

    private static func drawHexagonalBokeh(_ cg: CGContext, _ size: CGSize) {
        let c = CGPoint(x: 64, y: 64)
        let hex = regularHexagonPath(center: c, radius: 44, cornerSoftness: 3.5)

        cg.saveGState()
        cg.addPath(hex)
        cg.setFillColor(CGColor(red: 0.92, green: 0.98, blue: 0.56, alpha: 0.22))
        cg.fillPath()

        cg.addPath(hex)
        cg.setStrokeColor(CGColor(red: 0.98, green: 1.0, blue: 0.72, alpha: 0.52))
        cg.setLineWidth(2.8)
        cg.strokePath()
        cg.restoreGState()
    }

    // MARK: - Shared Vector Helpers

    private static func drawFourPointNeedleStar(
        in cg: CGContext,
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        waist: CGFloat,
        color: CGColor
    ) {
        let star = CGMutablePath()
        star.move(to: CGPoint(x: center.x, y: center.y - ry))
        star.addQuadCurve(to: CGPoint(x: center.x + rx, y: center.y), control: CGPoint(x: center.x + waist, y: center.y - waist))
        star.addQuadCurve(to: CGPoint(x: center.x, y: center.y + ry), control: CGPoint(x: center.x + waist, y: center.y + waist))
        star.addQuadCurve(to: CGPoint(x: center.x - rx, y: center.y), control: CGPoint(x: center.x - waist, y: center.y + waist))
        star.addQuadCurve(to: CGPoint(x: center.x, y: center.y - ry), control: CGPoint(x: center.x - waist, y: center.y - waist))
        star.closeSubpath()
        cg.addPath(star)
        cg.setFillColor(color)
        cg.fillPath()
    }

    private static func regularHexagonPath(center: CGPoint, radius: CGFloat, cornerSoftness: CGFloat) -> CGPath {
        var pts: [CGPoint] = []
        pts.reserveCapacity(6)
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3.0) - (.pi / 6.0)
            pts.append(CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
        }
        let path = CGMutablePath()
        guard cornerSoftness > 0.2 else {
            path.move(to: pts[0])
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            path.closeSubpath()
            return path
        }
        let count = pts.count
        for i in 0..<count {
            let prev = pts[(i + count - 1) % count]
            let curr = pts[i]
            let next = pts[(i + 1) % count]
            let v1 = CGPoint(x: prev.x - curr.x, y: prev.y - curr.y)
            let v2 = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
            let d1 = max(1, hypot(v1.x, v1.y))
            let d2 = max(1, hypot(v2.x, v2.y))
            let p1 = CGPoint(x: curr.x + v1.x / d1 * cornerSoftness, y: curr.y + v1.y / d1 * cornerSoftness)
            let p2 = CGPoint(x: curr.x + v2.x / d2 * cornerSoftness, y: curr.y + v2.y / d2 * cornerSoftness)
            if i == 0 {
                path.move(to: p1)
            } else {
                path.addLine(to: p1)
            }
            path.addQuadCurve(to: p2, control: curr)
        }
        path.closeSubpath()
        return path
    }

    /// Attenuates image alpha smoothly to zero at all 4 borders via `destinationIn` passes,
    /// eliminating any rectangular bounding-box clipping during CALayer drift/scale animations.
    private static func applySoftBorderEnvelope(cg: CGContext, size: CGSize, insetX: CGFloat, insetY: CGFloat) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let opaque = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let clear = CGColor(red: 1, green: 1, blue: 1, alpha: 0)
        let w = size.width
        let h = size.height

        cg.saveGState()
        cg.setBlendMode(.destinationIn)
        if let hGrad = CGGradient(
            colorsSpace: cs,
            colors: [clear, opaque, opaque, clear] as CFArray,
            locations: [0.0, Double(insetX / max(1, w)), Double(1.0 - insetX / max(1, w)), 1.0] as [CGFloat]
        ) {
            cg.drawLinearGradient(hGrad, start: .zero, end: CGPoint(x: w, y: 0), options: [])
        }
        if let vGrad = CGGradient(
            colorsSpace: cs,
            colors: [clear, opaque, opaque, clear] as CFArray,
            locations: [0.0, Double(insetY / max(1, h)), Double(1.0 - insetY / max(1, h)), 1.0] as [CGFloat]
        ) {
            cg.drawLinearGradient(vGrad, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        }
        cg.restoreGState()
    }
}
