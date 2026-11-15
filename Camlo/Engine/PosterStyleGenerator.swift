//
//  PosterStyleGenerator.swift
//  Camlo · 开幕
//
//  Clean-room PosterKit style engine: clock typography (PRTimeFontIdentifier*),
//  clock-region & full-canvas palette extraction, 1-tap CoreImage moonlight grade,
//  and binary NSKeyedArchiver plist synthesis for Lock & Home Screen pairing.
//

import Foundation
import UIKit
import SwiftUI
import CoreImage
import ImageIO

// MARK: - Clock Typography

enum ClockFontStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case soft
    case classic
    case rounded
    case serif
    case stencil
    case rail

    var id: String { rawValue }

    var posterKitIdentifier: String {
        switch self {
        case .soft:    return "PRTimeFontIdentifierSoft"
        case .classic: return "PRTimeFontIdentifierDefault"
        case .rounded: return "PRTimeFontIdentifierRounded"
        case .serif:   return "PRTimeFontIdentifierNewYork"
        case .stencil: return "PRTimeFontIdentifierStencil"
        case .rail:    return "PRTimeFontIdentifierRail"
        }
    }

    var title: String {
        switch self {
        case .soft:    return Bi("圆润柔光", "Soft")
        case .classic: return Bi("经典无衬", "Classic")
        case .rounded: return Bi("现代几何", "Rounded")
        case .serif:   return Bi("文艺衬线", "Serif")
        case .stencil: return Bi("先锋镂空", "Stencil")
        case .rail:    return Bi("修长轨道", "Rail")
        }
    }

    static func from(posterKitIdentifier: String?) -> ClockFontStyle {
        guard let raw = posterKitIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .soft
        }
        for candidate in Self.allCases where candidate.posterKitIdentifier == raw {
            return candidate
        }
        let lower = raw.lowercased()
        if lower.contains("serif") || lower.contains("newyork") { return .serif }
        if lower.contains("rounded") { return .rounded }
        if lower.contains("stencil") { return .stencil }
        if lower.contains("rail") { return .rail }
        if lower.contains("default") || lower.contains("system") { return .classic }
        return .soft
    }

    func swiftUIFont(size: CGFloat) -> Font {
        switch self {
        case .soft:
            return .system(size: size, weight: .semibold, design: .rounded)
        case .classic:
            return .system(size: size, weight: .bold, design: .default)
        case .rounded:
            return .system(size: size, weight: .heavy, design: .rounded)
        case .serif:
            return .system(size: size, weight: .semibold, design: .serif)
        case .stencil:
            return .system(size: size, weight: .black, design: .default)
        case .rail:
            return .system(size: size, weight: .light, design: .default)
        }
    }

    var fontWidth: Font.Width {
        switch self {
        case .stencil: return .expanded
        case .rail:    return .condensed
        default:       return .standard
        }
    }

    var letterSpacing: CGFloat {
        switch self {
        case .stencil: return 1.0
        case .rail:    return 0.6
        case .serif:   return 0.0
        default:       return -0.8
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        let baseWeight: UIFont.Weight
        let design: UIFontDescriptor.SystemDesign
        let widthTrait: CGFloat

        switch self {
        case .soft:
            baseWeight = .semibold
            design = .rounded
            widthTrait = 0.0
        case .classic:
            baseWeight = .bold
            design = .default
            widthTrait = 0.0
        case .rounded:
            baseWeight = .heavy
            design = .rounded
            widthTrait = 0.0
        case .serif:
            baseWeight = .semibold
            design = .serif
            widthTrait = 0.0
        case .stencil:
            baseWeight = .black
            design = .default
            widthTrait = 0.25
        case .rail:
            baseWeight = .light
            design = .default
            widthTrait = -0.30
        }

        let sysFont = UIFont.systemFont(ofSize: size, weight: baseWeight)
        var descriptor = sysFont.fontDescriptor.withDesign(design) ?? sysFont.fontDescriptor
        if widthTrait != 0.0 {
            descriptor = descriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.width: widthTrait]
            ])
        }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Clock Color & Home Pairing Modes

enum ClockColorMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case smartContrast
    case wallpaperTint
    case systemAuto
    case pureWhite
    case obsidianInk
    case champagneGold
    case iceCyan
    case roseQuartz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartContrast: return Bi("智能高反差", "Smart Contrast")
        case .wallpaperTint: return Bi("壁纸同色系", "Wallpaper Tint")
        case .systemAuto:    return Bi("系统自适应", "System Auto")
        case .pureWhite:     return Bi("纯净亮白", "Pure White")
        case .obsidianInk:   return Bi("曜石深墨", "Obsidian Ink")
        case .champagneGold: return Bi("流光香槟", "Champagne")
        case .iceCyan:       return Bi("冰川青蓝", "Ice Cyan")
        case .roseQuartz:    return Bi("暮光樱粉", "Rose Quartz")
        }
    }
}

enum HomeScreenPairingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case legibilityBlur
    case clearMatch
    case matchedGradient
    case matchedSolid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .legibilityBlur:  return Bi("原生柔焦虚化", "Soft-Focus Blur")
        case .clearMatch:      return Bi("清晰同图直通", "Clear Lock Match")
        case .matchedGradient: return Bi("智能同色渐变", "Matched Gradient")
        case .matchedSolid:    return Bi("同色暗调纯色", "Matched Solid")
        }
    }

    var subtitle: String {
        switch self {
        case .legibilityBlur:
            return Bi("开启 iOS 原生主屏毛玻璃景深虚化，图标清晰不杂乱", "Enables native PosterKit Home Screen legibility blur")
        case .clearMatch:
            return Bi("主屏与锁屏保持同一清晰动态壁纸", "Keeps crisp Lock Screen wallpaper on Home Screen")
        case .matchedGradient:
            return Bi("自动提取壁纸主色生成原生主屏氛围渐变", "Generates a native PosterKit Home Screen color gradient")
        case .matchedSolid:
            return Bi("提取壁纸暗调主色作为极简主屏纯色背板", "Pairs Lock Screen with a harmonious deep solid backdrop")
        }
    }
}

struct PosterStyleSpec: Equatable, Codable, Sendable {
    var clockFont: ClockFontStyle = .soft
    var clockColorMode: ClockColorMode = .systemAuto
    var homePairing: HomeScreenPairingMode = .legibilityBlur
}

// MARK: - RGBA Color & Palette Metrics

struct RGBAColor: Equatable, Codable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = max(0, min(1, r))
        self.g = max(0, min(1, g))
        self.b = max(0, min(1, b))
        self.a = max(0, min(1, a))
    }

    var uiColor: UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexRGBString: String {
        String(
            format: "#%02X%02X%02X",
            Int((r * 255.0).rounded()),
            Int((g * 255.0).rounded()),
            Int((b * 255.0).rounded())
        )
    }

    var hexRGBAString: String {
        String(
            format: "#%02X%02X%02X%02X",
            Int((r * 255.0).rounded()),
            Int((g * 255.0).rounded()),
            Int((b * 255.0).rounded()),
            Int((a * 255.0).rounded())
        )
    }

    var hsbComponents: (h: Double, s: Double, b: Double) {
        let maxV = max(r, max(g, b))
        let minV = min(r, min(g, b))
        let delta = maxV - minV
        var h: Double = 0
        if delta > 1e-6 {
            if maxV == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
            } else if maxV == g {
                h = ((b - r) / delta) + 2.0
            } else {
                h = ((r - g) / delta) + 4.0
            }
            h /= 6.0
            if h < 0 { h += 1.0 }
        }
        let s = maxV > 1e-6 ? (delta / maxV) : 0.0
        return (h, s, maxV)
    }

    static func fromHSB(h: Double, s: Double, b: Double, a: Double = 1.0) -> RGBAColor {
        let hue = ((h.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
        let sat = max(0, min(1, s))
        let bri = max(0, min(1, b))
        let c = bri * sat
        let x = c * (1.0 - abs((hue * 6.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = bri - c
        let rp, gp, bp: Double
        switch hue * 6.0 {
        case ..<1: (rp, gp, bp) = (c, x, 0)
        case ..<2: (rp, gp, bp) = (x, c, 0)
        case ..<3: (rp, gp, bp) = (0, c, x)
        case ..<4: (rp, gp, bp) = (0, x, c)
        case ..<5: (rp, gp, bp) = (x, 0, c)
        default:   (rp, gp, bp) = (c, 0, x)
        }
        return RGBAColor(r: rp + m, g: gp + m, b: bp + m, a: a)
    }

    var posterColorIdentifier: String {
        let (h, s, bri) = hsbComponents
        return String(format: "default-%.5f:%.5f:%.5f:%.2f", h, s, bri, a)
    }

    func uiColorArchiveDict(classUID: Any) -> [String: Any] {
        let nsrgbString = String(format: "%.3f %.3f %.3f", r, g, b)
        return [
            "$class": classUID,
            "UIColorComponentCount": 4,
            "UIRed": r,
            "UIGreen": g,
            "UIBlue": b,
            "UIAlpha": a,
            "UIRed-Double": r,
            "UIGreen-Double": g,
            "UIBlue-Double": b,
            "NSRGB": Data(nsrgbString.utf8),
            "NSColorSpace": 2
        ]
    }

    func bsColorArchiveDict(classUID: Any) -> [String: Any] {
        [
            "$class": classUID,
            "r": r,
            "g": g,
            "b": b,
            "a": a
        ]
    }

    static func fromUIColorDict(_ dict: [String: Any]) -> RGBAColor? {
        if let r = dict["UIRed-Double"] as? Double,
           let g = dict["UIGreen-Double"] as? Double,
           let b = dict["UIBlue-Double"] as? Double {
            let a = (dict["UIAlpha"] as? Double) ?? 1.0
            return RGBAColor(r: r, g: g, b: b, a: a)
        }
        if let r = dict["UIRed"] as? Double,
           let g = dict["UIGreen"] as? Double,
           let b = dict["UIBlue"] as? Double {
            let a = (dict["UIAlpha"] as? Double) ?? 1.0
            return RGBAColor(r: r, g: g, b: b, a: a)
        }
        if let nsrgb = dict["NSRGB"] as? Data,
           let str = String(data: nsrgb, encoding: .utf8) {
            let nums = str
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0")))
                .split(separator: " ")
                .compactMap { Double($0) }
            if nums.count >= 3 {
                return RGBAColor(r: nums[0], g: nums[1], b: nums[2], a: nums.count >= 4 ? nums[3] : 1.0)
            }
        }
        return nil
    }
}

struct WallpaperPaletteMetrics: Equatable, Codable, Sendable {
    var clockLuminance: Double
    var clockContrast: Double
    var averageColor: RGBAColor
    var averageContrast: Double
    var accentColor: RGBAColor
    var smartContrastClockColor: RGBAColor
    var wallpaperTintClockColor: RGBAColor
    var matchedGradientColor: RGBAColor
    var matchedSolidColor: RGBAColor

    static let neutralFallback = WallpaperPaletteMetrics(
        clockLuminance: 0.35,
        clockContrast: 0.24,
        averageColor: RGBAColor(r: 0.28, g: 0.34, b: 0.48),
        averageContrast: 0.22,
        accentColor: RGBAColor(r: 0.42, g: 0.56, b: 0.92),
        smartContrastClockColor: RGBAColor(r: 0.96, g: 0.97, b: 1.0, a: 0.96),
        wallpaperTintClockColor: RGBAColor(r: 0.80, g: 0.88, b: 1.0, a: 0.95),
        matchedGradientColor: RGBAColor(r: 0.22, g: 0.34, b: 0.62),
        matchedSolidColor: RGBAColor(r: 0.12, g: 0.16, b: 0.26)
    )
}

struct ParsedPosterStyleSummary: Sendable {
    var clockFontIdentifier: String?
    var clockFontStyle: ClockFontStyle
    var clockColor: RGBAColor?
    var contentsLuminance: Double?
    var homeAppearanceType: Int
    var hasLegibilityBlur: Bool
    var homeTintColor: RGBAColor?

    var homeModeSummary: HomeScreenPairingMode {
        switch homeAppearanceType {
        case 1:  return .matchedSolid
        case 2:  return .matchedGradient
        default: return hasLegibilityBlur ? .legibilityBlur : .clearMatch
        }
    }
}

// MARK: - PosterStyleGenerator

enum PosterStyleGenerator {
    nonisolated private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: Palette Analysis

    nonisolated static func analyzePalette(of image: UIImage) -> WallpaperPaletteMetrics {
        guard let cgImage = normalizedCGImage(for: image) else {
            return .neutralFallback
        }

        let sampleW = 64
        let sampleH = 128
        var rgba = [UInt8](repeating: 0, count: sampleW * sampleH * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: &rgba,
            width: sampleW,
            height: sampleH,
            bitsPerComponent: 8,
            bytesPerRow: sampleW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return .neutralFallback
        }

        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))

        let clockMinX = Int(Double(sampleW) * 0.14)
        let clockMaxX = Int(Double(sampleW) * 0.86)
        let clockMinY = Int(Double(sampleH) * 0.09)
        let clockMaxY = Int(Double(sampleH) * 0.29)

        var fullSumR: Double = 0
        var fullSumG: Double = 0
        var fullSumB: Double = 0
        var fullLumSum: Double = 0
        var fullLumSqSum: Double = 0
        var fullCount: Double = 0

        var clockLumSum: Double = 0
        var clockLumSqSum: Double = 0
        var clockCount: Double = 0

        var accentSumR: Double = 0
        var accentSumG: Double = 0
        var accentSumB: Double = 0
        var accentWeightSum: Double = 0

        for y in 0..<sampleH {
            for x in 0..<sampleW {
                let offset = (y * sampleW + x) * 4
                let r = Double(rgba[offset]) / 255.0
                let g = Double(rgba[offset + 1]) / 255.0
                let b = Double(rgba[offset + 2]) / 255.0
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b

                fullSumR += r
                fullSumG += g
                fullSumB += b
                fullLumSum += lum
                fullLumSqSum += lum * lum
                fullCount += 1.0

                if x >= clockMinX && x <= clockMaxX && y >= clockMinY && y <= clockMaxY {
                    clockLumSum += lum
                    clockLumSqSum += lum * lum
                    clockCount += 1.0
                }

                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let sat = maxC > 1e-4 ? (maxC - minC) / maxC : 0.0
                if sat > 0.14 && maxC > 0.12 && maxC < 0.96 {
                    let midWeight = 1.0 - abs(maxC - 0.55) * 0.65
                    let w = (sat * sat) * max(0.25, midWeight)
                    accentSumR += r * w
                    accentSumG += g * w
                    accentSumB += b * w
                    accentWeightSum += w
                }
            }
        }

        let averageColor = RGBAColor(
            r: fullSumR / max(1, fullCount),
            g: fullSumG / max(1, fullCount),
            b: fullSumB / max(1, fullCount)
        )

        let avgMeanLum = fullLumSum / max(1, fullCount)
        let avgVariance = max(0, (fullLumSqSum / max(1, fullCount)) - avgMeanLum * avgMeanLum)
        let averageContrast = min(0.85, max(0.08, sqrt(avgVariance) * 1.45))

        let clockLum = clockLumSum / max(1, clockCount)
        let clockVar = max(0, (clockLumSqSum / max(1, clockCount)) - clockLum * clockLum)
        let clockContrast = min(0.90, max(0.08, sqrt(clockVar) * 1.5))

        let accentColor: RGBAColor
        if accentWeightSum > 0.05 {
            accentColor = RGBAColor(
                r: accentSumR / accentWeightSum,
                g: accentSumG / accentWeightSum,
                b: accentSumB / accentWeightSum
            )
        } else {
            let (ah, asat, _) = averageColor.hsbComponents
            if asat > 0.06 {
                accentColor = RGBAColor.fromHSB(h: ah, s: max(0.32, asat), b: 0.72)
            } else {
                accentColor = RGBAColor(r: 0.44, g: 0.62, b: 0.94)
            }
        }

        let (accentH, accentS, _) = accentColor.hsbComponents
        let isLightClockSky = clockLum > 0.60

        let smartContrastClockColor: RGBAColor
        if isLightClockSky {
            smartContrastClockColor = RGBAColor.fromHSB(
                h: accentH,
                s: min(0.28, accentS * 0.45),
                b: 0.14,
                a: 0.94
            )
        } else {
            smartContrastClockColor = RGBAColor.fromHSB(
                h: accentH,
                s: min(0.16, accentS * 0.25),
                b: 0.98,
                a: 0.95
            )
        }

        let wallpaperTintClockColor = RGBAColor.fromHSB(
            h: accentH,
            s: max(0.28, min(0.58, accentS * 0.85)),
            b: isLightClockSky ? 0.24 : 0.92,
            a: 0.94
        )

        let matchedGradientColor = RGBAColor.fromHSB(
            h: accentH,
            s: max(0.35, min(0.78, accentS * 0.95)),
            b: 0.54
        )

        let matchedSolidColor = RGBAColor.fromHSB(
            h: accentH,
            s: max(0.25, min(0.55, accentS * 0.72)),
            b: 0.24
        )

        return WallpaperPaletteMetrics(
            clockLuminance: clockLum,
            clockContrast: clockContrast,
            averageColor: averageColor,
            averageContrast: averageContrast,
            accentColor: accentColor,
            smartContrastClockColor: smartContrastClockColor,
            wallpaperTintClockColor: wallpaperTintClockColor,
            matchedGradientColor: matchedGradientColor,
            matchedSolidColor: matchedSolidColor
        )
    }

    nonisolated static func resolveClockColor(mode: ClockColorMode, metrics: WallpaperPaletteMetrics) -> RGBAColor? {
        switch mode {
        case .systemAuto:
            return nil
        case .smartContrast:
            return metrics.smartContrastClockColor
        case .wallpaperTint:
            return metrics.wallpaperTintClockColor
        case .pureWhite:
            return RGBAColor(r: 0.98, g: 0.98, b: 1.0, a: 0.96)
        case .obsidianInk:
            return RGBAColor(r: 0.10, g: 0.12, b: 0.16, a: 0.94)
        case .champagneGold:
            return RGBAColor(r: 0.97, g: 0.87, b: 0.67, a: 0.95)
        case .iceCyan:
            return RGBAColor(r: 0.71, g: 0.93, b: 0.99, a: 0.95)
        case .roseQuartz:
            return RGBAColor(r: 0.98, g: 0.78, b: 0.86, a: 0.95)
        }
    }

    nonisolated static func previewClockColor(mode: ClockColorMode, metrics: WallpaperPaletteMetrics) -> RGBAColor {
        if let resolved = resolveClockColor(mode: mode, metrics: metrics) {
            return resolved
        }
        if metrics.clockLuminance > 0.66 {
            return RGBAColor(r: 0.14, g: 0.16, b: 0.20, a: 0.90)
        }
        return RGBAColor(r: 0.97, g: 0.98, b: 1.0, a: 0.92)
    }

    // MARK: - 1-Tap Auto Night Moonlight Grade

    nonisolated static func synthesizeNightImage(from dayImage: UIImage, preserveAlpha: Bool = false) -> UIImage {
        let targetOrientation = cgOrientation(from: dayImage.imageOrientation)
        let baseCI: CIImage
        if let existingCI = dayImage.ciImage {
            baseCI = existingCI.oriented(targetOrientation)
        } else if let cg = dayImage.cgImage {
            baseCI = CIImage(cgImage: cg).oriented(targetOrientation)
        } else {
            return dayImage
        }

        var current = baseCI
        if let exp = CIFilter(name: "CIExposureAdjust") {
            exp.setValue(current, forKey: kCIInputImageKey)
            exp.setValue(-0.88, forKey: kCIInputEVKey)
            if let out = exp.outputImage { current = out }
        }
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(current, forKey: kCIInputImageKey)
            controls.setValue(0.88, forKey: kCIInputSaturationKey)
            controls.setValue(1.08, forKey: kCIInputContrastKey)
            if let out = controls.outputImage { current = out }
        }
        if let tempTint = CIFilter(name: "CITemperatureAndTint") {
            tempTint.setValue(current, forKey: kCIInputImageKey)
            tempTint.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            tempTint.setValue(CIVector(x: 4650, y: -8), forKey: "inputTargetNeutral")
            if let out = tempTint.outputImage { current = out }
        }
        if let hs = CIFilter(name: "CIHighlightShadowAdjust") {
            hs.setValue(current, forKey: kCIInputImageKey)
            hs.setValue(0.68, forKey: "inputHighlightAmount")
            hs.setValue(0.08, forKey: "inputShadowAmount")
            if let out = hs.outputImage { current = out }
        }

        if preserveAlpha {
            // Re-mask RGB output strictly against original alpha to prevent filter halo bleed
            if let blend = CIFilter(name: "CIBlendWithAlphaMask"),
               let black = CIFilter(name: "CIConstantColorGenerator") {
                black.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0), forKey: kCIInputColorKey)
                blend.setValue(current, forKey: kCIInputImageKey)
                blend.setValue(black.outputImage?.cropped(to: baseCI.extent), forKey: kCIInputBackgroundImageKey)
                blend.setValue(baseCI, forKey: kCIInputMaskImageKey)
                if let out = blend.outputImage { current = out.cropped(to: baseCI.extent) }
            }
        }

        guard let outCG = ciContext.createCGImage(current, from: baseCI.extent) else {
            return dayImage
        }
        return UIImage(cgImage: outCG, scale: dayImage.scale, orientation: .up)
    }

    // MARK: - Binary NSKeyedArchiver Plist Generation

    /// Produces real `CFKeyedArchiverUID` objects indexed `0...maxIndex` for constructing
    /// authentic binary `NSKeyedArchiver` archives (`$objects[n]`) with exact `$classes` arrays.
    nonisolated static func makeKeyedArchiverUIDs(upTo maxIndex: Int, nullUID: Any) throws -> [Any] {
        let count = max(maxIndex + 2, 16)
        let dummies = (0..<count).map { "__camlo_uid_\($0)__" as NSString } as NSArray
        let archiveData = try NSKeyedArchiver.archivedData(withRootObject: dummies, requiringSecureCoding: true)
        guard let rootDict = try PropertyListSerialization.propertyList(from: archiveData, format: nil) as? [String: Any],
              let top = rootDict["$top"] as? [String: Any],
              let objects = rootDict["$objects"] as? [Any],
              objects.count > 1,
              let rootDictObj = objects[1] as? [String: Any],
              let uidArray = rootDictObj["NS.objects"] as? [Any],
              let uid1 = top["root"] else {
            throw NSError(domain: "CamloPosterStyle", code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to synthesize CFKeyedArchiverUID table."])
        }

        var result: [Any] = [nullUID, uid1]
        result.append(contentsOf: uidArray)
        return result
    }

    nonisolated static func buildTitleStyleConfigurationData(
        spec: PosterStyleSpec,
        metrics: WallpaperPaletteMetrics,
        seedData: Data? = nil
    ) throws -> Data {
        let rawSeed: Data
        if let seedData {
            rawSeed = seedData
        } else {
            rawSeed = try TendiesVaultStore.seedPlistData(named: "titleStyleConfiguration.plist")
        }

        guard var plist = try PropertyListSerialization.propertyList(from: rawSeed, format: nil) as? [String: Any],
              var objects = plist["$objects"] as? [Any],
              objects.count >= 8,
              var rootObj = objects[1] as? [String: Any] else {
            throw NSError(domain: "CamloPosterStyle", code: -11, userInfo: [NSLocalizedDescriptionKey: "Invalid titleStyleConfiguration.plist seed structure."])
        }

        // $objects[3] is timeFontIdentifier; contentsLuminence references a numeric $objects entry
        if let fontDict = objects[2] as? [String: Any],
           let fontIdIdx = uidIndex(of: fontDict["timeFontIdentifier"]),
           fontIdIdx > 0, fontIdIdx < objects.count {
            objects[fontIdIdx] = spec.clockFont.posterKitIdentifier
        } else {
            objects[3] = spec.clockFont.posterKitIdentifier
        }
        if let lumIdx = uidIndex(of: rootObj["contentsLuminence"]),
           lumIdx > 0, lumIdx < objects.count {
            objects[lumIdx] = metrics.clockLuminance
        } else {
            rootObj["contentsLuminence"] = metrics.clockLuminance
        }

        if let resolvedColor = resolveClockColor(mode: spec.clockColorMode, metrics: metrics) {
            guard let nullUID = rootObj["titleColor"] ?? rootObj["timeNumberingSystem"] else {
                throw NSError(domain: "CamloPosterStyle", code: -12, userInfo: [NSLocalizedDescriptionKey: "Missing null UID in titleStyleConfiguration seed."])
            }
            let uids = try makeKeyedArchiverUIDs(upTo: 15, nullUID: nullUID)
            // Append [8..13]: PRPosterColor, identifier, UIColor, PRPosterColor $classes, UIColor $classes, NSNumber(0)
            while objects.count > 8 {
                objects.removeLast()
            }
            let prPosterColorObj: [String: Any] = [
                "$class": uids[11],
                "identifier": uids[9],
                "color": uids[10],
                "preferredStyle": uids[13]
            ]
            let prPosterColorClasses: [String: Any] = [
                "$classname": "PRPosterColor",
                "$classes": ["PRPosterColor", "NSObject"]
            ]
            let uiColorClasses: [String: Any] = [
                "$classname": "UIColor",
                "$classes": ["UIColor", "NSObject"],
                "$classhints": ["NSColor"]
            ]

            objects.append(prPosterColorObj)                           // [8]
            objects.append(resolvedColor.posterColorIdentifier)        // [9]
            objects.append(resolvedColor.uiColorArchiveDict(classUID: uids[12])) // [10]
            objects.append(prPosterColorClasses)                       // [11]
            objects.append(uiColorClasses)                             // [12]
            objects.append(0)                                          // [13]

            rootObj["titleColor"] = uids[8]
            rootObj["userConfigured"] = true
        } else {
            rootObj["userConfigured"] = (spec.clockFont != .soft)
        }

        objects[1] = rootObj
        plist["$objects"] = objects
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    nonisolated static func buildHomeScreenConfigurationData(
        spec: PosterStyleSpec,
        metrics: WallpaperPaletteMetrics,
        seedData: Data? = nil
    ) throws -> Data {
        let rawSeed: Data
        if let seedData {
            rawSeed = seedData
        } else {
            rawSeed = try TendiesVaultStore.seedPlistData(named: "homescreenConfiguration.plist")
        }

        guard var plist = try PropertyListSerialization.propertyList(from: rawSeed, format: nil) as? [String: Any],
              var objects = plist["$objects"] as? [Any],
              objects.count >= 85,
              var rootObj = objects[1] as? [String: Any],
              var lockPosterAppearance = objects[2] as? [String: Any] else {
            throw NSError(domain: "CamloPosterStyle", code: -13, userInfo: [NSLocalizedDescriptionKey: "Invalid homescreenConfiguration.plist seed structure."])
        }

        switch spec.homePairing {
        case .clearMatch:
            rootObj["selectedAppearanceType"] = 0
            lockPosterAppearance["legibilityBlurEnabled"] = false
            objects[2] = lockPosterAppearance

        case .legibilityBlur:
            rootObj["selectedAppearanceType"] = 0
            lockPosterAppearance["legibilityBlurEnabled"] = true
            objects[2] = lockPosterAppearance

        case .matchedSolid:
            if var solidAppearance = objects[4] as? [String: Any],
               var solidPicker = objects[5] as? [String: Any],
               let paletteDict = objects[9] as? [String: Any],
               let paletteObjs = paletteDict["NS.objects"] as? [Any],
               let uid10 = paletteObjs.first,
               let oldUIColor = objects[12] as? [String: Any],
               let uiColorClassUID = oldUIColor["$class"] {
                let targetColor = metrics.matchedSolidColor
                objects[11] = targetColor.posterColorIdentifier
                objects[12] = targetColor.uiColorArchiveDict(classUID: uiColorClassUID)
                solidAppearance["color"] = uid10
                solidPicker["selectedColor"] = uid10
                objects[4] = solidAppearance
                objects[5] = solidPicker
            }
            rootObj["selectedAppearanceType"] = 1

        case .matchedGradient:
            if var gradientAppearance = objects[75] as? [String: Any],
               var gradientPicker = objects[76] as? [String: Any],
               let paletteDict = objects[79] as? [String: Any],
               let paletteObjs = paletteDict["NS.objects"] as? [Any],
               let uid80 = paletteObjs.first,
               let oldUIColor = objects[82] as? [String: Any],
               let uiColorClassUID = oldUIColor["$class"] {
                let targetColor = metrics.matchedGradientColor
                objects[81] = targetColor.posterColorIdentifier
                objects[82] = targetColor.uiColorArchiveDict(classUID: uiColorClassUID)
                gradientAppearance["color"] = uid80
                gradientPicker["selectedColor"] = uid80
                objects[75] = gradientAppearance
                objects[76] = gradientPicker
            }
            rootObj["selectedAppearanceType"] = 2
        }

        objects[1] = rootObj
        plist["$objects"] = objects
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    nonisolated static func buildRuntimeSnapshotMetadataData(
        color: RGBAColor,
        contrast: Double,
        seedData: Data? = nil
    ) throws -> Data {
        let rawSeed: Data
        if let seedData {
            rawSeed = seedData
        } else {
            rawSeed = try TendiesVaultStore.seedPlistData(named: "RuntimeSnapshotMetadata-lock.plist")
        }

        guard var plist = try PropertyListSerialization.propertyList(from: rawSeed, format: nil) as? [String: Any],
              var objects = plist["$objects"] as? [Any],
              objects.count >= 4,
              var statsObj = objects[1] as? [String: Any],
              let oldBSColor = objects[2] as? [String: Any],
              let bsClassUID = oldBSColor["$class"] else {
            throw NSError(domain: "CamloPosterStyle", code: -14, userInfo: [NSLocalizedDescriptionKey: "Invalid RuntimeSnapshotMetadata seed structure."])
        }

        statsObj["averageContrast"] = contrast
        objects[1] = statsObj
        objects[2] = color.bsColorArchiveDict(classUID: bsClassUID)
        plist["$objects"] = objects
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    // MARK: - Plist Inspector (X-Ray & LiveCAPreviewView)

    nonisolated static func parseDescriptorStyleSummary(in descriptorDir: URL) -> ParsedPosterStyleSummary {
        var fontIdentifier: String? = nil
        var clockColor: RGBAColor? = nil
        var contentsLuminance: Double? = nil
        var homeAppearanceType = 0
        var hasLegibilityBlur = false
        var homeTintColor: RGBAColor? = nil

        let fm = FileManager.default
        let versionsRoot = descriptorDir.appendingPathComponent("versions", isDirectory: true)
        var versionCandidates: [URL] = [
            versionsRoot.appendingPathComponent("1", isDirectory: true),
            versionsRoot.appendingPathComponent("0", isDirectory: true)
        ]
        if let extra = try? fm.contentsOfDirectory(at: versionsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
            for url in extra where !versionCandidates.contains(url) {
                versionCandidates.append(url)
            }
        }

        let titleURL = versionCandidates
            .map { $0.appendingPathComponent("com.apple.posterkit.provider.instance.titleStyleConfiguration.plist") }
            .first { fm.fileExists(atPath: $0.path) }
            ?? versionCandidates[0].appendingPathComponent("com.apple.posterkit.provider.instance.titleStyleConfiguration.plist")

        if let data = try? Data(contentsOf: titleURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let objects = plist["$objects"] as? [Any],
           let rootDict = resolveRootDict(in: plist, objects: objects) {

            if let lum = resolveDouble(rootDict["contentsLuminence"], in: objects) {
                contentsLuminance = lum
            }
            if let fontConfig = resolveDict(rootDict["timeFontConfiguration"], in: objects) {
                fontIdentifier = resolveString(fontConfig["timeFontIdentifier"], in: objects)
            }
            if let posterColor = resolveDict(rootDict["titleColor"], in: objects),
               let uiColorDict = resolveDict(posterColor["color"], in: objects) {
                clockColor = RGBAColor.fromUIColorDict(uiColorDict)
            }
        }

        let homeURL = versionCandidates
            .map { $0.appendingPathComponent("supplements/0/com.apple.posterkit.provider.supplementURL.homescreenConfiguration.plist") }
            .first { fm.fileExists(atPath: $0.path) }
            ?? versionCandidates[0].appendingPathComponent("supplements/0/com.apple.posterkit.provider.supplementURL.homescreenConfiguration.plist")
        if let data = try? Data(contentsOf: homeURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let objects = plist["$objects"] as? [Any],
           let rootDict = resolveRootDict(in: plist, objects: objects) {

            homeAppearanceType = (rootDict["selectedAppearanceType"] as? Int) ?? 0
            if let lockAppearance = resolveDict(rootDict["lockPosterAppearance"], in: objects) {
                hasLegibilityBlur = (lockAppearance["legibilityBlurEnabled"] as? Bool) ?? false
            }

            let targetKey: String?
            switch homeAppearanceType {
            case 1:  targetKey = "solidColorAppearance"
            case 2:  targetKey = "gradientAppearance"
            default: targetKey = nil
            }
            if let targetKey,
               let appearanceDict = resolveDict(rootDict[targetKey], in: objects),
               let posterColor = resolveDict(appearanceDict["color"], in: objects),
               let uiColorDict = resolveDict(posterColor["color"], in: objects) {
                homeTintColor = RGBAColor.fromUIColorDict(uiColorDict)
            }
        }

        return ParsedPosterStyleSummary(
            clockFontIdentifier: fontIdentifier,
            clockFontStyle: ClockFontStyle.from(posterKitIdentifier: fontIdentifier),
            clockColor: clockColor,
            contentsLuminance: contentsLuminance,
            homeAppearanceType: homeAppearanceType,
            hasLegibilityBlur: hasLegibilityBlur,
            homeTintColor: homeTintColor
        )
    }

    // MARK: - Private Image & KeyedArchiver Helpers

    nonisolated private static func normalizedCGImage(for image: UIImage) -> CGImage? {
        if let cg = image.cgImage, image.imageOrientation == .up {
            return cg
        }
        let targetSize = CGSize(width: min(image.size.width * image.scale, 180), height: min(image.size.height * image.scale, 360))
        guard targetSize.width > 1, targetSize.height > 1 else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let redrawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return redrawn.cgImage
    }

    nonisolated private static func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    nonisolated private static func uidIndex(of value: Any?) -> Int? {
        guard let value else { return nil }
        if let idx = value as? Int { return idx }
        guard let xmlData = try? PropertyListSerialization.data(fromPropertyList: [value], format: .xml, options: 0),
              let xmlStr = String(data: xmlData, encoding: .utf8),
              let keyRange = xmlStr.range(of: "<key>CF$UID</key>") else {
            return nil
        }
        let tail = xmlStr[keyRange.upperBound...]
        guard let openRange = tail.range(of: "<integer>"),
              let closeRange = tail.range(of: "</integer>", range: openRange.upperBound..<tail.endIndex) else {
            return nil
        }
        return Int(tail[openRange.upperBound..<closeRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines))
    }

    nonisolated private static func resolveRootDict(in plist: [String: Any], objects: [Any]) -> [String: Any]? {
        if let top = plist["$top"] as? [String: Any],
           let rootIdx = uidIndex(of: top["root"]),
           rootIdx > 0, rootIdx < objects.count,
           let dict = objects[rootIdx] as? [String: Any] {
            return dict
        }
        if objects.count > 1, let dict = objects[1] as? [String: Any] {
            return dict
        }
        return nil
    }

    nonisolated private static func resolveObject(_ value: Any?, in objects: [Any]) -> Any? {
        guard let value else { return nil }
        if let idx = uidIndex(of: value), idx >= 0, idx < objects.count {
            let target = objects[idx]
            if (target as? String) == "$null" { return nil }
            return target
        }
        return value
    }

    nonisolated private static func resolveDict(_ value: Any?, in objects: [Any]) -> [String: Any]? {
        resolveObject(value, in: objects) as? [String: Any]
    }

    nonisolated private static func resolveString(_ value: Any?, in objects: [Any]) -> String? {
        resolveObject(value, in: objects) as? String
    }

    nonisolated private static func resolveDouble(_ value: Any?, in objects: [Any]) -> Double? {
        if let d = resolveObject(value, in: objects) as? Double { return d }
        if let n = resolveObject(value, in: objects) as? NSNumber { return n.doubleValue }
        return nil
    }
}
