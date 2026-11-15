import Foundation
import SwiftUI
import UIKit
import CryptoKit
import Combine

enum CloudWallpaperCategory: String, CaseIterable, Identifiable {
    case all
    case motion
    case morph

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all:
            return Bi("全部云端包", "All Packs")
        case .motion:
            return Bi("无缝动态", "Motion Loops")
        case .morph:
            return Bi("景深变身", "Depth Morph")
        }
    }
}

struct CloudWallpaperPack: Identifiable, Codable, Equatable {
    let id: String
    let posterSeedId: Int?
    let category: String
    let kind: String
    let titleZh: String
    let titleEn: String
    let subtitleZh: String
    let subtitleEn: String
    let badgeZh: String
    let badgeEn: String
    let tagsZh: [String]
    let tagsEn: [String]
    let transitionPreset: String?
    let particlePreset: String?
    let supportsClockDepth: Bool?
    let packagePath: String
    let thumbPath: String
    let previewPath: String?
    let sizeBytes: Int
    let sha256: String
    let fps: Int?
    let frameCount: Int?
    let accentHex: String?

    var localizedTitle: String { Bi(titleZh, titleEn) }
    var localizedSubtitle: String { Bi(subtitleZh, subtitleEn) }
    var localizedBadge: String { Bi(badgeZh, badgeEn) }

    var localizedTags: [String] {
        tagsZh.indices.map { idx in
            let en = tagsEn.indices.contains(idx) ? tagsEn[idx] : tagsZh[idx]
            return Bi(tagsZh[idx], en)
        }
    }

    var formattedSize: String {
        if sizeBytes > 0 {
            return ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
        }
        return Bi("云端 .tendies", "Cloud .tendies")
    }

    var accentColor: Color {
        Color(camloHex: accentHex ?? "#6A4DF5")
    }

    var effectivePreviewPath: String {
        if let previewPath, !previewPath.isEmpty {
            return previewPath
        }
        return "wallpapers/previews/\(id).webp"
    }

    @MainActor
    var previewCandidateURLs: [URL] {
        CloudGalleryManager.buildRepoURLs(
            pathOrURL: effectivePreviewPath,
            repoSlug: AppSourceManager.shared.effectiveRepoSlug,
            branch: "main"
        )
    }

    static let seedFallbackPacks: [CloudWallpaperPack] = [
        CloudWallpaperPack(
            id: "lofoten_arctic_silence",
            posterSeedId: 18901,
            category: "motion",
            kind: "motionLoop",
            titleZh: "罗弗敦 · 极夜孤屿",
            titleEn: "Lofoten · Arctic Silence",
            subtitleZh: "北极圈镜面黑水峡湾 · 翡翠极光丝绸缓缓苏醒与呼吸",
            subtitleEn: "Mirror Arctic fjord under slow-breathing emerald Aurora Borealis",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["极光旷野", "镜面峡湾", "无声呼吸"],
            tagsEn: ["Arctic", "Aurora", "Breath Loop"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/lofoten_arctic_silence.tendies",
            thumbPath: "wallpapers/thumbs/lofoten_arctic_silence.jpg",
            previewPath: "wallpapers/previews/lofoten_arctic_silence.webp",
            sizeBytes: 3072206,
            sha256: "7dac14516ac0038b9bac916a12f2c797da1379c5eb392c83c493c128ec2d601b",
            fps: 8,
            frameCount: 16,
            accentHex: "#34D399"
        ),
        CloudWallpaperPack(
            id: "uyuni_mirror_eternity",
            posterSeedId: 18902,
            category: "motion",
            kind: "motionLoop",
            titleZh: "乌尤尼 · 苍穹之镜",
            titleEn: "Uyuni · Mirror of Eternity",
            subtitleZh: "无垠盐沼天水一色 · 钴蓝暮色与玫瑰金霞光往复流淌",
            subtitleEn: "Boundless salt flat mirror breathing between cobalt dusk and rose-amber glow",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["天空之镜", "暮色流霞", "无缝循环"],
            tagsEn: ["Mirror Flat", "Twilight", "Seamless"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/uyuni_mirror_eternity.tendies",
            thumbPath: "wallpapers/thumbs/uyuni_mirror_eternity.jpg",
            previewPath: "wallpapers/previews/uyuni_mirror_eternity.webp",
            sizeBytes: 1563969,
            sha256: "42133018cbe53a7e44ceab079b1745bdf6d01d5bf7f26594ed697f9dfba2d38b",
            fps: 8,
            frameCount: 16,
            accentHex: "#F4A261"
        ),
        CloudWallpaperPack(
            id: "abyssal_pelagic_medusa",
            posterSeedId: 18903,
            category: "motion",
            kind: "motionLoop",
            titleZh: "冥海浮生 · 幽蓝水母",
            titleEn: "Abyssal · Pelagic Grace",
            subtitleZh: "OLED 纯黑深海虚空 · 透明笠水母在靛蓝与蛋白荧光间温柔脉动",
            subtitleEn: "Bioluminescent deep-sea medusa pulsing softly in pure OLED black void",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["OLED 纯黑", "生物荧光", "静谧深海"],
            tagsEn: ["OLED Black", "Abyssal", "Bioluminescent"],
            transitionPreset: "crossfade",
            particlePreset: "fireflies",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/abyssal_pelagic_medusa.tendies",
            thumbPath: "wallpapers/thumbs/abyssal_pelagic_medusa.jpg",
            previewPath: "wallpapers/previews/abyssal_pelagic_medusa.webp",
            sizeBytes: 1837410,
            sha256: "06684fc364bd1784722e32f792d0ef9e7f74194e520d0632d88340de87687d07",
            fps: 8,
            frameCount: 16,
            accentHex: "#60A5FA"
        ),
        CloudWallpaperPack(
            id: "kyoto_moss_rain_zen",
            posterSeedId: 18904,
            category: "motion",
            kind: "motionLoop",
            titleZh: "苔庭听雨 · 幽篁微澜",
            titleEn: "Kyoto · Moss Garden Rain",
            subtitleZh: "京都雨水湿润苍苔竹影 · 石灯笼暖烛微光随雾气徐徐明灭",
            subtitleEn: "Rain-misted Kyoto temple moss & weathered stone lantern glowing softly",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["禅意庭院", "雨夜微灯", "东方留白"],
            tagsEn: ["Kyoto Zen", "Moss Garden", "Lantern"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/kyoto_moss_rain_zen.tendies",
            thumbPath: "wallpapers/thumbs/kyoto_moss_rain_zen.jpg",
            previewPath: "wallpapers/previews/kyoto_moss_rain_zen.webp",
            sizeBytes: 3931569,
            sha256: "71668eec6b5a3d0568de3e8d38882b0f0caefb13549abcd445430376378cac91",
            fps: 8,
            frameCount: 16,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "obsidian_champagne_tide",
            posterSeedId: 18905,
            category: "motion",
            kind: "motionLoop",
            titleZh: "黑曜流金 · 光影潮汐",
            titleEn: "Obsidian · Liquid Chiaroscuro",
            subtitleZh: "Soulages 式极简黑曜雕塑褶皱 · 香槟金掠射光影无声潮汐流动",
            subtitleEn: "Sculptural matte-obsidian folds kissed by grazing champagne-gold light",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["雕塑质感", "香槟金光", "极简主义"],
            tagsEn: ["Minimalism", "Chiaroscuro", "OLED"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/obsidian_champagne_tide.tendies",
            thumbPath: "wallpapers/thumbs/obsidian_champagne_tide.jpg",
            previewPath: "wallpapers/previews/obsidian_champagne_tide.webp",
            sizeBytes: 2257067,
            sha256: "f7fcecf45846996b5b84197d8c14a189462b4240aab367e7fb0b16b31799eeb1",
            fps: 8,
            frameCount: 16,
            accentHex: "#C8A97E"
        ),
        CloudWallpaperPack(
            id: "pillars_of_creation_dawn",
            posterSeedId: 18906,
            category: "morph",
            kind: "morphPair",
            titleZh: "创生之柱 · 星尘破晓",
            titleEn: "Pillars of Creation · Stellar Dawn",
            subtitleZh: "JWST 苍穹暗尘巨柱 → 上滑新生恒星琥珀金光穿透星际圣殿",
            subtitleEn: "JWST molecular dust pillars awaken with newborn amber starlight & Clock Depth",
            badgeZh: "深空景深",
            badgeEn: "Cosmic Depth",
            tagsZh: ["韦伯深空", "星际尘柱", "时钟景深"],
            tagsEn: ["JWST", "Nebula", "Clock Depth"],
            transitionPreset: "curtainRise",
            particlePreset: "starlight",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/pillars_of_creation_dawn.tendies",
            thumbPath: "wallpapers/thumbs/pillars_of_creation_dawn.jpg",
            previewPath: "wallpapers/previews/pillars_of_creation_dawn.webp",
            sizeBytes: 954047,
            sha256: "fd5a7ef6a28ddc72912a347527e9b1c4ee3e9608b1ea678d4027464b038a5a35",
            fps: nil,
            frameCount: nil,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "event_horizon_poem",
            posterSeedId: 18907,
            category: "morph",
            kind: "morphPair",
            titleZh: "视界孤光 · 引力诗篇",
            titleEn: "Event Horizon · Relativistic Halo",
            subtitleZh: "纯黑深空孤悬事件视界银环 → 上滑绽放相对论金色引力透镜光晕",
            subtitleEn: "Silent black-hole photon ring blooms into a golden relativistic accretion halo",
            badgeZh: "深空变身",
            badgeEn: "Cosmic Morph",
            tagsZh: ["黑洞视界", "引力透镜", "纯黑 OLED"],
            tagsEn: ["Black Hole", "Cosmos", "OLED Void"],
            transitionPreset: "burstZoom",
            particlePreset: "starlight",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/event_horizon_poem.tendies",
            thumbPath: "wallpapers/thumbs/event_horizon_poem.jpg",
            previewPath: "wallpapers/previews/event_horizon_poem.webp",
            sizeBytes: 644086,
            sha256: "a9b298fcbd9341534d71a15d92b388d7b3e7776d32e18674215b2b78dd0a05d8",
            fps: nil,
            frameCount: nil,
            accentHex: "#F59E0B"
        ),
        CloudWallpaperPack(
            id: "saturn_equinox_eclipse",
            posterSeedId: 18908,
            category: "morph",
            kind: "morphPair",
            titleZh: "土星春分 · 环影日食",
            titleEn: "Saturn · Equinox Eclipse",
            subtitleZh: "卡西尼号冷峻银灰孤星 → 上滑迎着日食逆光点亮蛋白石冰晶光环",
            subtitleEn: "Cassini slate Saturn transforms into backlit opal-gold equinox eclipse",
            badgeZh: "深空景深",
            badgeEn: "Cosmic Depth",
            tagsZh: ["卡西尼影像", "日食光环", "时钟景深"],
            tagsEn: ["Cassini", "Saturn", "Clock Depth"],
            transitionPreset: "crossfade",
            particlePreset: "starlight",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/saturn_equinox_eclipse.tendies",
            thumbPath: "wallpapers/thumbs/saturn_equinox_eclipse.jpg",
            previewPath: "wallpapers/previews/saturn_equinox_eclipse.webp",
            sizeBytes: 1644147,
            sha256: "e5e44405b69a5912f174c846a5e81c5519ffd7c9c450675b6e4ce6cb81b1b286",
            fps: nil,
            frameCount: nil,
            accentHex: "#E2B66A"
        ),
        CloudWallpaperPack(
            id: "tranquility_earthrise",
            posterSeedId: 18909,
            category: "morph",
            kind: "morphPair",
            titleZh: "静海孤月 · 蓝色弹珠",
            titleEn: "Sea of Tranquility · Earthrise",
            subtitleZh: "Apollo 8 银色环形山沉寂荒原 → 上滑蔚蓝地球升起于漆黑宇宙之上",
            subtitleEn: "Stark silver lunar crater horizon unveils luminous sapphire Earthrise above",
            badgeZh: "深空景深",
            badgeEn: "Cosmic Depth",
            tagsZh: ["阿波罗影像", "地出奇观", "时钟景深"],
            tagsEn: ["Apollo 8", "Earthrise", "Clock Depth"],
            transitionPreset: "curtainRise",
            particlePreset: "starlight",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/tranquility_earthrise.tendies",
            thumbPath: "wallpapers/thumbs/tranquility_earthrise.jpg",
            previewPath: "wallpapers/previews/tranquility_earthrise.webp",
            sizeBytes: 1427447,
            sha256: "1f289c6f050aec643c54196eea555083c7a7a213e9bbc7b68b2a19942a46af73",
            fps: nil,
            frameCount: nil,
            accentHex: "#3B82F6"
        ),
        CloudWallpaperPack(
            id: "desert_arch_andromeda",
            posterSeedId: 18910,
            category: "morph",
            kind: "morphPair",
            titleZh: "荒原星拱 · 仙女座之夜",
            titleEn: "Sandstone Arch · Andromeda Night",
            subtitleZh: "幽蓝暮色荒原石拱剪影 → 上滑深空仙女座星系悬照千年砂岩拱门",
            subtitleEn: "Twilight sandstone arch reveals the spiral Andromeda galaxy above & within",
            badgeZh: "星空景深",
            badgeEn: "Night Depth",
            tagsZh: ["旷野星空", "仙女座星系", "时钟景深"],
            tagsEn: ["Andromeda", "Night Sky", "Clock Depth"],
            transitionPreset: "crossfade",
            particlePreset: "meteorShower",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/desert_arch_andromeda.tendies",
            thumbPath: "wallpapers/thumbs/desert_arch_andromeda.jpg",
            previewPath: "wallpapers/previews/desert_arch_andromeda.webp",
            sizeBytes: 2727309,
            sha256: "008001d88e49ca20a3869047854b0e271413248f67e93e7d7374c7a3780321d6",
            fps: nil,
            frameCount: nil,
            accentHex: "#6366F1"
        ),
        CloudWallpaperPack(
            id: "patagonia_fitz_roy_fire",
            posterSeedId: 18911,
            category: "morph",
            kind: "morphPair",
            titleZh: "巴塔哥尼亚 · 荒原燃金",
            titleEn: "Patagonia · Fitz Roy Alpenglow",
            subtitleZh: "冷钢蓝冰碛湖与菲茨罗伊花岗岩剑峰 → 第一束曙光点燃绯红金壁",
            subtitleEn: "Austere blue-hour Fitz Roy spires ignite into crimson-gold granite alpenglow",
            badgeZh: "风光景深",
            badgeEn: "Nature Depth",
            tagsZh: ["大画幅风光", "日照金山", "时钟景深"],
            tagsEn: ["Patagonia", "Alpenglow", "Clock Depth"],
            transitionPreset: "curtainRise",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/patagonia_fitz_roy_fire.tendies",
            thumbPath: "wallpapers/thumbs/patagonia_fitz_roy_fire.jpg",
            previewPath: "wallpapers/previews/patagonia_fitz_roy_fire.webp",
            sizeBytes: 1280664,
            sha256: "e87e9cb0601c9e09f6f507c14c0542484fb06614bab9c4017feb28838454a83e",
            fps: nil,
            frameCount: nil,
            accentHex: "#EF4444"
        ),
        CloudWallpaperPack(
            id: "baikal_crystalline_abyss",
            posterSeedId: 18912,
            category: "morph",
            kind: "morphPair",
            titleZh: "贝加尔湖 · 冰封深渊",
            titleEn: "Lake Baikal · Sapphire Ice Rifts",
            subtitleZh: "凛冬暮蓝幽邃冰面裂隙 → 上滑极北晨光穿透蓝宝石冰裂折射金晖",
            subtitleEn: "Frozen indigo Baikal ice rifts refract low arctic morning sunlight in sapphire",
            badgeZh: "风光变身",
            badgeEn: "Nature Morph",
            tagsZh: ["蓝冰裂隙", "西伯利亚", "极简冷冽"],
            tagsEn: ["Lake Baikal", "Blue Ice", "Minimal"],
            transitionPreset: "flashAwaken",
            particlePreset: "snowfall",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/baikal_crystalline_abyss.tendies",
            thumbPath: "wallpapers/thumbs/baikal_crystalline_abyss.jpg",
            previewPath: "wallpapers/previews/baikal_crystalline_abyss.webp",
            sizeBytes: 1270524,
            sha256: "101e2e7491e82992f6d49144ad2d5652ab8d5b1a0e0281c7219c452f48cf3ad0",
            fps: nil,
            frameCount: nil,
            accentHex: "#0EA5E9"
        ),
        CloudWallpaperPack(
            id: "misty_cypress_stillness",
            posterSeedId: 18913,
            category: "morph",
            kind: "morphPair",
            titleZh: "迷雾孤柏 · 静水微光",
            titleEn: "Misty Cypress · Still Water",
            subtitleZh: "Michael Kenna 式冷寂晨雾孤树倒影 → 丁达尔金光刺破珍珠薄雾",
            subtitleEn: "Solitary cypress in glass-still dawn fog gilded by soft Tyndall sunbeams",
            badgeZh: "艺术景深",
            badgeEn: "Fine-Art Depth",
            tagsZh: ["极简孤寂", "晨雾微光", "时钟景深"],
            tagsEn: ["Minimalism", "Tyndall", "Clock Depth"],
            transitionPreset: "crossfade",
            particlePreset: "sunbeamRays",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/misty_cypress_stillness.tendies",
            thumbPath: "wallpapers/thumbs/misty_cypress_stillness.jpg",
            previewPath: "wallpapers/previews/misty_cypress_stillness.webp",
            sizeBytes: 1079733,
            sha256: "a515de1db4ecfa314f18365302879d16eb27109348ae44407c6637073b4ad577",
            fps: nil,
            frameCount: nil,
            accentHex: "#94A3B8"
        ),
        CloudWallpaperPack(
            id: "pamir_moonlit_karakul",
            posterSeedId: 18914,
            category: "morph",
            kind: "morphPair",
            titleZh: "帕米尔 · 慕士塔格月华",
            titleEn: "Pamir · Moonlit Glaciers",
            subtitleZh: "冷银月色照耀冰川之父与墨蓝圣湖 → 神圣藏红花晨曦铺满雪穹",
            subtitleEn: "Silver moonlight over Muztagh Ata glacier turns sacred saffron-gold at dawn",
            badgeZh: "风光景深",
            badgeEn: "Nature Depth",
            tagsZh: ["帕米尔高原", "雪山冰湖", "时钟景深"],
            tagsEn: ["Pamir", "Glacier", "Clock Depth"],
            transitionPreset: "curtainRise",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/pamir_moonlit_karakul.tendies",
            thumbPath: "wallpapers/thumbs/pamir_moonlit_karakul.jpg",
            previewPath: "wallpapers/previews/pamir_moonlit_karakul.webp",
            sizeBytes: 1201383,
            sha256: "54b65bc68bbad5a75a93808c28500a4e5630b66dc78d5a61c7ebc3de08173e16",
            fps: nil,
            frameCount: nil,
            accentHex: "#F59E0B"
        ),
        CloudWallpaperPack(
            id: "song_qianli_qinglv",
            posterSeedId: 18915,
            category: "morph",
            kind: "morphPair",
            titleZh: "千里江山 · 溪山霁雪",
            titleEn: "Song Scroll · Azurite Dawn",
            subtitleZh: "北宋绢本水墨孤峰静伫 → 上滑化作石青石绿泥金千里青绿江山",
            subtitleEn: "Northern Song silk monochrome ink peak unfolds into imperial azurite & gold",
            badgeZh: "宋画意境",
            badgeEn: "Song Painting",
            tagsZh: ["宋代绢本", "千里青绿", "时钟景深"],
            tagsEn: ["Song Dynasty", "Qinglv", "Clock Depth"],
            transitionPreset: "curtainRise",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/song_qianli_qinglv.tendies",
            thumbPath: "wallpapers/thumbs/song_qianli_qinglv.jpg",
            previewPath: "wallpapers/previews/song_qianli_qinglv.webp",
            sizeBytes: 1854549,
            sha256: "f6a84f8cdc9ca9d8dd681325351bff9bde28b49e9e246175268446493b6ef556",
            fps: nil,
            frameCount: nil,
            accentHex: "#0F766E"
        ),
        CloudWallpaperPack(
            id: "dunhuang_crescent_star",
            posterSeedId: 18916,
            category: "morph",
            kind: "morphPair",
            titleZh: "敦煌月牙 · 大漠星河",
            titleEn: "Dunhuang · Crescent Oasis",
            subtitleZh: "丝路深蓝夜幕下月牙清泉与沙脊 → 第一缕漠北金晖勾勒苍凉几何",
            subtitleEn: "Silk Road night above Crescent Spring ignites sculpted dunes in mineral gold",
            badgeZh: "东方大漠",
            badgeEn: "Silk Road Depth",
            tagsZh: ["敦煌月牙泉", "大漠光影", "时钟景深"],
            tagsEn: ["Dunhuang", "Desert", "Clock Depth"],
            transitionPreset: "crossfade",
            particlePreset: "starlight",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/dunhuang_crescent_star.tendies",
            thumbPath: "wallpapers/thumbs/dunhuang_crescent_star.jpg",
            previewPath: "wallpapers/previews/dunhuang_crescent_star.webp",
            sizeBytes: 1069606,
            sha256: "94b02dc002f6029f8a048928b74f5050fac9b9a0170742e2b88af4e81a7e1a4b",
            fps: nil,
            frameCount: nil,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "giverny_waterlilies_light",
            posterSeedId: 18917,
            category: "morph",
            kind: "morphPair",
            titleZh: "吉维尼 · 睡莲晨曦",
            titleEn: "Giverny · Nymphéas Light",
            subtitleZh: "致敬莫奈晚年油画厚涂：深紫暮池浮萍 → 破晓珍珠玫瑰与青瓷晨光荡漾",
            subtitleEn: "Oil-impasto homage to Monet's Nymphéas: violet dusk pond to luminous rose dawn",
            badgeZh: "大师油画",
            badgeEn: "Impressionism",
            tagsZh: ["莫奈睡莲", "印象派", "传世笔触"],
            tagsEn: ["Monet", "Oil Painting", "Dawn Light"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/giverny_waterlilies_light.tendies",
            thumbPath: "wallpapers/thumbs/giverny_waterlilies_light.jpg",
            previewPath: "wallpapers/previews/giverny_waterlilies_light.webp",
            sizeBytes: 1946358,
            sha256: "d7fbeb8eeefaa056b3f1e907937a71c13cd6ee61244dc19ff8183b06b5815fbf",
            fps: nil,
            frameCount: nil,
            accentHex: "#A855F7"
        ),
        CloudWallpaperPack(
            id: "turner_golden_seascape",
            posterSeedId: 18918,
            category: "morph",
            kind: "morphPair",
            titleZh: "雾海流霞 · 浪漫主义",
            titleEn: "Misty Sea · Romantic Sublime",
            subtitleZh: "透纳与弗里德里希意境油画：靛蓝雾海孤帆 → 破云蜜金珍珠光海融天",
            subtitleEn: "Turner & Friedrich sublime oil painting dissolving sea fog into honeyed gold",
            badgeZh: "大师油画",
            badgeEn: "Romantic Oil",
            tagsZh: ["透纳海景", "浪漫主义", "光影弥散"],
            tagsEn: ["Turner", "Sublime", "Oil Art"],
            transitionPreset: "crossfade",
            particlePreset: "sunbeamRays",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/turner_golden_seascape.tendies",
            thumbPath: "wallpapers/thumbs/turner_golden_seascape.jpg",
            previewPath: "wallpapers/previews/turner_golden_seascape.webp",
            sizeBytes: 1041995,
            sha256: "52e797deed818f1fb65ed6856f266fbfc85cfbcede60dd563c14dd7029431bc3",
            fps: nil,
            frameCount: nil,
            accentHex: "#CA8A04"
        ),
        CloudWallpaperPack(
            id: "skyspace_oculus_twilight",
            posterSeedId: 18919,
            category: "morph",
            kind: "morphPair",
            titleZh: "苍穹之窗 · 暮光冥想",
            titleEn: "Skyspace · Oculus Meditation",
            subtitleZh: "致敬詹姆斯·特瑞尔与安藤忠雄：清水混凝土天窗由普鲁士蓝过渡琥珀紫罗兰",
            subtitleEn: "Turrell & Ando concrete oculus shifts from Prussian blue to luminous twilight",
            badgeZh: "光影空间",
            badgeEn: "Light & Space",
            tagsZh: ["光影建筑", "特瑞尔天窗", "静默冥想"],
            tagsEn: ["Turrell", "Ando", "Architecture"],
            transitionPreset: "aodGaze",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/skyspace_oculus_twilight.tendies",
            thumbPath: "wallpapers/thumbs/skyspace_oculus_twilight.jpg",
            previewPath: "wallpapers/previews/skyspace_oculus_twilight.webp",
            sizeBytes: 1046228,
            sha256: "3dd1ad2ea98d6c61ee0b4c9f40b1f172a971a9d8683e91982a48f636ddd25fec",
            fps: nil,
            frameCount: nil,
            accentHex: "#6366F1"
        ),
        CloudWallpaperPack(
            id: "pantheon_sunbeam_sanctuary",
            posterSeedId: 18920,
            category: "morph",
            kind: "morphPair",
            titleZh: "光之圣殿 · 静默几何",
            titleEn: "Sanctuary · Travertine Sunbeam",
            subtitleZh: "极简洞石圣殿与室内镜池幽暗蓝调 → 午后金光如剑斜劈素壁与水波",
            subtitleEn: "Monolithic travertine sanctuary in blue-gray calm bisected by a golden sunbeam",
            badgeZh: "建筑景深",
            badgeEn: "Spatial Depth",
            tagsZh: ["洞石光束", "几何诗意", "建筑空间"],
            tagsEn: ["Architecture", "Sunbeam", "Sanctuary"],
            transitionPreset: "aodGaze",
            particlePreset: "sunbeamRays",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/pantheon_sunbeam_sanctuary.tendies",
            thumbPath: "wallpapers/thumbs/pantheon_sunbeam_sanctuary.jpg",
            previewPath: "wallpapers/previews/pantheon_sunbeam_sanctuary.webp",
            sizeBytes: 1108313,
            sha256: "a93060fc04d3f875657418222105c234335efca0b9f0f7af201df97b42c6bff3",
            fps: nil,
            frameCount: nil,
            accentHex: "#B45309"
        )
    ]
}

enum CloudCatalogChannel: String, CaseIterable, Identifiable, Codable, Sendable {
    case camloOfficial
    case caPlayground
    case nuggetCustom
    case nuggetApple

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .camloOfficial:
            return Bi("Camlo 官方", "Camlo Official")
        case .caPlayground:
            return Bi("CAPlayground", "CAPlayground")
        case .nuggetCustom:
            return Bi("Nugget 创意", "Nugget Custom")
        case .nuggetApple:
            return Bi("Apple 机型库", "Apple Collections")
        }
    }

    var shortTitle: String {
        switch self {
        case .camloOfficial:
            return Bi("官方", "Official")
        case .caPlayground:
            return "CAPlayground"
        case .nuggetCustom:
            return Bi("Nugget 创意", "Custom")
        case .nuggetApple:
            return Bi("Apple 原厂", "Apple")
        }
    }

    var iconName: String {
        switch self {
        case .camloOfficial:
            return "sparkles"
        case .caPlayground:
            return "paintpalette.fill"
        case .nuggetCustom:
            return "wand.and.stars"
        case .nuggetApple:
            return "apple.logo"
        }
    }

    var repoSlug: String {
        switch self {
        case .camloOfficial:
            return AppSourceManager.defaultRepoSlug
        case .caPlayground:
            return "CAPlayground/wallpapers"
        case .nuggetCustom, .nuggetApple:
            return "SerStars/nugget-wallpapers"
        }
    }

    var branch: String { "main" }

    var indexRelativePath: String {
        switch self {
        case .camloOfficial:
            return "wallpapers/catalog.json"
        case .caPlayground:
            return "wallpapers.json"
        case .nuggetCustom:
            return "wallpapers-custom.json"
        case .nuggetApple:
            return "wallpapers-apple.json"
        }
    }

    var cacheFileName: String {
        "channel_\(rawValue)_cache.json"
    }
}

enum CloudSortOrder: String, CaseIterable, Identifiable {
    case featured
    case newest
    case nameAscending

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .featured:
            return Bi("默认推荐", "Featured")
        case .newest:
            return Bi("最新发布", "Newest")
        case .nameAscending:
            return Bi("名称 A→Z", "Name A–Z")
        }
    }
}

struct CommunityWallpaperPack: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    let rawID: String
    let channel: CloudCatalogChannel
    let name: String
    let description: String
    let author: String
    let fileRelativeOrAbsoluteURL: String
    let previewRelativeOrAbsoluteURL: String
    let dateString: String?
    let originTag: String?
    let isContest: Bool
    let orderIndex: Int

    var cloudPackID: String { id }

    var isAnimatedPreview: Bool {
        let lower = previewRelativeOrAbsoluteURL.lowercased()
        return lower.hasSuffix(".gif") || lower.hasSuffix(".webp") || lower.contains(".gif?")
    }

    var previewCandidateURLs: [URL] {
        CloudGalleryManager.buildRepoURLs(
            pathOrURL: previewRelativeOrAbsoluteURL,
            repoSlug: channel.repoSlug,
            branch: channel.branch
        )
    }

    var packageCandidateURLs: [URL] {
        CloudGalleryManager.buildRepoURLs(
            pathOrURL: fileRelativeOrAbsoluteURL,
            repoSlug: channel.repoSlug,
            branch: channel.branch
        )
    }

    var displayAuthor: String {
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch channel {
        case .nuggetApple:
            return "Apple"
        case .caPlayground:
            return "CAPlayground Community"
        case .nuggetCustom:
            return "Nugget Community"
        case .camloOfficial:
            return "Camlo"
        }
    }
}

struct CloudWallpaperCatalog: Codable {
    let schemaVersion: Int?
    let generatedAt: String?
    let repo: String?
    let packCount: Int?
    let packs: [CloudWallpaperPack]
}

@MainActor
final class CloudGalleryManager: ObservableObject {
    static let shared = CloudGalleryManager()

    @Published var packs: [CloudWallpaperPack] = CloudWallpaperPack.seedFallbackPacks
    @Published var thumbnails: [String: UIImage] = [:]
    @Published var isRefreshingCatalog = false
    @Published var lastSyncedAt: Date?
    @Published var syncErrorMessage: String?

    @Published var selectedChannel: CloudCatalogChannel = .camloOfficial
    @Published var communityPacksByChannel: [CloudCatalogChannel: [CommunityWallpaperPack]] = [:]
    @Published var isRefreshingChannel: [CloudCatalogChannel: Bool] = [:]
    @Published var channelErrorByChannel: [CloudCatalogChannel: String] = [:]
    @Published var lastSyncedByChannel: [CloudCatalogChannel: Date] = [:]

    @Published var downloadProgressByID: [String: Double] = [:]
    @Published var activeDownloadID: String?

    private let memCache = NSCache<NSString, UIImage>()
    private var inFlightThumbIDs = Set<String>()
    private var hasSyncedOnce = false
    private var activeDownloadTask: Task<TendiesVaultItem, Error>?

    private var cacheRoot: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("CamloCloudGallery", isDirectory: true)
    }

    private var thumbCacheDir: URL {
        cacheRoot.appendingPathComponent("thumbs", isDirectory: true)
    }

    private var catalogCacheURL: URL {
        cacheRoot.appendingPathComponent("catalog_cache.json")
    }

    private init() {
        ensureCacheDirs()
        loadCachedCatalog()
        loadCachedCommunityCatalogs()
    }

    private func ensureCacheDirs() {
        try? FileManager.default.createDirectory(at: thumbCacheDir, withIntermediateDirectories: true)
    }

    private func loadCachedCatalog() {
        guard let data = try? Data(contentsOf: catalogCacheURL),
              let decoded = try? JSONDecoder().decode(CloudWallpaperCatalog.self, from: data),
              !decoded.packs.isEmpty else {
            return
        }
        if decoded.packs.count < packs.count {
            return
        }
        packs = decoded.packs
    }

    private func loadCachedCommunityCatalogs() {
        for channel in CloudCatalogChannel.allCases where channel != .camloOfficial {
            let fileURL = cacheRoot.appendingPathComponent(channel.cacheFileName)
            guard let data = try? Data(contentsOf: fileURL),
                  let parsed = Self.parseCommunityCatalog(data: data, channel: channel),
                  !parsed.isEmpty else {
                continue
            }
            communityPacksByChannel[channel] = parsed
        }
    }

    // MARK: - Multi-Route URL Builder & Concurrent HEAD Racing

    nonisolated static func buildRepoURLs(
        pathOrURL rawInput: String,
        repoSlug: String,
        branch: String = "main"
    ) -> [URL] {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let preferMirror = AppSourceManager.prefersCNMirror

        func buildGitHubURLs(slug: String, branch: String, rawRelativePath: String) -> [URL] {
            let cleanRel = rawRelativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let encodedRel = percentEncodeRelativePath(cleanRel)
            let rawURLString = "https://raw.githubusercontent.com/\(slug)/\(branch)/\(encodedRel)"

            let ghFast = "https://ghfast.top/\(rawURLString)"
            let ghProxy = "https://gh-proxy.com/\(rawURLString)"
            let ghProxyNet = "https://ghproxy.net/\(rawURLString)"
            let jsdMirror = "https://cdn.jsdmirror.com/gh/\(slug)@\(branch)/\(encodedRel)"
            let jsDelivr = "https://fastly.jsdelivr.net/gh/\(slug)@\(branch)/\(encodedRel)"

            let preferAuthenticatedRaw = !AppSourceManager.currentGitHubToken.isEmpty
                && slug.lowercased() == AppSourceManager.currentEffectiveRepoSlug().lowercased()

            let ordered: [String]
            if preferAuthenticatedRaw {
                ordered = [rawURLString, jsDelivr, ghFast, ghProxy, ghProxyNet, jsdMirror]
            } else if preferMirror {
                ordered = [ghFast, ghProxy, ghProxyNet, jsdMirror, jsDelivr, rawURLString]
            } else {
                ordered = [rawURLString, jsDelivr, ghFast, ghProxy, ghProxyNet, jsdMirror]
            }

            var seen = Set<String>()
            return ordered.compactMap { str in
                guard seen.insert(str).inserted else { return nil }
                return URL(string: str)
            }
        }

        if trimmed.lowercased().hasPrefix("https://") || trimmed.lowercased().hasPrefix("http://") {
            guard let directURL = sanitizedAbsoluteURL(from: trimmed) else { return [] }
            if directURL.host?.lowercased() == "raw.githubusercontent.com" {
                let comps = directURL.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
                if comps.count >= 6, comps[2] == "refs", comps[3] == "heads" {
                    let parsedSlug = "\(comps[0])/\(comps[1])"
                    let parsedBranch = comps[4]
                    let parsedRel = comps.dropFirst(5).joined(separator: "/")
                    return buildGitHubURLs(slug: parsedSlug, branch: parsedBranch, rawRelativePath: parsedRel)
                } else if comps.count >= 4 {
                    let parsedSlug = "\(comps[0])/\(comps[1])"
                    let parsedBranch = comps[2]
                    let parsedRel = comps.dropFirst(3).joined(separator: "/")
                    return buildGitHubURLs(slug: parsedSlug, branch: parsedBranch, rawRelativePath: parsedRel)
                }
            }
            return [directURL]
        }

        return buildGitHubURLs(slug: repoSlug, branch: branch, rawRelativePath: trimmed)
    }

    nonisolated private static func percentEncodeRelativePath(_ path: String) -> String {
        let segmentAllowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        return path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { seg in
                let raw = String(seg)
                let decoded = raw.removingPercentEncoding ?? raw
                return decoded.addingPercentEncoding(withAllowedCharacters: segmentAllowed) ?? raw
            }
            .joined(separator: "/")
    }

    nonisolated private static func sanitizedAbsoluteURL(from raw: String) -> URL? {
        if let direct = URL(string: raw), !raw.contains(" ") {
            return direct
        }
        guard let schemeRange = raw.range(of: "://") else {
            return URL(string: raw)
        }
        let scheme = String(raw[..<schemeRange.lowerBound])
        let rest = String(raw[schemeRange.upperBound...])
        let slashIdx = rest.firstIndex(of: "/") ?? rest.endIndex
        let authority = String(rest[..<slashIdx])
        let tail = String(rest[slashIdx...])

        let queryIdx = tail.firstIndex(of: "?") ?? tail.endIndex
        let pathPart = String(tail[..<queryIdx])
        let queryPart = String(tail[queryIdx...])

        let encodedPath = pathPart.isEmpty ? "" : "/" + percentEncodeRelativePath(String(pathPart.dropFirst()))
        let encodedQuery = queryPart.isEmpty ? "" : (queryPart.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? queryPart)
        return URL(string: "\(scheme)://\(authority)\(encodedPath)\(encodedQuery)")
    }

    actor CamloEndpointRanker {
        static let shared = CamloEndpointRanker()

        private struct HostSample {
            var ewmaSeconds: TimeInterval
            var updatedAt: Date
            var failed: Bool
        }

        private let ttlSeconds: TimeInterval = 300
        private var hostScores: [String: HostSample] = [:]

        private lazy var probeSession: URLSession = {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 4.0
            config.timeoutIntervalForResource = 4.5
            config.httpAdditionalHeaders = ["User-Agent": "Camlo/\(CamloDevice.appVersion)"]
            return URLSession(configuration: config)
        }()

        func recordTransportFailure(for url: URL) {
            guard let host = url.host?.lowercased() else { return }
            hostScores[host] = HostSample(ewmaSeconds: 999.0, updatedAt: Date(), failed: true)
        }

        func recordSuccess(for url: URL, rtt: TimeInterval) {
            guard let host = url.host?.lowercased() else { return }
            let clamped = max(0.01, rtt)
            let sampleTime = Date()
            if let prev = hostScores[host], !prev.failed {
                let blended = (prev.ewmaSeconds * 0.4) + (clamped * 0.6)
                hostScores[host] = HostSample(ewmaSeconds: blended, updatedAt: sampleTime, failed: false)
            } else {
                hostScores[host] = HostSample(ewmaSeconds: clamped, updatedAt: sampleTime, failed: false)
            }
        }

        func prioritize(_ candidates: [URL]) async -> [URL] {
            guard candidates.count > 1 else { return candidates }
            let now = Date()

            // Return cached EWMA ordering when all candidate hosts have fresh (< 5 min) measurements.
            let allFresh = candidates.allSatisfy { url in
                guard let host = url.host?.lowercased(),
                      let sample = hostScores[host] else { return false }
                return now.timeIntervalSince(sample.updatedAt) < ttlSeconds
            }
            if allFresh {
                return sortedByCachedLatency(candidates, referenceDate: now)
            }

            let measurements = await withTaskGroup(of: (URL, TimeInterval?).self) { group in
                for url in candidates {
                    group.addTask { [probeSession] in
                        let rtt = await Self.probeRangeRTT(url: url, session: probeSession)
                        return (url, rtt)
                    }
                }
                var out: [(URL, TimeInterval?)] = []
                for await pair in group {
                    out.append(pair)
                }
                return out
            }

            let sampleTime = Date()
            for (url, rtt) in measurements {
                guard let host = url.host?.lowercased() else { continue }
                if let rtt {
                    if let prev = hostScores[host], !prev.failed {
                        let blended = (prev.ewmaSeconds * 0.4) + (rtt * 0.6)
                        hostScores[host] = HostSample(ewmaSeconds: blended, updatedAt: sampleTime, failed: false)
                    } else {
                        hostScores[host] = HostSample(ewmaSeconds: rtt, updatedAt: sampleTime, failed: false)
                    }
                } else {
                    hostScores[host] = HostSample(ewmaSeconds: 999.0, updatedAt: sampleTime, failed: true)
                }
            }

            return sortedByCachedLatency(candidates, referenceDate: sampleTime)
        }

        private func sortedByCachedLatency(_ candidates: [URL], referenceDate: Date) -> [URL] {
            let originalIndex = Dictionary(uniqueKeysWithValues: candidates.enumerated().map { ($0.element, $0.offset) })
            return candidates.sorted { lhs, rhs in
                let lSample = lhs.host.flatMap { hostScores[$0.lowercased()] }
                let rSample = rhs.host.flatMap { hostScores[$0.lowercased()] }
                let lScore = scoreValue(sample: lSample, referenceDate: referenceDate)
                let rScore = scoreValue(sample: rSample, referenceDate: referenceDate)
                if lScore != rScore {
                    return lScore < rScore
                }
                return (originalIndex[lhs] ?? 0) < (originalIndex[rhs] ?? 0)
            }
        }

        private func scoreValue(sample: HostSample?, referenceDate: Date) -> TimeInterval {
            guard let sample, referenceDate.timeIntervalSince(sample.updatedAt) < ttlSeconds else {
                return 50.0
            }
            return sample.failed ? 999.0 : sample.ewmaSeconds
        }

        private static func probeRangeRTT(url: URL, session: URLSession) async -> TimeInterval? {
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4.0)
            req.httpMethod = "GET"
            req.setValue("bytes=0-1", forHTTPHeaderField: "Range")
            req.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            AppSourceManager.applyGitHubAuthIfNeeded(to: &req)
            let started = CFAbsoluteTimeGetCurrent()
            do {
                let (_, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else { return nil }
                guard (200...299).contains(http.statusCode) || http.statusCode == 416 else { return nil }
                if let mime = http.mimeType?.lowercased(), mime.contains("text/html") {
                    return nil
                }
                return max(0.001, CFAbsoluteTimeGetCurrent() - started)
            } catch {
                return nil
            }
        }
    }

    func refreshChannelIfNeeded(_ channel: CloudCatalogChannel) async {
        if channel == .camloOfficial {
            await refreshCatalogIfNeeded()
            return
        }
        let existing = communityPacksByChannel[channel] ?? []
        if existing.isEmpty || lastSyncedByChannel[channel] == nil {
            await refreshChannel(channel, force: false)
        }
    }

    func refreshChannel(_ channel: CloudCatalogChannel, force: Bool = true) async {
        if channel == .camloOfficial {
            await refreshCatalog(force: force)
            return
        }
        if isRefreshingChannel[channel] == true { return }
        if !force, !(communityPacksByChannel[channel] ?? []).isEmpty, lastSyncedByChannel[channel] != nil {
            return
        }

        isRefreshingChannel[channel] = true
        channelErrorByChannel[channel] = nil
        defer { isRefreshingChannel[channel] = false }

        let baseCandidates = Self.buildRepoURLs(
            pathOrURL: channel.indexRelativePath,
            repoSlug: channel.repoSlug,
            branch: channel.branch
        )
        let racedURLs = await CamloEndpointRanker.shared.prioritize(baseCandidates)
        var lastError: Error?

        for url in racedURLs {
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 18)
                request.setValue("Camlo/\(CamloDevice.appVersion)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw NSError(
                        domain: "CloudGallery",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                    )
                }
                if let parsed = Self.parseCommunityCatalog(data: data, channel: channel), !parsed.isEmpty {
                    ensureCacheDirs()
                    let cacheFile = cacheRoot.appendingPathComponent(channel.cacheFileName)
                    try? data.write(to: cacheFile, options: .atomic)
                    communityPacksByChannel[channel] = parsed
                    lastSyncedByChannel[channel] = Date()
                    channelErrorByChannel[channel] = nil
                    return
                }
                throw NSError(
                    domain: "CloudGallery",
                    code: -10,
                    userInfo: [NSLocalizedDescriptionKey: Bi("远端清单格式异常或为空", "Empty or invalid catalog JSON")]
                )
            } catch {
                lastError = error
            }
        }

        if let err = lastError {
            channelErrorByChannel[channel] = Bi(
                "拉取 \(channel.localizedTitle) 目录失败：\(err.localizedDescription)（可在右上角切换镜像/直连或重试）",
                "Failed to load \(channel.localizedTitle): \(err.localizedDescription)"
            )
        }
    }

    nonisolated private static func parseCommunityCatalog(
        data: Data,
        channel: CloudCatalogChannel
    ) -> [CommunityWallpaperPack]? {
        guard let root = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }

        func stringField(_ obj: [String: Any], _ key: String) -> String? {
            if let s = obj[key] as? String {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            if let i = obj[key] as? Int {
                return String(i)
            }
            if let n = obj[key] as? NSNumber {
                return n.stringValue
            }
            return nil
        }

        func authorField(_ obj: [String: Any], keys: [String]) -> String {
            for key in keys {
                if let arr = obj[key] as? [Any] {
                    let joined = arr.compactMap { $0 as? String }
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                    if !joined.isEmpty { return joined }
                } else if let str = stringField(obj, key) {
                    return str
                }
            }
            return ""
        }

        func boolField(_ obj: [String: Any], _ key: String) -> Bool {
            if let b = obj[key] as? Bool { return b }
            if let i = obj[key] as? Int { return i != 0 }
            if let s = obj[key] as? String {
                return ["true", "1", "yes"].contains(s.lowercased())
            }
            return false
        }

        func formatEpochSeconds(_ seconds: TimeInterval) -> String? {
            guard seconds >= 946_684_800, seconds <= 4_102_444_800 else { return nil }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date(timeIntervalSince1970: seconds))
        }

        func dateField(_ obj: [String: Any], _ key: String) -> String? {
            let rawNumber: Double?
            if let num = obj[key] as? NSNumber, CFGetTypeID(num) != CFBooleanGetTypeID() {
                rawNumber = num.doubleValue
            } else if let str = stringField(obj, key),
                      str.allSatisfy({ $0.isNumber || $0 == "." }),
                      let parsed = Double(str) {
                rawNumber = parsed
            } else {
                rawNumber = nil
            }

            if let num = rawNumber, num > 0 {
                let seconds = num >= 1_000_000_000_000 ? (num / 1000.0) : num
                if let formatted = formatEpochSeconds(seconds) {
                    return formatted
                }
            }
            return stringField(obj, key)
        }

        switch channel {
        case .camloOfficial:
            return nil

        case .caPlayground:
            guard let dict = root as? [String: Any],
                  let rows = dict["wallpapers"] as? [[String: Any]] else {
                return nil
            }
            var parsed: [CommunityWallpaperPack] = []
            parsed.reserveCapacity(rows.count)
            for (idx, row) in rows.enumerated() {
                guard let name = stringField(row, "name"),
                      let file = stringField(row, "file") else { continue }
                let rawID = stringField(row, "id") ?? "\(idx)"
                let preview = stringField(row, "preview") ?? ""
                let creator = authorField(row, keys: ["creator", "author", "authors"])
                let desc = stringField(row, "description") ?? ""
                let date = dateField(row, "date")
                let origin = stringField(row, "from")
                parsed.append(CommunityWallpaperPack(
                    id: "\(channel.rawValue):\(rawID)",
                    rawID: rawID,
                    channel: channel,
                    name: name,
                    description: desc,
                    author: creator,
                    fileRelativeOrAbsoluteURL: file,
                    previewRelativeOrAbsoluteURL: preview,
                    dateString: date,
                    originTag: origin,
                    isContest: false,
                    orderIndex: idx
                ))
            }
            return parsed

        case .nuggetCustom, .nuggetApple:
            guard let rows = root as? [[String: Any]] else {
                return nil
            }
            var parsed: [CommunityWallpaperPack] = []
            parsed.reserveCapacity(rows.count)
            for (idx, row) in rows.enumerated() {
                guard let name = stringField(row, "name"),
                      let file = stringField(row, "url") ?? stringField(row, "file") else { continue }
                let rawID = stringField(row, "id") ?? "\(idx)"
                let preview = stringField(row, "preview") ?? ""
                let authors = authorField(row, keys: ["authors", "author", "creator"])
                let desc = stringField(row, "description") ?? ""
                let date = dateField(row, "date")
                let contest = boolField(row, "contest")
                parsed.append(CommunityWallpaperPack(
                    id: "\(channel.rawValue):\(rawID)",
                    rawID: rawID,
                    channel: channel,
                    name: name,
                    description: desc,
                    author: authors,
                    fileRelativeOrAbsoluteURL: file,
                    previewRelativeOrAbsoluteURL: preview,
                    dateString: date,
                    originTag: contest ? "Contest" : nil,
                    isContest: contest,
                    orderIndex: idx
                ))
            }
            return parsed
        }
    }

    func cancelActiveDownload() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        if let activeID = activeDownloadID {
            downloadProgressByID.removeValue(forKey: activeID)
        }
        activeDownloadID = nil
    }

    func refreshCatalogIfNeeded() async {
        if !hasSyncedOnce {
            await refreshCatalog(force: false)
        }
    }

    func refreshCatalog(force: Bool = true) async {
        if isRefreshingCatalog { return }
        if hasSyncedOnce && !force { return }

        isRefreshingCatalog = true
        syncErrorMessage = nil
        defer { isRefreshingCatalog = false }

        let urls = AppSourceManager.shared.candidateRawURLs(for: "wallpapers/catalog.json")
        var lastError: Error?
        var saw404 = false

        for url in urls {
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
                request.setValue("Camlo/\(CamloDevice.appVersion)", forHTTPHeaderField: "User-Agent")
                AppSourceManager.applyGitHubAuthIfNeeded(to: &request)
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    if http.statusCode == 404 {
                        saw404 = true
                    }
                    throw NSError(
                        domain: "CloudGallery",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                    )
                }
                let decoded = try JSONDecoder().decode(CloudWallpaperCatalog.self, from: data)
                if !decoded.packs.isEmpty {
                    ensureCacheDirs()
                    try? data.write(to: catalogCacheURL, options: .atomic)
                    packs = decoded.packs
                    lastSyncedAt = Date()
                    hasSyncedOnce = true
                    syncErrorMessage = nil
                    return
                }
            } catch {
                if (error as NSError).code == 404 {
                    saw404 = true
                }
                lastError = error
            }
        }

        if saw404 || (lastError as? NSError)?.code == 404 {
            let count = packs.count
            syncErrorMessage = Bi(
                "Camlo 官方仓库当前处于私有测试状态（HTTP 404）。如需内测在线加载全部 \(count) 套大师级官方壁纸，可在「系统状态 → 软件源订阅 → 高级」填写 GitHub Token；待仓库公开后即可免配置直接加载，CAPlayground / Nugget 社区频道当前可直接下载。",
                "Camlo Official repo is currently private (HTTP 404). To test streaming all \(count) official masterworks, enter a GitHub Token in System & Settings -> App Source -> Advanced; CAPlayground & Nugget channels work without a token."
            )
            return
        }

        if let err = lastError {
            syncErrorMessage = Bi(
                "拉取云端壁纸目录失败：\(err.localizedDescription)（可尝试顶部切换 GitHub 直连或大陆镜像）",
                "Failed to load cloud catalog: \(err.localizedDescription)"
            )
        }
    }

    func cachedThumbnail(for pack: CloudWallpaperPack) -> UIImage? {
        if let inState = thumbnails[pack.id] {
            return inState
        }
        if let inMem = memCache.object(forKey: pack.id as NSString) {
            return inMem
        }
        let diskURL = thumbCacheDir.appendingPathComponent("\(pack.id).jpg")
        if let data = try? Data(contentsOf: diskURL),
           let img = UIImage.downsampledRetina(from: data, maxPixelDimension: 840) {
            memCache.setObject(img, forKey: pack.id as NSString)
            return img
        }
        return nil
    }

    func loadThumbnailIfNeeded(for pack: CloudWallpaperPack) async {
        if let existing = cachedThumbnail(for: pack) {
            if thumbnails[pack.id] == nil {
                thumbnails[pack.id] = existing
            }
            return
        }
        if inFlightThumbIDs.contains(pack.id) { return }
        inFlightThumbIDs.insert(pack.id)
        defer { inFlightThumbIDs.remove(pack.id) }

        let urls = AppSourceManager.shared.candidateRawURLs(for: pack.thumbPath)
        let targetDiskURL = thumbCacheDir.appendingPathComponent("\(pack.id).jpg")

        for url in urls {
            do {
                var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 18)
                request.setValue("Camlo/\(CamloDevice.appVersion)", forHTTPHeaderField: "User-Agent")
                AppSourceManager.applyGitHubAuthIfNeeded(to: &request)
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    continue
                }
                let decoded: UIImage? = await Task.detached(priority: .utility) {
                    UIImage.downsampledRetina(from: data, maxPixelDimension: 840)
                }.value
                if let image = decoded {
                    ensureCacheDirs()
                    try? data.write(to: targetDiskURL, options: .atomic)
                    memCache.setObject(image, forKey: pack.id as NSString)
                    thumbnails[pack.id] = image
                    return
                }
            } catch {
                continue
            }
        }
    }

    func downloadedVaultItem(for pack: CloudWallpaperPack, in items: [TendiesVaultItem]) -> TendiesVaultItem? {
        items.first { $0.cloudPackID == pack.id }
    }

    func downloadedCommunityVaultItem(for pack: CommunityWallpaperPack, in items: [TendiesVaultItem]) -> TendiesVaultItem? {
        items.first { $0.cloudPackID == pack.cloudPackID }
    }

    func downloadAndImport(pack: CloudWallpaperPack) async throws -> TendiesVaultItem {
        cancelActiveDownload()
        let task = Task<TendiesVaultItem, Error> {
            activeDownloadID = pack.id
            downloadProgressByID[pack.id] = 0.02
            defer {
                downloadProgressByID.removeValue(forKey: pack.id)
                if activeDownloadID == pack.id {
                    activeDownloadID = nil
                }
                activeDownloadTask = nil
            }

            let rawCandidates = Self.buildRepoURLs(
                pathOrURL: pack.packagePath,
                repoSlug: AppSourceManager.shared.effectiveRepoSlug,
                branch: "main"
            )
            let urls = await CamloEndpointRanker.shared.prioritize(rawCandidates)
            guard !urls.isEmpty else {
                throw URLError(.badURL)
            }

            let tempURL: URL
            do {
                tempURL = try await downloadVerifiedArchive(
                    from: urls,
                    trackID: pack.id,
                    expectedSize: Int64(pack.sizeBytes),
                    expectedSHA256: pack.sha256.isEmpty ? nil : pack.sha256,
                    isOfficialChannel: true
                )
            } catch {
                if (error as NSError).code == 404 {
                    throw NSError(
                        domain: "CloudGallery",
                        code: 404,
                        userInfo: [
                            NSLocalizedDescriptionKey: Bi(
                                "Camlo 官方仓库当前为私有状态（HTTP 404），请等待作者公开仓库后再下载官方云端包；您可先在「CAPlayground / Nugget」频道正常下载社区壁纸，或在首页使用内置 6 套获奖风光预设。",
                                "Kianuni/Camlo is currently private (HTTP 404), so official cloud packs cannot be fetched remotely yet. Use CAPlayground / Nugget channels or the 6 built-in Landscapes."
                            )
                        ]
                    )
                }
                throw error
            }
            defer { try? FileManager.default.removeItem(at: tempURL) }
            try Task.checkCancellation()

            downloadProgressByID[pack.id] = 0.97
            let sizeText = pack.sizeBytes > 0 ? " · \(pack.formattedSize)" : ""
            let summary = "\(pack.localizedBadge)\(sizeText)"
            let imported = try TendiesVaultStore.shared.importExternalTendies(
                from: tempURL,
                preferredTitle: pack.localizedTitle,
                preferredKind: pack.category == "morph" ? .morph : .video,
                preferredSummary: summary,
                cloudPackID: pack.id
            )
            downloadProgressByID[pack.id] = 1.0
            return imported
        }
        activeDownloadTask = task
        return try await task.value
    }

    func downloadAndImportCommunity(pack: CommunityWallpaperPack) async throws -> TendiesVaultItem {
        cancelActiveDownload()
        let task = Task<TendiesVaultItem, Error> {
            activeDownloadID = pack.id
            downloadProgressByID[pack.id] = 0.02
            defer {
                downloadProgressByID.removeValue(forKey: pack.id)
                if activeDownloadID == pack.id {
                    activeDownloadID = nil
                }
                activeDownloadTask = nil
            }

            let urls = await CamloEndpointRanker.shared.prioritize(pack.packageCandidateURLs)
            guard !urls.isEmpty else {
                throw URLError(.badURL)
            }

            let tempURL = try await downloadVerifiedArchive(
                from: urls,
                trackID: pack.id,
                expectedSize: 0,
                expectedSHA256: nil,
                isOfficialChannel: false
            )
            defer { try? FileManager.default.removeItem(at: tempURL) }
            try Task.checkCancellation()

            downloadProgressByID[pack.id] = 0.97
            let preferredSummary: String? = pack.author.isEmpty
                ? nil
                : "\(pack.channel.shortTitle) · \(pack.displayAuthor)"
            let imported = try TendiesVaultStore.shared.importExternalTendies(
                from: tempURL,
                preferredTitle: pack.name,
                preferredKind: .imported,
                preferredSummary: preferredSummary,
                cloudPackID: pack.cloudPackID
            )
            downloadProgressByID[pack.id] = 1.0
            return imported
        }
        activeDownloadTask = task
        return try await task.value
    }

    private func downloadVerifiedArchive(
        from urls: [URL],
        trackID: String,
        expectedSize: Int64,
        expectedSHA256: String?,
        isOfficialChannel: Bool
    ) async throws -> URL {
        var httpStatusCodes: [Int] = []
        var nonTLSError: Error?
        var lastError: Error?

        for url in urls {
            try Task.checkCancellation()
            let attemptStart = CFAbsoluteTimeGetCurrent()
            do {
                let tempURL = try await downloadArchiveFile(
                    from: url,
                    trackID: trackID,
                    expectedSize: expectedSize
                )

                if let expectedSHA256, !expectedSHA256.isEmpty {
                    downloadProgressByID[trackID] = 0.95
                    let digestHex = try await Task.detached(priority: .userInitiated) {
                        let fileData = try Data(contentsOf: tempURL, options: .mappedIfSafe)
                        let hash = SHA256.hash(data: fileData)
                        return hash.map { String(format: "%02x", $0) }.joined()
                    }.value
                    guard digestHex.lowercased() == expectedSHA256.lowercased() else {
                        try? FileManager.default.removeItem(at: tempURL)
                        throw NSError(
                            domain: "CloudGallery",
                            code: -99,
                            userInfo: [
                                NSLocalizedDescriptionKey: Bi(
                                    "SHA-256 校验未通过，文件可能损坏或被劫持",
                                    "SHA-256 verification failed for \(trackID)"
                                )
                            ]
                        )
                    }
                }

                let elapsed = max(0.05, CFAbsoluteTimeGetCurrent() - attemptStart)
                await CamloEndpointRanker.shared.recordSuccess(for: url, rtt: min(elapsed, 8.0))
                return tempURL
            } catch is CancellationError {
                throw CancellationError()
            } catch let urlError as URLError {
                if urlError.code == .cancelled || Task.isCancelled {
                    throw CancellationError()
                }
                await CamloEndpointRanker.shared.recordTransportFailure(for: url)
                lastError = urlError
                let isTLSOrBlock = urlError.code == .secureConnectionFailed
                    || urlError.code == .serverCertificateUntrusted
                    || urlError.code == .cannotConnectToHost
                    || urlError.code == .timedOut
                if !isTLSOrBlock {
                    nonTLSError = urlError
                }
            } catch {
                if Task.isCancelled {
                    throw CancellationError()
                }
                let nsErr = error as NSError
                if nsErr.domain == "CloudGallery", (400...599).contains(nsErr.code) {
                    httpStatusCodes.append(nsErr.code)
                }
                nonTLSError = error
                lastError = error
            }
        }

        if !httpStatusCodes.isEmpty, httpStatusCodes.allSatisfy({ $0 == 404 }) {
            let count = packs.count
            let msg: String
            if isOfficialChannel {
                msg = Bi(
                    "Camlo 官方仓库当前处于私有测试状态（HTTP 404）。如需内测在线下载全部 \(count) 套官方包，可在「系统状态 → 软件源订阅 → 高级」填写 GitHub Token；待仓库公开后即可免配置直接下载，CAPlayground / Nugget 社区库当前可直接下载。",
                    "Kianuni/Camlo is currently private (HTTP 404). To test downloading all \(count) official packs while private, add a GitHub Token in System & Settings -> App Source -> Advanced; CAPlayground & Nugget channels work now."
                )
            } else {
                msg = Bi(
                    "远端仓库未找到该壁纸文件（HTTP 404），可能已被原作者移动或重命名",
                    "Wallpaper archive not found in remote repository (HTTP 404)."
                )
            }
            throw NSError(
                domain: "CloudGallery",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }

        if let lastURLErr = lastError as? URLError,
           AppSourceManager.prefersCNMirror,
           let preferredErr = nonTLSError,
           lastURLErr.code == .secureConnectionFailed
            || lastURLErr.code == .serverCertificateUntrusted
            || lastURLErr.code == .cannotConnectToHost
            || lastURLErr.code == .timedOut {
            throw preferredErr
        }

        throw lastError ?? NSError(
            domain: "CloudGallery",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: Bi("下载 .tendies 失败，请切换网络线路或重试", "Failed to download .tendies archive")]
        )
    }

    private func downloadArchiveFile(from url: URL, trackID: String, expectedSize: Int64) async throws -> URL {
        let safeTrack = trackID.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud_\(safeTrack)_\(UUID().uuidString.prefix(8)).tendies")
        let fm = FileManager.default
        if fm.fileExists(atPath: tempFile.path) {
            try? fm.removeItem(at: tempFile)
        }

        var didKeepFile = false
        defer {
            if !didKeepFile {
                try? fm.removeItem(at: tempFile)
            }
        }

        let tracker = DownloadProgressTracker()
        let delegate = ArchiveDownloadSessionDelegate(destinationURL: tempFile) { [weak self] written, totalExpected in
            let denominator = totalExpected > 0 ? totalExpected : expectedSize
            guard denominator > 0 else { return }
            let frac = min(0.93, max(0.04, Double(written) / Double(denominator) * 0.93))
            guard tracker.shouldEmit(fraction: frac) else { return }
            Task { @MainActor [weak self] in
                guard let self, self.activeDownloadID == trackID else { return }
                self.downloadProgressByID[trackID] = frac
            }
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = false
        config.allowsCellularAccess = true
        config.httpAdditionalHeaders = [
            "User-Agent": "Camlo/\(CamloDevice.appVersion)",
            "Accept-Encoding": "identity"
        ]
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("Camlo/\(CamloDevice.appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.assumesHTTP3Capable = false
        AppSourceManager.applyGitHubAuthIfNeeded(to: &request)

        let cancelBox = DownloadTaskCancelBox()
        let (_, httpResponse) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.attach(continuation: continuation)
                let dlTask = session.downloadTask(with: request)
                if cancelBox.setTask(dlTask) {
                    dlTask.resume()
                } else {
                    dlTask.cancel()
                }
            }
        } onCancel: {
            cancelBox.cancel()
        }

        try Task.checkCancellation()

        if let http = httpResponse, !(200...299).contains(http.statusCode) {
            throw NSError(
                domain: "CloudGallery",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
        }

        let attrs = try? fm.attributesOfItem(atPath: tempFile.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        if fileSize < 512 {
            throw NSError(
                domain: "CloudGallery",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: Bi("下载内容过小或为空，可能被镜像节点拦截", "Downloaded archive is empty or invalid")]
            )
        }

        let magicData: Data
        do {
            let readHandle = try FileHandle(forReadingFrom: tempFile)
            defer { try? readHandle.close() }
            magicData = (try? readHandle.read(upToCount: 16)) ?? Data()
        }

        let prefixBytes = [UInt8](magicData.prefix(4))
        let isZIP = prefixBytes == [0x50, 0x4B, 0x03, 0x04] || prefixBytes == [0x50, 0x4B, 0x05, 0x06]
        if !isZIP {
            if let headStr = String(data: magicData, encoding: .utf8)?.lowercased(),
               headStr.contains("<html") || headStr.contains("<!doc") {
                throw NSError(
                    domain: "CloudGallery",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: Bi("镜像节点返回网页而非壁纸包，请切换节点重试", "Mirror returned HTML instead of archive")]
                )
            }
            throw NSError(
                domain: "CloudGallery",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: Bi("远端文件非有效 .tendies 压缩包，已尝试备用线路", "Remote file is not a valid ZIP/.tendies archive")]
            )
        }

        didKeepFile = true
        return tempFile
    }
}

private final class DownloadTaskCancelBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDownloadTask?
    private var isCancelled = false

    func setTask(_ task: URLSessionDownloadTask) -> Bool {
        lock.lock()
        self.task = task
        let cancelled = self.isCancelled
        lock.unlock()
        return !cancelled
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let current = task
        lock.unlock()
        current?.cancel()
    }
}

private final class DownloadProgressTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var lastFraction: Double = 0
    private var lastTimestamp: CFAbsoluteTime = 0

    func shouldEmit(fraction: Double) -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        defer { lock.unlock() }
        if (fraction - lastFraction) >= 0.015 || (now - lastTimestamp) >= 0.10 {
            lastFraction = fraction
            lastTimestamp = now
            return true
        }
        return false
    }
}

private final class ArchiveDownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let destinationURL: URL
    private let onProgress: @Sendable (Int64, Int64) -> Void
    private var continuation: CheckedContinuation<(URL, HTTPURLResponse?), Error>?
    private var movedToDestination = false
    private var moveError: Error?

    init(
        destinationURL: URL,
        onProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
        super.init()
    }

    func attach(continuation: CheckedContinuation<(URL, HTTPURLResponse?), Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    private func takeContinuation() -> CheckedContinuation<(URL, HTTPURLResponse?), Error>? {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        return cont
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: location, to: destinationURL)
            lock.lock()
            movedToDestination = true
            lock.unlock()
        } catch {
            lock.lock()
            moveError = error
            lock.unlock()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let cont = takeContinuation() else { return }
        if let error {
            cont.resume(throwing: error)
            return
        }
        lock.lock()
        let didMove = movedToDestination
        let capturedMoveError = moveError
        lock.unlock()

        if let capturedMoveError {
            cont.resume(throwing: capturedMoveError)
            return
        }
        guard didMove else {
            cont.resume(throwing: NSError(
                domain: "CloudGallery",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: Bi("下载完成但未找到本地临时文件", "Download finished without output file")]
            ))
            return
        }
        cont.resume(returning: (destinationURL, task.response as? HTTPURLResponse))
    }
}

private extension Color {
    init(camloHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
