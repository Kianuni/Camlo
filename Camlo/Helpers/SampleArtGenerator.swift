//
//  SampleArtGenerator.swift
//  Camlo · 开幕
//
//  Loads the 6 curated HD Lock <-> Unlock transformation preset packs from PresetGallery.bundle,
//  reconstructing full-resolution RGBA Clock-Depth cutouts from lightweight 8-bit masks in <3ms.
//

import UIKit
import CoreGraphics

enum DemoCategoryFilter: String, CaseIterable, Identifiable {
    case all
    case nature
    case creative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return Bi("全部精选", "All Packs")
        case .nature: return Bi("获奖风光", "Landscapes")
        case .creative: return Bi("潮流创意", "Creative")
        }
    }
}

struct BuiltInDemoPack: Identifiable {
    let id: String
    let filterGroup: DemoCategoryFilter
    let categoryBadge: String
    let title: String
    let subtitle: String
    let recommendedPreset: MorphTransitionPreset
    let recommendedParticles: ParticlePreset

    var hasDepthCutout: Bool {
        SampleArtGenerator.hasMask(for: id)
    }

    var lockThumbnail: UIImage? {
        SampleArtGenerator.loadThumbnailImage(named: "\(id)_thumb_lock.jpg")
    }

    var unlockThumbnail: UIImage? {
        SampleArtGenerator.loadThumbnailImage(named: "\(id)_thumb_unlock.jpg")
    }

    func buildImages() -> (lock: UIImage, unlock: UIImage, lockCutout: UIImage?, unlockCutout: UIImage?) {
        SampleArtGenerator.loadFullPresetAssets(id: id)
    }
}

enum SampleArtGenerator {
    static var allDemos: [BuiltInDemoPack] {
        [
            // MARK: Award-Winning Nature Landscape Photography (6 Packs)
            BuiltInDemoPack(
                id: "dolomites",
                filterGroup: .nature,
                categoryBadge: Bi("多洛米蒂", "Dolomites"),
                title: Bi("多洛米蒂 · 日照金山", "Dolomites · Alpenglow"),
                subtitle: Bi("阿尔卑斯蓝调冷寂冰湖 → 上滑绝壁点燃绯红金色日照金山与镜面湖光", "Pre-dawn Dolomites mirror tarn ignites into blazing rose-gold alpine sunrise"),
                recommendedPreset: .crossfade,
                recommendedParticles: .sunbeamRays
            ),
            BuiltInDemoPack(
                id: "namib",
                filterGroup: .nature,
                categoryBadge: Bi("纳米布沙漠", "Namib Desert"),
                title: Bi("纳米布 · 光影沙丘", "Namib · Golden Dune"),
                subtitle: Bi("暮蓝冷色 S 型巨型沙脊 → 解锁晨光劈开炽烈橙红沙坡与枯木剪影", "Twilight S-curve desert dune splits between fiery amber sun and velvet shadow"),
                recommendedPreset: .curtainRise,
                recommendedParticles: .none
            ),
            BuiltInDemoPack(
                id: "iceland",
                filterGroup: .nature,
                categoryBadge: Bi("冰岛奇境", "Iceland"),
                title: Bi("冰岛 · 黑沙玄光", "Iceland · Obsidian Tide"),
                subtitle: Bi("冷冽迷雾玄武岩山峰与黑沙滩 → 解锁破云熔金朝霞映彻镜面潮汐", "Moody Vestrahorn mist & black sand mirror glow under molten volcanic dawn"),
                recommendedPreset: .crossfade,
                recommendedParticles: .none
            ),
            BuiltInDemoPack(
                id: "yosemite",
                filterGroup: .nature,
                categoryBadge: Bi("优胜美地", "Yosemite"),
                title: Bi("优胜美地 · 熔岩火瀑", "Yosemite · Horsetail Firefall"),
                subtitle: Bi("深冬暮影冷峻酋长岩崖壁 → 上滑落日直击悬瀑化作炽热熔岩火瀑", "Shadowed El Capitan cliff ignites Horsetail Fall into a glowing molten firefall"),
                recommendedPreset: .flashAwaken,
                recommendedParticles: .embers
            ),
            BuiltInDemoPack(
                id: "fuji_sea",
                filterGroup: .nature,
                categoryBadge: Bi("富士山", "Mt. Fuji"),
                title: Bi("富士山 · 破晓云海", "Mt. Fuji · Dawn Cloud Sea"),
                subtitle: Bi("破晓前沉静深蓝云海雪顶 → 上滑赤富士绯红金顶照亮翻涌金色云涛", "Pre-dawn snowy Fuji cone awakens into crimson Akafuji above a gilded cloud sea"),
                recommendedPreset: .curtainRise,
                recommendedParticles: .none
            ),
            BuiltInDemoPack(
                id: "aurora",
                filterGroup: .nature,
                categoryBadge: Bi("自然深空", "Aurora"),
                title: Bi("凛冬雪峰 · 极光盛典", "Alpine Starry Aurora"),
                subtitle: Bi("静谧银河雪山冰湖倒影 → 上滑漫天翡翠紫罗兰极光绚丽流转", "Silent Milky Way alpine mirror lake blooms with emerald & violet Aurora Borealis"),
                recommendedPreset: .crossfade,
                recommendedParticles: .meteorShower
            ),
            // MARK: Creative & Pop Culture Transformations (5 Packs)
            BuiltInDemoPack(
                id: "anime",
                filterGroup: .creative,
                categoryBadge: Bi("二次元觉醒", "Anime"),
                title: Bi("星穹剑姬 · 破界觉醒", "Starlight Valkyrie"),
                subtitle: Bi("暗夜冥想静立 → 上滑睁眼绽放星辉羽翼与圣剑光芒（银冠破框遮挡时钟）", "Dormant starlight sword-maiden awakens with glowing cyan eyes & crystal wings"),
                recommendedPreset: .burstZoom,
                recommendedParticles: .starlight
            ),
            BuiltInDemoPack(
                id: "guofeng",
                filterGroup: .creative,
                categoryBadge: Bi("新中式山水", "Ink Scroll"),
                title: Bi("寒江孤月 · 金碧破晓", "Ink Moon to Golden Dawn"),
                subtitle: Bi("墨色寒山孤亭夜 → 上滑化作千里江山石青金碧日出云海（主峰破框遮挡时钟）", "Midnight ink landscape unveils into imperial blue-green & molten gold sunrise"),
                recommendedPreset: .curtainRise,
                recommendedParticles: .fireflies
            ),
            BuiltInDemoPack(
                id: "supercar",
                filterGroup: .creative,
                categoryBadge: Bi("暗夜超跑", "Hypercar"),
                title: Bi("暗夜超跑 · 氮气点火", "Midnight GT Ignition"),
                subtitle: Bi("雨夜哑光黑武士静默停泊 → 解锁瞬间激光大灯、炽红卡钳与蓝紫尾焰全开", "Stealth matte-black hypercar roars to life with laser headlights & twin exhaust flames"),
                recommendedPreset: .flashAwaken,
                recommendedParticles: .auroraRibbon
            ),
            BuiltInDemoPack(
                id: "mecha",
                filterGroup: .creative,
                categoryBadge: Bi("赛博机甲", "Mecha"),
                title: Bi("苍穹机甲 · 晶核超频", "Aegis Mecha Overdrive"),
                subtitle: Bi("格纳库休眠白钛装甲 → 上滑全息光翼与胸口等离子晶核超频展开", "Dormant titanium mecha activates neon plasma reactor core & holographic wings"),
                recommendedPreset: .holoCard,
                recommendedParticles: .starlight
            ),
            BuiltInDemoPack(
                id: "cute",
                filterGroup: .creative,
                categoryBadge: Bi("萌宠治愈", "Cozy Pet"),
                title: Bi("柴犬团子 · 扑屏早安", "Sleepy Shiba Morning"),
                subtitle: Bi("烛光窗台熟睡柴犬与小奶猫 → 上滑迎着落樱晨光睁眼微笑问早", "Sleeping Shiba Inu & tiny white kitten wake up to warm sakura morning sunshine"),
                recommendedPreset: .aodGaze,
                recommendedParticles: .sakura
            )
        ]
    }

    // MARK: - Bundle Asset Loader & Fast RGBA Mask Compositor

    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 48
        return cache
    }()

    private static var galleryBundleURL: URL? {
        Bundle.main.url(forResource: "PresetGallery", withExtension: "bundle")
    }

    static func hasMask(for id: String) -> Bool {
        guard let dir = galleryBundleURL else { return false }
        let fm = FileManager.default
        let lockMask = dir.appendingPathComponent("\(id)_mask_lock.png")
        let unlockMask = dir.appendingPathComponent("\(id)_mask_unlock.png")
        return fm.fileExists(atPath: lockMask.path) || fm.fileExists(atPath: unlockMask.path)
    }

    static func loadThumbnailImage(named filename: String) -> UIImage? {
        let key = filename as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        guard let img = loadBundleImage(named: filename) else {
            return nil
        }
        thumbnailCache.setObject(img, forKey: key)
        return img
    }

    static func loadBundleImage(named filename: String) -> UIImage? {
        if let dir = galleryBundleURL {
            let fileURL = dir.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
                return img
            }
        }
        return nil
    }

    static func loadFullPresetAssets(id: String) -> (lock: UIImage, unlock: UIImage, lockCutout: UIImage?, unlockCutout: UIImage?) {
        let lockImg = loadBundleImage(named: "\(id)_lock.jpg") ?? fallbackGradientImage(dark: true)
        let unlockImg = loadBundleImage(named: "\(id)_unlock.jpg") ?? fallbackGradientImage(dark: false)

        let lockMask = loadBundleImage(named: "\(id)_mask_lock.png")
        let unlockMask = loadBundleImage(named: "\(id)_mask_unlock.png")

        let lockCut = lockMask.flatMap { compositeForeground(image: lockImg, grayscaleMask: $0) }
        let unlockCut = unlockMask.flatMap { compositeForeground(image: unlockImg, grayscaleMask: $0) }

        return (lockImg, unlockImg, lockCut, unlockCut)
    }

    /// Reconstructs an alpha-transparent RGBA foreground cutout from an RGB image + 8-bit grayscale mask
    /// (where white = opaque foreground in Floating.ca, black = transparent).
    private static func compositeForeground(image: UIImage, grayscaleMask: UIImage) -> UIImage? {
        guard let srcCG = image.cgImage, let maskCG = grayscaleMask.cgImage else { return nil }
        let w = srcCG.width
        let h = srcCG.height
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.interpolationQuality = .high
        ctx.clip(to: rect, mask: maskCG)
        ctx.draw(srcCG, in: rect)

        guard let outCG = ctx.makeImage() else { return nil }
        return UIImage(cgImage: outCG, scale: 1.0, orientation: .up)
    }

    private static func fallbackGradientImage(dark: Bool) -> UIImage {
        let size = CGSize(width: 780, height: 1688)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let cs = CGColorSpaceCreateDeviceRGB()
            let colors = dark
                ? [CGColor(red: 0.05, green: 0.06, blue: 0.16, alpha: 1), CGColor(red: 0.14, green: 0.12, blue: 0.28, alpha: 1)]
                : [CGColor(red: 0.36, green: 0.20, blue: 0.68, alpha: 1), CGColor(red: 0.94, green: 0.48, blue: 0.42, alpha: 1)]
            if let grad = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
    }
}
