//
//  CamloModels.swift
//  Camlo · 开幕
//

import Foundation
import ImageIO
import SwiftUI
import UIKit

enum LockScreenStage: String, CaseIterable, Identifiable {
    case sleep = "Sleep"
    case locked = "Locked"
    case unlock = "Unlock"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return Bi("熄屏", "Sleep")
        case .locked: return Bi("锁屏", "Locked")
        case .unlock: return Bi("解锁", "Unlock")
        }
    }

    var symbol: String {
        switch self {
        case .sleep: return "moon.zzz.fill"
        case .locked: return "lock.fill"
        case .unlock: return "sparkles"
        }
    }
}

enum MorphTransitionPreset: String, CaseIterable, Identifiable, Codable {
    case curtainRise = "curtainRise"
    case burstZoom = "burstZoom"
    case crossfade = "crossfade"
    case flashAwaken = "flashAwaken"
    case holoCard = "holoCard"
    case aodGaze = "aodGaze"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .curtainRise: return Bi("上滑揭幕", "Curtain Rise")
        case .burstZoom: return Bi("破屏觉醒", "Burst Awaken")
        case .crossfade: return Bi("丝滑叠化", "Silk Crossfade")
        case .flashAwaken: return Bi("圣光瞬变", "Flash Morph")
        case .holoCard: return Bi("光栅幻卡", "Holo Flip")
        case .aodGaze: return Bi("暗夜睁眼", "AOD Gaze")
        }
    }

    var subtitle: String {
        switch self {
        case .curtainRise: return Bi("锁屏帷幕顺势上掀，露出底层变身形态", "Lock layer lifts upward with swipe to reveal unlock form")
        case .burstZoom: return Bi("解锁瞬间弹性缩放破屏而出，张力拉满", "High-energy spring zoom reveal on unlock")
        case .crossfade: return Bi("呼吸感柔和渐变切换，百搭日夜与换装", "Smooth cinematic dissolve between lock and unlock")
        case .flashAwaken: return Bi("一道柔白高光闪过，瞬间完成形态切换", "Luminous flash pulse masks an instant transformation")
        case .holoCard: return Bi("仿立体光栅闪卡微旋视差切换", "Lenticular 3D tilt & lateral parallax shift")
        case .aodGaze: return Bi("熄屏微光剪影 → 亮屏展开 → 解锁二次变身", "Dim AOD silhouette -> full lock -> unlock evolution")
        }
    }

    var symbol: String {
        switch self {
        case .curtainRise: return "rectangle.portrait.and.arrow.forward"
        case .burstZoom: return "arrow.up.left.and.arrow.down.right"
        case .crossfade: return "square.stack.3d.forward.dottedline"
        case .flashAwaken: return "bolt.sparkles.fill"
        case .holoCard: return "sparkles.rectangle.stack.fill"
        case .aodGaze: return "eye.circle.fill"
        }
    }
}

enum ParticlePreset: String, CaseIterable, Identifiable, Codable {
    case none = "none"
    case meteorShower = "meteorShower"
    case sunbeamRays = "sunbeamRays"
    case auroraRibbon = "auroraRibbon"
    case sakura = "sakura"
    case snowfall = "snowfall"
    case starlight = "starlight"
    case embers = "embers"
    case fireflies = "fireflies"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return Bi("无特效", "None")
        case .meteorShower: return Bi("星河流星", "Meteors")
        case .sunbeamRays: return Bi("丁达尔晨光", "Sunbeams")
        case .auroraRibbon: return Bi("幻彩流光", "Prism Silk")
        case .sakura: return Bi("落樱缤纷", "Sakura")
        case .snowfall: return Bi("冰晶飞雪", "Crystal Snow")
        case .starlight: return Bi("十字星芒", "Cross Flare")
        case .embers: return Bi("流火飞星", "Fire Sparks")
        case .fireflies: return Bi("森系流萤", "Fireflies")
        }
    }

    var subtitle: String {
        switch self {
        case .none:
            return Bi("纯粹原画，零前景叠加", "Clean artwork with no foreground FX")
        case .meteorShower:
            return Bi("修长流星划破天际，伴随十字微星呼吸闪烁", "Diagonal shooting meteors with crisp twinkling cross-stars")
        case .sunbeamRays:
            return Bi("斜向流动的体积感金色光束与浮游棱镜金尘", "Drifting volumetric golden sunbeam shafts & prism motes")
        case .auroraRibbon:
            return Bi("柔滑律动的极光丝绸光带与六芒炫光", "Undulating iridescent silk light ribbons & prism glints")
        case .sakura:
            return Bi("正侧双态手绘樱瓣随风翻飞 + 近景大光圈柔焦花影", "3D fluttering dual sakura petals with shallow-DOF bokeh")
        case .snowfall:
            return Bi("精细六棱分形冰晶雪花双层视差斜飘", "Detailed 6-branch dendritic ice crystals with wind parallax")
        case .starlight:
            return Bi("电影级水平拉丝四芒与八芒星针呼吸闪烁", "Anamorphic 4-point & 8-point optical cross flares")
        case .embers:
            return Bi("破空拉长火星流线与明暗渐变余烬碎屑升腾", "Upward-streaking hot spark lances & cooling ember shards")
        case .fireflies:
            return Bi("灵动流光尾迹萤火 + 复古镜头六角光斑漫游", "Curved bioluminescent trails & hexagonal aperture bokeh")
        }
    }

    var symbol: String {
        switch self {
        case .none: return "circle.slash"
        case .meteorShower: return "moon.stars.fill"
        case .sunbeamRays: return "sun.max.fill"
        case .auroraRibbon: return "wind"
        case .sakura: return "camera.macro"
        case .snowfall: return "snowflake"
        case .starlight: return "sparkles"
        case .embers: return "flame.fill"
        case .fireflies: return "light.beacon.max.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .none: return .secondary
        case .meteorShower: return Color(red: 0.56, green: 0.86, blue: 1.0)
        case .sunbeamRays: return Color(red: 1.0, green: 0.84, blue: 0.46)
        case .auroraRibbon: return Color(red: 0.45, green: 0.94, blue: 0.86)
        case .sakura: return Color(red: 1.0, green: 0.62, blue: 0.76)
        case .snowfall: return Color(red: 0.82, green: 0.93, blue: 1.0)
        case .starlight: return Color(red: 0.76, green: 0.88, blue: 1.0)
        case .embers: return Color(red: 1.0, green: 0.48, blue: 0.22)
        case .fireflies: return Color(red: 0.82, green: 0.96, blue: 0.44)
        }
    }
}

enum VideoLoopStyle: String, CaseIterable, Identifiable, Codable {
    case pingPong = "pingPong"
    case loop = "loop"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pingPong: return Bi("无缝乒乓往返", "Seamless Ping-Pong")
        case .loop: return Bi("标准单向循环", "Standard Loop")
        }
    }
}

enum VaultItemKind: String, Codable {
    case morph = "morph"
    case video = "video"
    case imported = "imported"

    var badgeText: String {
        switch self {
        case .morph: return Bi("滑动变身", "Morph")
        case .video: return Bi("动态锁屏", "Motion")
        case .imported: return Bi("外部导入", "Imported")
        }
    }

    var symbol: String {
        switch self {
        case .morph: return "wand.and.stars"
        case .video: return "play.rectangle.fill"
        case .imported: return "shippingbox.fill"
        }
    }
}

struct VaultDescriptorEntry: Codable, Equatable, Sendable {
    var folderName: String
    var extensionBundleID: String
    var preserveIdentity: Bool
}

struct TendiesVaultItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()
    var kind: VaultItemKind
    var storageFolderName: String
    var descriptorFolderNames: [String]
    var targetExtension: PBExtensionTarget
    var thumbnailFilename: String?
    var subtitleSummary: String
    var isSelected: Bool = false
    var cloudPackID: String? = nil
    var descriptorEntries: [VaultDescriptorEntry]? = nil

    var resolvedDescriptorEntries: [VaultDescriptorEntry] {
        if let entries = descriptorEntries, !entries.isEmpty {
            return entries
        }
        return descriptorFolderNames.map {
            VaultDescriptorEntry(
                folderName: $0,
                extensionBundleID: targetExtension.extensionIdentifier,
                preserveIdentity: targetExtension == .mercury
            )
        }
    }
}

enum CanvasDisplayProfile: String, CaseIterable, Identifiable, Hashable {
    case standardPhone
    case duoDualScreen

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .standardPhone:
            return Bi("常规 iPhone", "Standard iPhone")
        case .duoDualScreen:
            return Bi("iPhone Duo 双屏", "iPhone Duo Dual")
        }
    }

    var shortBadgeTitle: String {
        switch self {
        case .standardPhone:
            return Bi("常规 9:19", "Standard")
        case .duoDualScreen:
            return Bi("Duo 内外双屏", "Duo Inner+Outer")
        }
    }
}

enum DuoScreenSurface: String, CaseIterable, Identifiable, Hashable {
    case outerCover
    case innerUnfolded

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .outerCover:
            return Bi("外屏 · 6.7\"", "Outer Cover")
        case .innerUnfolded:
            return Bi("内展开 · 书本横屏", "Inner Unfolded")
        }
    }

    /// Logical point dimensions verified against Xcode 27.2 iPhone19,4 (V68) profile.
    var logicalSize: CGSize {
        switch self {
        case .outerCover:
            return CGSize(width: 466, height: 678)
        case .innerUnfolded:
            return CGSize(width: 951, height: 669)
        }
    }

    var aspectRatio: CGFloat {
        logicalSize.width / max(logicalSize.height, 1)
    }

    var morphPixelSize: CGSize {
        switch self {
        case .outerCover:
            return CGSize(width: 1398, height: 2034)
        case .innerUnfolded:
            return CGSize(width: 2282, height: 1606)
        }
    }

    var videoPixelSize: CGSize {
        switch self {
        case .outerCover:
            return CGSize(width: 520, height: 758)
        case .innerUnfolded:
            return CGSize(width: 860, height: 604)
        }
    }
}

struct TendiesInspectionReport: Identifiable {
    let id = UUID()
    let item: TendiesVaultItem
    let descriptorCount: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let totalLayers: Int
    let stateNames: [String]
    let transitionCount: Int
    let animationCount: Int
    let hasFloatingDepth: Bool
    let hasEmitterParticles: Bool
    let wallpaperType: String
    let hasGyroParallax: Bool
    let isAppearanceAware: Bool
    let clockFontIdentifier: String?
    let hasHomeLegibilityBlur: Bool
    let hasDuoDualCanvas: Bool
    let assetImages: [(name: String, image: UIImage)]
    let packageSizeBytes: Int64
}

struct CropFraming: Equatable, Codable, Sendable {
    /// 1.0 = exact aspect-fill; >1.0 = zoomed in; down to 0.70 when `allowEdgeExtend` is true.
    var zoom: CGFloat = 1.0
    /// Normalized translation of the drawn image center in units of destination canvas width/height.
    /// Positive `offsetX` moves the image RIGHT (revealing more of the LEFT side of the photo).
    /// Negative `offsetY` moves the image UP (lifting bottom-edge subjects higher above the Home bar).
    var offsetX: CGFloat = 0.0
    var offsetY: CGFloat = 0.0
    /// When true, allows zooming down to 0.70x and panning up to 28% past photo edges with blurred edge fill.
    var allowEdgeExtend: Bool = false

    static let identity = CropFraming()

    var isIdentity: Bool {
        abs(zoom - 1.0) < 0.001 &&
        abs(offsetX) < 0.001 &&
        abs(offsetY) < 0.001 &&
        !allowEdgeExtend
    }

    func clamped(for sourceSize: CGSize, canvasAspect: CGFloat = 390.0 / 844.0) -> CropFraming {
        let srcW = max(sourceSize.width, 1)
        let srcH = max(sourceSize.height, 1)
        let dstW = max(canvasAspect, 0.05)
        let dstH: CGFloat = 1.0
        let baseScale = max(dstW / srcW, dstH / srcH)

        let minZoom: CGFloat = allowEdgeExtend ? 0.70 : 1.0
        let cZoom = min(max(zoom, minZoom), 4.0)
        let relW = (srcW * baseScale * cZoom) / dstW
        let relH = (srcH * baseScale * cZoom) / dstH

        let maxOffX: CGFloat
        let maxOffY: CGFloat
        if allowEdgeExtend {
            maxOffX = abs(relW - 1.0) * 0.5 + 0.28
            maxOffY = abs(relH - 1.0) * 0.5 + 0.28
        } else {
            maxOffX = max(0, (relW - 1.0) * 0.5)
            maxOffY = max(0, (relH - 1.0) * 0.5)
        }

        return CropFraming(
            zoom: cZoom,
            offsetX: min(max(offsetX, -maxOffX), maxOffX),
            offsetY: min(max(offsetY, -maxOffY), maxOffY),
            allowEdgeExtend: allowEdgeExtend
        )
    }
}

extension UIImage {
    /// True when image aspect ratio differs noticeably from iPhone Lock Screen (~390:844), such as 3:4, 4:3, 1:1, or 16:9 camera photos.
    var needsInteractiveCropSuggestion: Bool {
        needsInteractiveCropSuggestion(targetAspect: 390.0 / 844.0)
    }

    func needsInteractiveCropSuggestion(targetAspect: CGFloat) -> Bool {
        let ratio = size.width / max(size.height, 1)
        return abs(ratio - targetAspect) > 0.045
    }

    /// Normalizes EXIF orientation to `.up` and aspect-fills target pixel dimensions cleanly with optional pan/zoom framing.
    func aspectFilled(to pixelSize: CGSize, framing: CropFraming = .identity) -> UIImage {
        let dstW = max(pixelSize.width, 1)
        let dstH = max(pixelSize.height, 1)
        let srcW = max(size.width, 1)
        let srcH = max(size.height, 1)
        let c = framing.clamped(for: CGSize(width: srcW, height: srcH), canvasAspect: dstW / dstH)

        let baseScale = max(dstW / srcW, dstH / srcH)
        let drawW = srcW * baseScale * c.zoom
        let drawH = srcH * baseScale * c.zoom
        let drawRect = CGRect(
            x: (dstW - drawW) * 0.5 + c.offsetX * dstW,
            y: (dstH - drawH) * 0.5 + c.offsetY * dstH,
            width: drawW,
            height: drawH
        )
        let coversCanvas = drawRect.minX <= 0.5 && drawRect.maxX >= dstW - 0.5 && drawRect.minY <= 0.5 && drawRect.maxY >= dstH - 0.5

        let tinyBackdrop: UIImage?
        if !coversCanvas {
            let tinySize = CGSize(width: 36, height: 78)
            let tinyFmt = UIGraphicsImageRendererFormat()
            tinyFmt.scale = 1.0
            tinyFmt.opaque = true
            tinyBackdrop = UIGraphicsImageRenderer(size: tinySize, format: tinyFmt).image { _ in
                let bScale = max(tinySize.width / srcW, tinySize.height / srcH)
                let bw = srcW * bScale
                let bh = srcH * bScale
                self.draw(in: CGRect(
                    x: (tinySize.width - bw) * 0.5,
                    y: (tinySize.height - bh) * 0.5,
                    width: bw,
                    height: bh
                ))
            }
        } else {
            tinyBackdrop = nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let canvasSize = CGSize(width: dstW, height: dstH)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            if let backdrop = tinyBackdrop {
                backdrop.draw(in: canvasRect.insetBy(dx: -dstW * 0.06, dy: -dstH * 0.06))
                UIColor.black.withAlphaComponent(0.20).setFill()
                ctx.fill(canvasRect)
            }
            self.draw(in: drawRect)
        }
    }

    /// Decodes image data directly into a Retina-capped bitmap via ImageIO without full-resolution RAM inflation.
    static func downsampledRetina(from data: Data, maxPixelDimension: CGFloat = 2560) -> UIImage? {
        let sourceOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOpts as CFDictionary) else {
            return UIImage(data: data)?.normalizedUp()
        }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelDimension)
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) {
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        }
        return UIImage(data: data)?.normalizedUp()
    }

    /// Normalizes EXIF orientation to `.up` at native size.
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
