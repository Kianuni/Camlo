import Foundation
import SwiftUI
import UIKit
import CryptoKit
import Combine

enum CloudWallpaperCategory: String, CaseIterable, Identifiable {
    case all
    case anime
    case morph
    case duo
    case motion

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all:
            return Bi("全部云端", "All Packs")
        case .anime:
            return Bi("次元 3D", "Anime 3D")
        case .morph:
            return Bi("景深变身", "Depth Morph")
        case .duo:
            return Bi("Duo 双屏", "iPhone Duo")
        case .motion:
            return Bi("无缝动态", "Motion Loops")
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

    private static let seedPacksA: [CloudWallpaperPack] = [
        CloudWallpaperPack(
            id: "rembrandt_cellist_reverie",
            posterSeedId: 18921,
            category: "morph",
            kind: "morphPair",
            titleZh: "沉思琴者 · 暗金厚涂",
            titleEn: "The Cellist · Chiaroscuro Reverie",
            subtitleZh: "伦勃朗与萨金特粗亚麻布厚涂：暗褐沉思 → 戏剧性暖金明暗对照拉响琴弦",
            subtitleEn: "Rembrandt & Sargent oil on coarse linen: tenebrist silence to golden impasto resonance",
            badgeZh: "古典油画",
            badgeEn: "Old Master",
            tagsZh: ["伦勃朗光", "粗麻厚涂", "清漆裂纹"],
            tagsEn: ["Rembrandt", "Impasto", "Chiaroscuro"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/rembrandt_cellist_reverie.tendies",
            thumbPath: "wallpapers/thumbs/rembrandt_cellist_reverie.jpg",
            previewPath: "wallpapers/previews/rembrandt_cellist_reverie.webp",
            sizeBytes: 3037087,
            sha256: "f46c821ddfbf02fa09fcc7914e1ce717ee72a2f7deeed5a8748d72c62d6b68a9",
            fps: nil,
            frameCount: nil,
            accentHex: "#B45309"
        ),
        CloudWallpaperPack(
            id: "vermeer_window_letter",
            posterSeedId: 18922,
            category: "morph",
            kind: "morphPair",
            titleZh: "代尔夫特 · 珠光静室",
            titleEn: "Delft Window · Pearl Quietude",
            subtitleZh: "维米尔古典透明罩染：幽蓝晨室读信 → 推窗斜阳点亮柠檬黄丝袖与珍珠耳坠",
            subtitleEn: "Vermeer oil glazing on linen: cool shuttered morning to luminous Delft window light",
            badgeZh: "古典油画",
            badgeEn: "Dutch Master",
            tagsZh: ["维米尔光", "透明罩染", "馆藏肌理"],
            tagsEn: ["Vermeer", "Oil Glazing", "Fine Art"],
            transitionPreset: "crossfade",
            particlePreset: "sunbeamRays",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/vermeer_window_letter.tendies",
            thumbPath: "wallpapers/thumbs/vermeer_window_letter.jpg",
            previewPath: "wallpapers/previews/vermeer_window_letter.webp",
            sizeBytes: 2355525,
            sha256: "761d4c79ff510f99cd7642fcd6384b3af3c6de84c2d565c35f701fd69f269c49",
            fps: nil,
            frameCount: nil,
            accentHex: "#2563EB"
        ),
        CloudWallpaperPack(
            id: "caravaggio_pomegranate_vanitas",
            posterSeedId: 18923,
            category: "morph",
            kind: "morphPair",
            titleZh: "卡拉瓦乔 · 暗夜石榴",
            titleEn: "Caravaggio · Tenebrist Still Life",
            subtitleZh: "巴洛克暗色调主义静物：石台幽影 → 一束地窖斜光劈开石榴红宝石罩染",
            subtitleEn: "Caravaggist tenebrist bodegón on dark linen: cellar beam igniting ruby pomegranate glazes",
            badgeZh: "巴洛克画派",
            badgeEn: "Tenebrism",
            tagsZh: ["卡拉瓦乔", "暗色调派", "古典静物"],
            tagsEn: ["Caravaggio", "Tenebrism", "Still Life"],
            transitionPreset: "aodGaze",
            particlePreset: "none",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/caravaggio_pomegranate_vanitas.tendies",
            thumbPath: "wallpapers/thumbs/caravaggio_pomegranate_vanitas.jpg",
            previewPath: "wallpapers/previews/caravaggio_pomegranate_vanitas.webp",
            sizeBytes: 2441351,
            sha256: "09923c5008e96d4f6b2e3e07f0f0e344af0c1123ae3982009326e0ac194e2b38",
            fps: nil,
            frameCount: nil,
            accentHex: "#991B1B"
        ),
        CloudWallpaperPack(
            id: "latour_candlelight_vigil",
            posterSeedId: 18924,
            category: "motion",
            kind: "motionLoop",
            titleZh: "拉图尔 · 烛影守夜",
            titleEn: "De La Tour · Candlelight Vigil",
            subtitleZh: "乔治·德·拉图尔巴洛克烛火油画 · 掌心掩映朱砂暖光在粗麻裂纹间静谧呼吸",
            subtitleEn: "Georges de La Tour Baroque tenebrist candle flame breathing softly across oil craquelure",
            badgeZh: "馆藏动态",
            badgeEn: "Living Oil",
            tagsZh: ["拉图尔烛光", "明暗对照", "粗麻裂纹"],
            tagsEn: ["De La Tour", "Candlelight", "Baroque"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/latour_candlelight_vigil.tendies",
            thumbPath: "wallpapers/thumbs/latour_candlelight_vigil.jpg",
            previewPath: "wallpapers/previews/latour_candlelight_vigil.webp",
            sizeBytes: 2975349,
            sha256: "696254c1cdd7c69abbfe58b56377f0258691c7abc551066bf0787f4680a3efa2",
            fps: 8,
            frameCount: 16,
            accentHex: "#C2410C"
        ),
        CloudWallpaperPack(
            id: "sargent_venetian_gondola",
            posterSeedId: 18925,
            category: "morph",
            kind: "morphPair",
            titleZh: "威尼斯水巷 · 萨金特笔意",
            titleEn: "Venetian Canal · Bravura Nocturne",
            subtitleZh: "萨金特潇洒写意湿画法：蓝灰暮色窄巷贡多拉 → 古老宫窗泻落流金水影",
            subtitleEn: "Sargent alla prima oil on linen: dusk Venetian back-canal lit by warm palazzo windows",
            badgeZh: "写意油画",
            badgeEn: "Bravura Oil",
            tagsZh: ["萨金特笔触", "刮刀水影", "威尼斯"],
            tagsEn: ["Sargent", "Alla Prima", "Venice"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/sargent_venetian_gondola.tendies",
            thumbPath: "wallpapers/thumbs/sargent_venetian_gondola.jpg",
            previewPath: "wallpapers/previews/sargent_venetian_gondola.webp",
            sizeBytes: 1521681,
            sha256: "6d0ee4320cef06796873a81cd08b353e0da52f059753f579079be8e3c955aa6b",
            fps: nil,
            frameCount: nil,
            accentHex: "#0F766E"
        ),
        CloudWallpaperPack(
            id: "velazquez_atelier_easel",
            posterSeedId: 18926,
            category: "morph",
            kind: "morphPair",
            titleZh: "马德里画室 · 银灰空气",
            titleEn: "Madrid Atelier · Silver Velatura",
            subtitleZh: "委拉斯开兹宫廷画室空气透视：冷寂木画架背影 → 高窗暖银天光漫入尘埃",
            subtitleEn: "Velázquez atmospheric studio oil on linen: shadowed easel bathed in silver-gold clerestory air",
            badgeZh: "古典油画",
            badgeEn: "Spanish Master",
            tagsZh: ["委拉斯开兹", "空气透视", "银灰调子"],
            tagsEn: ["Velázquez", "Atmospheric", "Atelier"],
            transitionPreset: "aodGaze",
            particlePreset: "sunbeamRays",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/velazquez_atelier_easel.tendies",
            thumbPath: "wallpapers/thumbs/velazquez_atelier_easel.jpg",
            previewPath: "wallpapers/previews/velazquez_atelier_easel.webp",
            sizeBytes: 1282267,
            sha256: "e05e3e59c4b9c394922ba0a01ed6b153094c2ea8f2ce1aba3f9db9354ee65f54",
            fps: nil,
            frameCount: nil,
            accentHex: "#78716C"
        ),
        CloudWallpaperPack(
            id: "leonardo_sfumato_valley",
            posterSeedId: 18927,
            category: "morph",
            kind: "morphPair",
            titleZh: "达芬奇晕涂 · 远山暮霭",
            titleEn: "Renaissance Valley · Sfumato Mist",
            subtitleZh: "文艺复兴杨木板油彩与烟熏晕涂法：青黛远山迷雾 → 琥珀金暮光层层渗透河谷",
            subtitleEn: "Leonardo sfumato oil on poplar panel: blue-earth crags suffused with amber-olive twilight glazes",
            badgeZh: "文艺复兴",
            badgeEn: "Renaissance",
            tagsZh: ["达芬奇晕涂", "古典罩染", "木板裂纹"],
            tagsEn: ["Leonardo", "Sfumato", "Old Master"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/leonardo_sfumato_valley.tendies",
            thumbPath: "wallpapers/thumbs/leonardo_sfumato_valley.jpg",
            previewPath: "wallpapers/previews/leonardo_sfumato_valley.webp",
            sizeBytes: 1397221,
            sha256: "bd94765f05cca7a11a8fc2e6be068961c8a0dfd893bb25133f1d1767fd8c53a2",
            fps: nil,
            frameCount: nil,
            accentHex: "#A16207"
        ),
        CloudWallpaperPack(
            id: "sorolla_coastal_garden_dusk",
            posterSeedId: 18928,
            category: "morph",
            kind: "morphPair",
            titleZh: "海岸橄榄园 · 外光碎金",
            titleEn: "Coastal Garden · Plein-Air Dusk",
            subtitleZh: "莫奈与索罗利亚外光派刮刀厚涂：暮蓝海岸橄榄树 → 斑驳暖金斜阳洒满陶土小径",
            subtitleEn: "Monet & Sorolla plein-air impasto oil: dappled Mediterranean sunset piercing olive trees",
            badgeZh: "印象外光",
            badgeEn: "Plein Air",
            tagsZh: ["索罗利亚", "刮刀厚涂", "破碎色彩"],
            tagsEn: ["Sorolla", "Impasto", "Plein Air"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/sorolla_coastal_garden_dusk.tendies",
            thumbPath: "wallpapers/thumbs/sorolla_coastal_garden_dusk.jpg",
            previewPath: "wallpapers/previews/sorolla_coastal_garden_dusk.webp",
            sizeBytes: 2110112,
            sha256: "e6887950b98dbf56187dff2ad9dd86afc2818e8fe0b789f3e5fe0e870df939bd",
            fps: nil,
            frameCount: nil,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "monet_rouen_cathedral_light",
            posterSeedId: 18929,
            category: "morph",
            kind: "morphPair",
            titleZh: "鲁昂石壁 · 晨昏色阶",
            titleEn: "Rouen Façade · Chromatic Crust",
            subtitleZh: "莫奈鲁昂大教堂干笔矿石厚涂：冷紫晨雾石拱 → 破晓玫瑰赭金光影浮雕震颤",
            subtitleEn: "Monet Rouen Cathedral encrusted oil impasto shifting from misty mauve-slate to rose-ochre dawn",
            badgeZh: "印象派馆藏",
            badgeEn: "Impressionism",
            tagsZh: ["莫奈大教堂", "干笔堆叠", "色彩并置"],
            tagsEn: ["Monet", "Impasto Crust", "Optical"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/monet_rouen_cathedral_light.tendies",
            thumbPath: "wallpapers/thumbs/monet_rouen_cathedral_light.jpg",
            previewPath: "wallpapers/previews/monet_rouen_cathedral_light.webp",
            sizeBytes: 2083221,
            sha256: "2793626eaeb405ba7f5322c9d6a6831d9a337ea271e22d33df5d9607b439947b",
            fps: nil,
            frameCount: nil,
            accentHex: "#C084FC"
        ),
        CloudWallpaperPack(
            id: "vangogh_cypress_wheatfield",
            posterSeedId: 18930,
            category: "motion",
            kind: "motionLoop",
            titleZh: "圣雷米丝柏 · 旋涡星夜",
            titleEn: "Saint-Rémy · Impasto Cypress",
            subtitleZh: "梵高圣雷米粗黄麻布雕塑感厚涂 · 普鲁士蓝旋涡夜空与金麦浪静默脉动",
            subtitleEn: "Van Gogh sculptural oil impasto on jute: swirling Prussian-blue night and ochre wheat breathing",
            badgeZh: "馆藏动态",
            badgeEn: "Living Impasto",
            tagsZh: ["梵高厚涂", "圣雷米", "黄麻画布"],
            tagsEn: ["Van Gogh", "Impasto", "Post-Impressionism"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/vangogh_cypress_wheatfield.tendies",
            thumbPath: "wallpapers/thumbs/vangogh_cypress_wheatfield.jpg",
            previewPath: "wallpapers/previews/vangogh_cypress_wheatfield.webp",
            sizeBytes: 5345701,
            sha256: "bd982863a695307830a92aa429332a903abc7593eb349b4561470cf152a181fb",
            fps: 8,
            frameCount: 16,
            accentHex: "#CA8A04"
        ),
        CloudWallpaperPack(
            id: "sorolla_valencia_white_sail",
            posterSeedId: 18931,
            category: "morph",
            kind: "morphPair",
            titleZh: "瓦伦西亚 · 逆光白帆",
            titleEn: "Valencia Surf · Luminous Sail",
            subtitleZh: "索罗利亚西班牙光影主义：珍珠灰浅滩静帆 → 落日琥珀金逆光穿透亚麻风帆",
            subtitleEn: "Sorolla Spanish Luminism oil: pearl-gray surf ignited by backlit amber sun through linen sail",
            badgeZh: "外光巨匠",
            badgeEn: "Luminism",
            tagsZh: ["索罗利亚", "逆光白帆", "潇洒笔触"],
            tagsEn: ["Sorolla", "Luminism", "Seascape"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/sorolla_valencia_white_sail.tendies",
            thumbPath: "wallpapers/thumbs/sorolla_valencia_white_sail.jpg",
            previewPath: "wallpapers/previews/sorolla_valencia_white_sail.webp",
            sizeBytes: 1646500,
            sha256: "304e336eb2677b9564e356f262eb024f5484cac0af0cfafed29094e85fdb0cd8",
            fps: nil,
            frameCount: nil,
            accentHex: "#EA580C"
        ),
        CloudWallpaperPack(
            id: "corot_silver_birch_pond",
            posterSeedId: 18932,
            category: "morph",
            kind: "morphPair",
            titleZh: "枫丹白露 · 银桦诗意",
            titleEn: "Ville-d'Avray · Silver Corot",
            subtitleZh: "巴比松画派柯罗抒情风景：羽毛笔触银灰晨雾池塘 → 柔和蜜金晨光漫染白桦林",
            subtitleEn: "Corot Barbizon lyrical oil on linen: feathery silver-gray dawn mist warming into honeyed morning",
            badgeZh: "巴比松派",
            badgeEn: "Barbizon Oil",
            tagsZh: ["柯罗银灰", "抒情风景", "古典亚麻"],
            tagsEn: ["Corot", "Barbizon", "Pastoral"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/corot_silver_birch_pond.tendies",
            thumbPath: "wallpapers/thumbs/corot_silver_birch_pond.jpg",
            previewPath: "wallpapers/previews/corot_silver_birch_pond.webp",
            sizeBytes: 1648295,
            sha256: "c7618e35d3fcb0360cca843ab37509114a33438908859a3f1eddadc8f4cbdde2",
            fps: nil,
            frameCount: nil,
            accentHex: "#64748B"
        ),
        CloudWallpaperPack(
            id: "pissarro_rainy_boulevard_lamp",
            posterSeedId: 18933,
            category: "morph",
            kind: "morphPair",
            titleZh: "蒙马特雨暮 · 暖灯石街",
            titleEn: "Montmartre Rain · Oil Dusk",
            subtitleZh: "毕沙罗印象派雨夜巴黎：湿冷石板灰蓝街景 → 煤气街灯与咖啡馆流淌碎金倒影",
            subtitleEn: "Pissarro Impressionist rainy Paris dusk: wet slate cobblestones streaking with warm amber lamps",
            badgeZh: "印象派馆藏",
            badgeEn: "Impressionism",
            tagsZh: ["毕沙罗", "巴黎雨街", "冷暖并置"],
            tagsEn: ["Pissarro", "Paris Rain", "Broken Color"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/pissarro_rainy_boulevard_lamp.tendies",
            thumbPath: "wallpapers/thumbs/pissarro_rainy_boulevard_lamp.jpg",
            previewPath: "wallpapers/previews/pissarro_rainy_boulevard_lamp.webp",
            sizeBytes: 1797574,
            sha256: "49c1a626de9e7d550f0ded076bdbdec6d60eebe5449aa9f934e7eee2099b8ba1",
            fps: nil,
            frameCount: nil,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "klimt_birch_forest_gold",
            posterSeedId: 18934,
            category: "morph",
            kind: "morphPair",
            titleZh: "桦林秋毯 · 维也纳金叶",
            titleEn: "Attersee Woods · Gilded Moss",
            subtitleZh: "克林姆特分离派白桦林：静谧红褐落叶地毯 → 斜阳点燃斑驳古旧金箔与赤铜肌理",
            subtitleEn: "Klimt Vienna Secession birch woods: russet leaf carpet ignited with antique gold-leaf mosaic",
            badgeZh: "分离派金箔",
            badgeEn: "Secession Gold",
            tagsZh: ["克林姆特", "古典金箔", "马赛克笔触"],
            tagsEn: ["Klimt", "Gold Leaf", "Secession"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/klimt_birch_forest_gold.tendies",
            thumbPath: "wallpapers/thumbs/klimt_birch_forest_gold.jpg",
            previewPath: "wallpapers/previews/klimt_birch_forest_gold.webp",
            sizeBytes: 2326580,
            sha256: "7d2e1cfdfe6dece43d5360c62d803a3a159e94fc8a346258ce4cffc144381cfa",
            fps: nil,
            frameCount: nil,
            accentHex: "#B45309"
        ),
        CloudWallpaperPack(
            id: "friedrich_wanderer_sea_fog",
            posterSeedId: 18935,
            category: "morph",
            kind: "morphPair",
            titleZh: "吕根白崖 · 崇高云海",
            titleEn: "Chalk Cliffs · Romantic Fog",
            subtitleZh: "弗里德里希德国浪漫主义：孤绝玄武岩与靛灰雾海 → 破晓珍珠琥珀天光普照万壑",
            subtitleEn: "Caspar David Friedrich Romantic oil: solitary crag over indigo fog unveiled in pearl-amber dawn",
            badgeZh: "浪漫崇高",
            badgeEn: "Romanticism",
            tagsZh: ["弗里德里希", "云海崇高", "透明罩染"],
            tagsEn: ["Friedrich", "Sublime", "Romanticism"],
            transitionPreset: "curtainRise",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/friedrich_wanderer_sea_fog.tendies",
            thumbPath: "wallpapers/thumbs/friedrich_wanderer_sea_fog.jpg",
            previewPath: "wallpapers/previews/friedrich_wanderer_sea_fog.webp",
            sizeBytes: 1203628,
            sha256: "ad9296f770c6142e2ad2ea67563bdde73f5d78783bd9813d2589dc8fd9698316",
            fps: nil,
            frameCount: nil,
            accentHex: "#475569"
        ),
        CloudWallpaperPack(
            id: "hammershoi_dust_sunbeam_rooms",
            posterSeedId: 18936,
            category: "motion",
            kind: "motionLoop",
            titleZh: "哥本哈根 · 静室斜阳",
            titleEn: "Strandgade · Silent Sunbeam",
            subtitleZh: "哈默修伊北欧静寂主义粗麻油画 · 灰白木门与橡木地板上的几何斜阳静默流转",
            subtitleEn: "Vilhelm Hammershøi quietist Nordic interior with dusty afternoon sunlight breathing on linen",
            badgeZh: "馆藏动态",
            badgeEn: "Nordic Oil",
            tagsZh: ["哈默修伊", "北欧静室", "克制灰调"],
            tagsEn: ["Hammershøi", "Quietism", "Interior"],
            transitionPreset: "crossfade",
            particlePreset: "sunbeamRays",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/hammershoi_dust_sunbeam_rooms.tendies",
            thumbPath: "wallpapers/thumbs/hammershoi_dust_sunbeam_rooms.jpg",
            previewPath: "wallpapers/previews/hammershoi_dust_sunbeam_rooms.webp",
            sizeBytes: 2807688,
            sha256: "321c72b11d8d71053bb7ccc89941b131b6d4ccea1c88ec5d775e4c842fd6168c",
            fps: 8,
            frameCount: 16,
            accentHex: "#94A3B8"
        ),
        CloudWallpaperPack(
            id: "wyeth_windblown_lace_window",
            posterSeedId: 18937,
            category: "morph",
            kind: "morphPair",
            titleZh: "克里斯蒂娜之窗 · 蛋彩孤风",
            titleEn: "Maine Window · Egg Tempera",
            subtitleZh: "安德鲁·怀斯木板蛋彩干笔写实：荒原旧窗静止薄纱 → 海风拂起蕾丝映出金秋草坡",
            subtitleEn: "Andrew Wyeth dry-brush egg tempera on gesso: coastal breeze lifting frayed lace over Maine hills",
            badgeZh: "蛋彩写实",
            badgeEn: "Egg Tempera",
            tagsZh: ["怀斯蛋彩", "干笔肌理", "孤寂现实"],
            tagsEn: ["Wyeth", "Tempera", "Realism"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/wyeth_windblown_lace_window.tendies",
            thumbPath: "wallpapers/thumbs/wyeth_windblown_lace_window.jpg",
            previewPath: "wallpapers/previews/wyeth_windblown_lace_window.webp",
            sizeBytes: 1824735,
            sha256: "657b60ec38a4fb93603c0e4b6b42c53ac497be3896dd84518a89a4ccb6ffa3a8",
            fps: nil,
            frameCount: nil,
            accentHex: "#A8A29E"
        ),
        CloudWallpaperPack(
            id: "aivazovsky_emerald_wave_moon",
            posterSeedId: 18938,
            category: "morph",
            kind: "morphPair",
            titleZh: "夜海琉璃 · 透光惊涛",
            titleEn: "Ninth Wave · Translucent Surge",
            subtitleZh: "艾瓦佐夫斯基浪漫海景多层罩染：冷银月夜墨绿涌浪 → 曙光穿透翡翠浪尖如琉璃发光",
            subtitleEn: "Aivazovsky marine oil velatura: moonlit midnight surge pierced by luminous jade-amber dawn",
            badgeZh: "海景巨匠",
            badgeEn: "Marine Oil",
            tagsZh: ["艾瓦佐夫斯基", "透光罩染", "琉璃巨浪"],
            tagsEn: ["Aivazovsky", "Velatura", "Seascape"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/aivazovsky_emerald_wave_moon.tendies",
            thumbPath: "wallpapers/thumbs/aivazovsky_emerald_wave_moon.jpg",
            previewPath: "wallpapers/previews/aivazovsky_emerald_wave_moon.webp",
            sizeBytes: 1559404,
            sha256: "da76c51dbe8b6a555761ea9dcd3956dddf679cbb61ffe5cbd54d0706808c3e3f",
            fps: nil,
            frameCount: nil,
            accentHex: "#0D9488"
        ),
        CloudWallpaperPack(
            id: "whistler_thames_nocturne_gold",
            posterSeedId: 18939,
            category: "motion",
            kind: "motionLoop",
            titleZh: "泰晤士夜曲 · 青金微星",
            titleEn: "Nocturne · Blue and Old Gold",
            subtitleZh: "惠斯勒色调主义稀薄松节油擦染 · 普鲁士蓝夜雾木桥与古金灯火微星缓缓浮动",
            subtitleEn: "Whistler Nocturne in Prussian blue and antique gold oil washes breathing over misty river",
            badgeZh: "馆藏动态",
            badgeEn: "Nocturne Oil",
            tagsZh: ["惠斯勒夜曲", "青金擦染", "色调主义"],
            tagsEn: ["Whistler", "Nocturne", "Tonalism"],
            transitionPreset: "crossfade",
            particlePreset: "fireflies",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/whistler_thames_nocturne_gold.tendies",
            thumbPath: "wallpapers/thumbs/whistler_thames_nocturne_gold.jpg",
            previewPath: "wallpapers/previews/whistler_thames_nocturne_gold.webp",
            sizeBytes: 2681689,
            sha256: "06432d9042af9a85dc812de7c3e28ac600acfff9e9b4309c439b8d960588a1bd",
            fps: 8,
            frameCount: 16,
            accentHex: "#1D4ED8"
        ),
        CloudWallpaperPack(
            id: "homer_rockbound_lighthouse_spray",
            posterSeedId: 18940,
            category: "morph",
            kind: "morphPair",
            titleZh: "缅因礁岸 · 怒海孤灯",
            titleEn: "Maine Coast · Lighthouse Spray",
            subtitleZh: "温斯洛·霍默粗犷刮刀油画：暴风暮色花岗岩孤塔 → 灯塔金光刺破盐雾与古铜晚霞",
            subtitleEn: "Winslow Homer palette-knife marine oil: storm-battered stone lighthouse igniting golden beacon",
            badgeZh: "写实海景",
            badgeEn: "American Oil",
            tagsZh: ["霍默刮刀", "怒海灯塔", "大地色盘"],
            tagsEn: ["Winslow Homer", "Palette Knife", "Lighthouse"],
            transitionPreset: "aodGaze",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/homer_rockbound_lighthouse_spray.tendies",
            thumbPath: "wallpapers/thumbs/homer_rockbound_lighthouse_spray.jpg",
            previewPath: "wallpapers/previews/homer_rockbound_lighthouse_spray.webp",
            sizeBytes: 2442431,
            sha256: "d5d488e97cf36cc51ebb6653b4978446033336437169780ebd9660324d325f20",
            fps: nil,
            frameCount: nil,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "redon_pastel_celestial_vase",
            posterSeedId: 18941,
            category: "morph",
            kind: "morphPair",
            titleZh: "奥迪隆雷东 · 粉彩梦境",
            titleEn: "Odilon Redon · Pastel Reverie",
            subtitleZh: "象征主义大师雷东羊皮纸粉彩：暮褐陶瓶暗影野花 → 青金石蓝与茜草粉彩如梦绽放",
            subtitleEn: "Odilon Redon Symbolist pastel on rag paper: shadowed stoneware bouquet blooming in lapis & rose",
            badgeZh: "象征粉彩",
            badgeEn: "Pastel Art",
            tagsZh: ["雷东粉彩", "象征主义", "丝绒纸纹"],
            tagsEn: ["Odilon Redon", "Pastel", "Symbolism"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/redon_pastel_celestial_vase.tendies",
            thumbPath: "wallpapers/thumbs/redon_pastel_celestial_vase.jpg",
            previewPath: "wallpapers/previews/redon_pastel_celestial_vase.webp",
            sizeBytes: 3252264,
            sha256: "621e0ec36b6668052e32e9feb0eff7533e652744008ecca4d3ba51de3b93a17d",
            fps: nil,
            frameCount: nil,
            accentHex: "#6366F1"
        ),
        CloudWallpaperPack(
            id: "mayuan_autumn_river_boat",
            posterSeedId: 18942,
            category: "morph",
            kind: "morphPair",
            titleZh: "秋江迷雾 · 马一角意境",
            titleEn: "Autumn River · Ma Yuan Silk",
            subtitleZh: "南宋马远院体古旧绢本：枯笔飞白寒江孤舟水墨 → 淡赭金秋晨霭轻染对角崖松",
            subtitleEn: "Song Dynasty Ma Yuan silk scroll: minimalist one-corner misty skiff warmed by faint ochre dawn",
            badgeZh: "宋画院体",
            badgeEn: "Song Imperial",
            tagsZh: ["马一角", "枯笔飞白", "古绢留白"],
            tagsEn: ["Ma Yuan", "Song Silk", "Feibai"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/mayuan_autumn_river_boat.tendies",
            thumbPath: "wallpapers/thumbs/mayuan_autumn_river_boat.jpg",
            previewPath: "wallpapers/previews/mayuan_autumn_river_boat.webp",
            sizeBytes: 1638236,
            sha256: "3aa1aab76a161a8d29c5fc99d2f46e1697530d14fb9fe1025f134c80180f5534",
            fps: nil,
            frameCount: nil,
            accentHex: "#78716C"
        ),
        CloudWallpaperPack(
            id: "guoxi_early_spring_jade_mist",
            posterSeedId: 18943,
            category: "motion",
            kind: "motionLoop",
            titleZh: "早春烟岚 · 郭熙卷云皴",
            titleEn: "Early Spring · Guo Xi Scroll",
            subtitleZh: "北宋郭熙《早春图》宫绢水墨意境 · 卷云皴巨嶂与蟹爪寒林间白练云气徐徐吐纳",
            subtitleEn: "Northern Song Guo Xi silk scroll: coiled-cloud crags and temple eaves breathing with silk mist",
            badgeZh: "宋画动态",
            badgeEn: "Living Scroll",
            tagsZh: ["郭熙早春", "卷云皴法", "三远留白"],
            tagsEn: ["Guo Xi", "Song Scroll", "Ink Mist"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/guoxi_early_spring_jade_mist.tendies",
            thumbPath: "wallpapers/thumbs/guoxi_early_spring_jade_mist.jpg",
            previewPath: "wallpapers/previews/guoxi_early_spring_jade_mist.webp",
            sizeBytes: 4374811,
            sha256: "5abde801a5def2a912c727f3fffd313305b9cc16d03431a21e2a8c5eb8c31a97",
            fps: 8,
            frameCount: 16,
            accentHex: "#57534E"
        ),
        CloudWallpaperPack(
            id: "huizong_auspicious_cranes_palace",
            posterSeedId: 18944,
            category: "morph",
            kind: "morphPair",
            titleZh: "瑞鹤凌霄 · 宣和院体",
            titleEn: "Auspicious Cranes · Imperial Silk",
            subtitleZh: "致敬宋徽宗《瑞鹤图》矿物石青古绢：暮霭宫檐双鹤静掠 → 金缕五色祥云群鹤翩然盘旋",
            subtitleEn: "Song Emperor Huizong mineral-azurite silk gongbi: twilight palace eaves to golden-cloud cranes",
            badgeZh: "宣和院体",
            badgeEn: "Imperial Gongbi",
            tagsZh: ["宋徽宗", "矿物石青", "工笔瑞鹤"],
            tagsEn: ["Huizong", "Azurite Silk", "Gongbi"],
            transitionPreset: "curtainRise",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/huizong_auspicious_cranes_palace.tendies",
            thumbPath: "wallpapers/thumbs/huizong_auspicious_cranes_palace.jpg",
            previewPath: "wallpapers/previews/huizong_auspicious_cranes_palace.webp",
            sizeBytes: 1383814,
            sha256: "6b812b84ff4c2fa90e201d81e1d5d71ee027674933724834522070f85a463e60",
            fps: nil,
            frameCount: nil,
            accentHex: "#1E40AF"
        ),
        CloudWallpaperPack(
            id: "xiagui_wind_rain_bamboo_pavilion",
            posterSeedId: 18945,
            category: "morph",
            kind: "morphPair",
            titleZh: "溪山霁雨 · 夏半边水墨",
            titleEn: "Misty Pavilion · Xia Gui Wash",
            subtitleZh: "南宋夏圭半边构图绢本泼墨：风雨疾竹水榭淋漓墨色 → 雨收云散夕照淡金映平湖",
            subtitleEn: "Southern Song Xia Gui silk wash: wind-swept feibai bamboo pavilion clearing into pale-gold dusk",
            badgeZh: "宋画院体",
            badgeEn: "Song Ink",
            tagsZh: ["夏半边", "泼墨飞白", "大面积留白"],
            tagsEn: ["Xia Gui", "Ink Wash", "Negative Space"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/xiagui_wind_rain_bamboo_pavilion.tendies",
            thumbPath: "wallpapers/thumbs/xiagui_wind_rain_bamboo_pavilion.jpg",
            previewPath: "wallpapers/previews/xiagui_wind_rain_bamboo_pavilion.webp",
            sizeBytes: 1798830,
            sha256: "f205c09a73d375a53e25164c09dd9af7c8030bac17ef8059c7f683541bffdc47",
            fps: nil,
            frameCount: nil,
            accentHex: "#6B7280"
        )
    ]

    private static let seedPacksB: [CloudWallpaperPack] = [
        CloudWallpaperPack(
            id: "mifu_cloudy_mountains_ink",
            posterSeedId: 18946,
            category: "motion",
            kind: "motionLoop",
            titleZh: "潇湘白云 · 米家水墨点",
            titleEn: "Cloudy Peaks · Mi Fu Ink Dots",
            subtitleZh: "北宋米芾父子米氏云山宣纸水墨 · 湿笔横点烟峦在漫山白雾与淡花青间悠然浮沉",
            subtitleEn: "Song literati Mi Fu wet-ink dot mountains breathing softly in absorbent Xuan paper river fog",
            badgeZh: "文人动态",
            badgeEn: "Literati Ink",
            tagsZh: ["米氏云山", "宣纸墨点", "潇湘烟雨"],
            tagsEn: ["Mi Fu", "Xuan Paper", "Literati"],
            transitionPreset: "crossfade",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/mifu_cloudy_mountains_ink.tendies",
            thumbPath: "wallpapers/thumbs/mifu_cloudy_mountains_ink.jpg",
            previewPath: "wallpapers/previews/mifu_cloudy_mountains_ink.webp",
            sizeBytes: 3859548,
            sha256: "cb1e11bdf374034560e5c92e4e45e333e2466b1b3d9c7491155de3bc129ae106",
            fps: 8,
            frameCount: 16,
            accentHex: "#475569"
        ),
        CloudWallpaperPack(
            id: "badashanren_lotus_kingfisher",
            posterSeedId: 18947,
            category: "morph",
            kind: "morphPair",
            titleZh: "墨荷孤禽 · 八大禅意留白",
            titleEn: "Ink Lotus · Bada Shanren Zen",
            subtitleZh: "八大山人陈年宣纸大写意：枯笔焦墨残荷孤鸟冷眼向天 → 一朵淡胭脂荷苞静默初绽",
            subtitleEn: "Bada Shanren zen xieyi ink on aged Xuan paper: solitary perched bird & budding rouge lotus",
            badgeZh: "文人写意",
            badgeEn: "Zen Xieyi",
            tagsZh: ["八大山人", "枯笔写意", "孤高禅意"],
            tagsEn: ["Bada Shanren", "Xieyi Ink", "Zen"],
            transitionPreset: "aodGaze",
            particlePreset: "none",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/badashanren_lotus_kingfisher.tendies",
            thumbPath: "wallpapers/thumbs/badashanren_lotus_kingfisher.jpg",
            previewPath: "wallpapers/previews/badashanren_lotus_kingfisher.webp",
            sizeBytes: 1513004,
            sha256: "69b3a04aef6066fea0bb283389416cc0e50b0deba6a7e7541548b206d74c9ca5",
            fps: nil,
            frameCount: nil,
            accentHex: "#78716C"
        ),
        CloudWallpaperPack(
            id: "song_plum_blossom_moonlight",
            posterSeedId: 18948,
            category: "morph",
            kind: "morphPair",
            titleZh: "暗香疏影 · 宋绢寒梅月色",
            titleEn: "Moonlit Plum · Song Silk Branch",
            subtitleZh: "南宋马麟茶褐古绢院体小品：铁线苍枝含苞冷寂 → 皓月流辉点亮蛤粉五瓣寒梅清芬",
            subtitleEn: "Southern Song Ma Lin dark tea-silk scroll: gnarled plum branch blooming with shell-white petals",
            badgeZh: "宋画小品",
            badgeEn: "Song Album",
            tagsZh: ["马麟寒梅", "茶褐古绢", "蛤粉点染"],
            tagsEn: ["Ma Lin", "Plum Blossom", "Song Silk"],
            transitionPreset: "crossfade",
            particlePreset: "sakura",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/song_plum_blossom_moonlight.tendies",
            thumbPath: "wallpapers/thumbs/song_plum_blossom_moonlight.jpg",
            previewPath: "wallpapers/previews/song_plum_blossom_moonlight.webp",
            sizeBytes: 1382280,
            sha256: "e1011f8f249bedca100549ce33aee9b9bdfb18f6e13b70859c350e1c9f0ddbe9",
            fps: nil,
            frameCount: nil,
            accentHex: "#A16207"
        ),
        CloudWallpaperPack(
            id: "hasui_zojoji_red_pagoda_snow",
            posterSeedId: 18949,
            category: "morph",
            kind: "morphPair",
            titleZh: "雪夜古刹 · 巴水木版拓印",
            titleEn: "Snowy Pagoda · Woodblock Night",
            subtitleZh: "川濑巴水新版画桑皮和纸木刻：深靛晕染雪松朱塔寒夜 → 古寺障子窗透出融融暖橘灯火",
            subtitleEn: "Kawase Hasui shin-hanga woodblock on washi: bokashi indigo snow pagoda lit by warm lantern glow",
            badgeZh: "新版画木刻",
            badgeEn: "Shin-hanga",
            tagsZh: ["川濑巴水", "木版摺痕", "雪夜古寺"],
            tagsEn: ["Kawase Hasui", "Woodblock", "Washi"],
            transitionPreset: "aodGaze",
            particlePreset: "snowfall",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/hasui_zojoji_red_pagoda_snow.tendies",
            thumbPath: "wallpapers/thumbs/hasui_zojoji_red_pagoda_snow.jpg",
            previewPath: "wallpapers/previews/hasui_zojoji_red_pagoda_snow.webp",
            sizeBytes: 2140744,
            sha256: "fc0ce97a77957eabf48789665b646a0d18da9e0e36ce98e3f7ab43def3db3758",
            fps: nil,
            frameCount: nil,
            accentHex: "#DC2626"
        ),
        CloudWallpaperPack(
            id: "hokusai_indigo_fuji_pine_coast",
            posterSeedId: 18950,
            category: "morph",
            kind: "morphPair",
            titleZh: "甲州蓝摺 · 富岳苍松",
            titleEn: "Aizuri-e · Indigo Mount Fuji",
            subtitleZh: "葛饰北斋普鲁士蓝木版浮世绘：和纸孤松远眺冷蓝富岳 → 破晓赤富士红赭金霞浸染雪岭",
            subtitleEn: "Hokusai woodblock print on mulberry washi: Prussian-blue Aizuri-e Fuji awakening into Red Fuji",
            badgeZh: "木版浮世",
            badgeEn: "Ukiyo-e Print",
            tagsZh: ["北斋蓝摺", "赤富士", "和纸木纹"],
            tagsEn: ["Hokusai", "Aizuri-e", "Red Fuji"],
            transitionPreset: "curtainRise",
            particlePreset: "none",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/hokusai_indigo_fuji_pine_coast.tendies",
            thumbPath: "wallpapers/thumbs/hokusai_indigo_fuji_pine_coast.jpg",
            previewPath: "wallpapers/previews/hokusai_indigo_fuji_pine_coast.webp",
            sizeBytes: 2269124,
            sha256: "72f75e75fe4c2ca6cc92a29a5c64a9a3f56a11955d922756332f002123520aad",
            fps: nil,
            frameCount: nil,
            accentHex: "#1D4ED8"
        ),
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

    static let seedFallbackPacks: [CloudWallpaperPack] = seedPacksA + seedPacksB + seedPacksC + seedPacksD

    private static let seedPacksC: [CloudWallpaperPack] = [
        CloudWallpaperPack(
            id: "duo_qianli_handscroll_dawn",
            posterSeedId: 18951,
            category: "duo",
            kind: "duoMorph",
            titleZh: "千里青绿 · 双屏长卷",
            titleEn: "Qianli Scroll · Dual Unfold",
            subtitleZh: "北宋绢本水墨云岫封面 → 展开化作王希孟式青绿金碧万里江山",
            subtitleEn: "Northern Song monochrome ink cover unfolds into azurite & malachite panoramic peaks",
            badgeZh: "iPhone Duo 宋画",
            badgeEn: "Duo · Song Silk",
            tagsZh: ["iPhone Duo", "青绿山水", "内外双屏"],
            tagsEn: ["iPhone Duo", "Song Scroll", "Dual-Screen"],
            transitionPreset: "curtainRise",
            particlePreset: "sunbeamRays",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/duo_qianli_handscroll_dawn.tendies",
            thumbPath: "wallpapers/thumbs/duo_qianli_handscroll_dawn.jpg",
            previewPath: "wallpapers/previews/duo_qianli_handscroll_dawn.webp",
            sizeBytes: 3189598,
            sha256: "02cd22a39594f1ff8e3f49b5d71cb7961c9d74ca8d938e32b5664aff7154f1ad",
            fps: nil,
            frameCount: nil,
            accentHex: "#0EA5E9"
        ),
        CloudWallpaperPack(
            id: "duo_dolomites_alpenglow_panorama",
            posterSeedId: 18952,
            category: "duo",
            kind: "duoMorph",
            titleZh: "多洛米蒂 · 日照金山双屏",
            titleEn: "Dolomites · Alpenglow Panorama",
            subtitleZh: "寒夜蓝调高山冰碛倒影 → 展开百里玫瑰金日照金山与镜面平湖",
            subtitleEn: "Blue-hour Dolomites tarn unfolds into a sweeping rose-gold alpine ridge panorama",
            badgeZh: "iPhone Duo 极境",
            badgeEn: "Duo · Alpine",
            tagsZh: ["iPhone Duo", "日照金山", "内外双屏"],
            tagsEn: ["iPhone Duo", "Dolomites", "Dual-Screen"],
            transitionPreset: "aodGaze",
            particlePreset: "sunbeamRays",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/duo_dolomites_alpenglow_panorama.tendies",
            thumbPath: "wallpapers/thumbs/duo_dolomites_alpenglow_panorama.jpg",
            previewPath: "wallpapers/previews/duo_dolomites_alpenglow_panorama.webp",
            sizeBytes: 2216081,
            sha256: "d15e5bb7d94f1f1aa4bd3157f1a072274870dd9ba9503079f7e162720042a470",
            fps: nil,
            frameCount: nil,
            accentHex: "#F59E0B"
        ),
        CloudWallpaperPack(
            id: "duo_monet_waterlily_triptych",
            posterSeedId: 18953,
            category: "duo",
            kind: "duoMorph",
            titleZh: "睡莲长卷 · 橘园晨光",
            titleEn: "Orangerie Lilies · Dual Mural",
            subtitleZh: "致敬莫奈《睡莲》巨幅联画：暮紫幽池展开铺陈珍珠粉金晨曦涟漪",
            subtitleEn: "Homage to Monet's Orangerie waterlily triptych from violet dusk to pearlescent dawn",
            badgeZh: "iPhone Duo 油画",
            badgeEn: "Duo · Impressionism",
            tagsZh: ["iPhone Duo", "印象派", "内外双屏"],
            tagsEn: ["iPhone Duo", "Monet", "Dual-Screen"],
            transitionPreset: "crossfade",
            particlePreset: "fireflies",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/duo_monet_waterlily_triptych.tendies",
            thumbPath: "wallpapers/thumbs/duo_monet_waterlily_triptych.jpg",
            previewPath: "wallpapers/previews/duo_monet_waterlily_triptych.webp",
            sizeBytes: 3637851,
            sha256: "4f9af98e5ac9bac51df9ba42b43b47bc132d6c573d462cdffdc305cb7aa5af6c",
            fps: nil,
            frameCount: nil,
            accentHex: "#A855F7"
        ),
        CloudWallpaperPack(
            id: "duo_rembrandt_chamber_concert",
            posterSeedId: 18954,
            category: "duo",
            kind: "duoMorph",
            titleZh: "巴洛克琴室 · 明暗奏鸣",
            titleEn: "Baroque Chamber · Chiaroscuro",
            subtitleZh: "致敬伦勃朗与维米尔：外屏大提琴静默低吟 → 展开漫入琥珀日光琴厅",
            subtitleEn: "Dutch Golden Age homage: shadowed cello study unfolds into a sunlit Vermeer hall",
            badgeZh: "iPhone Duo 巴洛克",
            badgeEn: "Duo · Baroque",
            tagsZh: ["iPhone Duo", "伦勃朗", "内外双屏"],
            tagsEn: ["iPhone Duo", "Rembrandt", "Dual-Screen"],
            transitionPreset: "flashAwaken",
            particlePreset: "sunbeamRays",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/duo_rembrandt_chamber_concert.tendies",
            thumbPath: "wallpapers/thumbs/duo_rembrandt_chamber_concert.jpg",
            previewPath: "wallpapers/previews/duo_rembrandt_chamber_concert.webp",
            sizeBytes: 3516355,
            sha256: "1d650fd95f67d8268dbd90d203c2a462237ed6c0c2c530a5ea0c363b581acf22",
            fps: nil,
            frameCount: nil,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "duo_fuji_pine_screen_byobu",
            posterSeedId: 18955,
            category: "duo",
            kind: "duoMorph",
            titleZh: "金箔松风 · 江户屏风",
            titleEn: "Kinpaku Byōbu · Pine & Red Fuji",
            subtitleZh: "江户六曲金箔屏风画境：银箔墨松封面 → 展开璀璨金云与赤富士湾",
            subtitleEn: "Edo silver-and-gold leaf folding screen unfolding from ink mist pines to glowing Akafuji",
            badgeZh: "iPhone Duo 屏风",
            badgeEn: "Duo · Byōbu",
            tagsZh: ["iPhone Duo", "金箔屏风", "内外双屏"],
            tagsEn: ["iPhone Duo", "Akafuji", "Dual-Screen"],
            transitionPreset: "curtainRise",
            particlePreset: "sakura",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/duo_fuji_pine_screen_byobu.tendies",
            thumbPath: "wallpapers/thumbs/duo_fuji_pine_screen_byobu.jpg",
            previewPath: "wallpapers/previews/duo_fuji_pine_screen_byobu.webp",
            sizeBytes: 3300211,
            sha256: "7dbf38700b3277edee2853f5a7c09e41eca652b97f722ff43dbde1a889366e56",
            fps: nil,
            frameCount: nil,
            accentHex: "#EF4444"
        ),
        CloudWallpaperPack(
            id: "duo_carina_cosmic_cliffs_wide",
            posterSeedId: 18956,
            category: "duo",
            kind: "duoMorph",
            titleZh: "船底座星崖 · 深空巨幕",
            titleEn: "Carina Cliffs · Cosmic Wide",
            subtitleZh: "深空望远镜红外视界：静谧靛黑尘柱 → 展开点亮熔金与宝石蓝星云悬崖",
            subtitleEn: "Deep-space infrared observatory cliff silhouette awakening in molten gold and sapphire gas",
            badgeZh: "iPhone Duo 宇宙",
            badgeEn: "Duo · Cosmos",
            tagsZh: ["iPhone Duo", "深空星云", "内外双屏"],
            tagsEn: ["iPhone Duo", "Nebula", "Dual-Screen"],
            transitionPreset: "burstZoom",
            particlePreset: "starlight",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/duo_carina_cosmic_cliffs_wide.tendies",
            thumbPath: "wallpapers/thumbs/duo_carina_cosmic_cliffs_wide.jpg",
            previewPath: "wallpapers/previews/duo_carina_cosmic_cliffs_wide.webp",
            sizeBytes: 2252506,
            sha256: "4fb7c42849d4f5a3220ace9c48c8fc8132b58d43d2791eb86ec5b10bda271d42",
            fps: nil,
            frameCount: nil,
            accentHex: "#3B82F6"
        ),
        CloudWallpaperPack(
            id: "duo_sorolla_mediterranean_terrace",
            posterSeedId: 18957,
            category: "duo",
            kind: "duoMorph",
            titleZh: "地中海柱廊 · 索罗亚日光",
            titleEn: "Mediterranean Terrace · Luminism",
            subtitleZh: "外光印象派海滨花园：暮色大理石柱露台 → 展开艳阳盛夏列柱湾",
            subtitleEn: "Homage to Sorolla's sunlit Mediterranean garden pergola across cover & unfolded screens",
            badgeZh: "iPhone Duo 外光",
            badgeEn: "Duo · Luminism",
            tagsZh: ["iPhone Duo", "索罗亚", "内外双屏"],
            tagsEn: ["iPhone Duo", "Sorolla", "Dual-Screen"],
            transitionPreset: "crossfade",
            particlePreset: "sunbeamRays",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/duo_sorolla_mediterranean_terrace.tendies",
            thumbPath: "wallpapers/thumbs/duo_sorolla_mediterranean_terrace.jpg",
            previewPath: "wallpapers/previews/duo_sorolla_mediterranean_terrace.webp",
            sizeBytes: 3653609,
            sha256: "9a6aff91a126213a348f3e477c8a3c4751b58b9d92b8ea0d059efc522ba37de9",
            fps: nil,
            frameCount: nil,
            accentHex: "#06B6D4"
        ),
        CloudWallpaperPack(
            id: "duo_namib_starry_dune_sea",
            posterSeedId: 18958,
            category: "duo",
            kind: "duoMorph",
            titleZh: "纳米布星沙 · 破晓沙海",
            titleEn: "Namib Dune Sea · Starlit Dawn",
            subtitleZh: "星夜蓝调刀锋沙脊 → 展开枯树谷与万里朱红晨光沙海冷暖明暗切割",
            subtitleEn: "Star-crowned S-curve Namib dune unfolding into Deadvlei's glowing vermilion dawn sea",
            badgeZh: "iPhone Duo 荒漠",
            badgeEn: "Duo · Desert",
            tagsZh: ["iPhone Duo", "纳米布沙丘", "内外双屏"],
            tagsEn: ["iPhone Duo", "Namib", "Dual-Screen"],
            transitionPreset: "aodGaze",
            particlePreset: "starlight",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/duo_namib_starry_dune_sea.tendies",
            thumbPath: "wallpapers/thumbs/duo_namib_starry_dune_sea.jpg",
            previewPath: "wallpapers/previews/duo_namib_starry_dune_sea.webp",
            sizeBytes: 2288944,
            sha256: "7bc16c8bcd669c6aadd97d84d0dcfd40e749405b48d6b67c60eb10b0f795eef6",
            fps: nil,
            frameCount: nil,
            accentHex: "#F97316"
        ),
        CloudWallpaperPack(
            id: "duo_guoxi_misty_valleys_scroll",
            posterSeedId: 18959,
            category: "duo",
            kind: "duoMotion",
            titleZh: "郭熙烟岚 · 呼吸宋画",
            titleEn: "Guo Xi Valleys · Living Scroll",
            subtitleZh: "北宋水墨实况动态双屏：寒林早春流岚呼吸游移，内外屏无缝流转",
            subtitleEn: "Living Northern Song ink scroll cinemagraph with breathing mists across both displays",
            badgeZh: "iPhone Duo 实况",
            badgeEn: "Duo · Live Ink",
            tagsZh: ["iPhone Duo", "动态宋画", "实况双屏"],
            tagsEn: ["iPhone Duo", "Guo Xi", "Dual Motion"],
            transitionPreset: "aodGaze",
            particlePreset: "fireflies",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/duo_guoxi_misty_valleys_scroll.tendies",
            thumbPath: "wallpapers/thumbs/duo_guoxi_misty_valleys_scroll.jpg",
            previewPath: "wallpapers/previews/duo_guoxi_misty_valleys_scroll.webp",
            sizeBytes: 5267385,
            sha256: "61dbc3f6f5b580ac9bbc9088ee05c15dbbb94dcbbb0aab3d3db17c6b5003a990",
            fps: 12,
            frameCount: 16,
            accentHex: "#10B981"
        ),
        CloudWallpaperPack(
            id: "duo_lofoten_aurora_fjord_panorama",
            posterSeedId: 18960,
            category: "duo",
            kind: "duoMotion",
            titleZh: "罗弗敦极光 · 峡湾实况长镜",
            titleEn: "Lofoten Aurora · Dual Fjord Live",
            subtitleZh: "北极圈极光实况动态双屏：木屋倒影渐醒，碧紫极光丝带于内屏天际舞动",
            subtitleEn: "Arctic fjord cinemagraph: cabin reflections shimmer as emerald aurora ribbons dance",
            badgeZh: "iPhone Duo 极光",
            badgeEn: "Duo · Live Aurora",
            tagsZh: ["iPhone Duo", "北欧极光", "实况双屏"],
            tagsEn: ["iPhone Duo", "Lofoten", "Dual Motion"],
            transitionPreset: "aodGaze",
            particlePreset: "starlight",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/duo_lofoten_aurora_fjord_panorama.tendies",
            thumbPath: "wallpapers/thumbs/duo_lofoten_aurora_fjord_panorama.jpg",
            previewPath: "wallpapers/previews/duo_lofoten_aurora_fjord_panorama.webp",
            sizeBytes: 4153011,
            sha256: "88a4330794f15f2e82cc4b5544428c9e2b0fa7bc53e3ae8eb9afa3fd5ad57794",
            fps: 12,
            frameCount: 16,
            accentHex: "#22C55E"
        )
    ]

    private static let seedPacksD: [CloudWallpaperPack] = [
        CloudWallpaperPack(
            id: "anime_ink_sketch_bloom",
            posterSeedId: 18961,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "墨线初醒 · 樱绘少女",
            titleEn: "Ink Sketch Bloom · Sakura",
            subtitleZh: "黑底银白钢笔线稿 → 上滑水彩厚涂觉醒，绿眸暮空与落樱破屏而出（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Obsidian silver dip-pen sketch blooming into cel-and-gouache color, emerald eyes & drifting sakura (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "线稿觉醒"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Ink to Color"],
            transitionPreset: "crossfade",
            particlePreset: "sakura",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_ink_sketch_bloom.tendies",
            thumbPath: "wallpapers/thumbs/anime_ink_sketch_bloom.jpg",
            previewPath: "wallpapers/previews/anime_ink_sketch_bloom.webp",
            sizeBytes: 3616699,
            sha256: "cf8274c861d9b304231c63be5c05c1bb6d4db5f967598eb82934646b93e1f33f",
            fps: nil,
            frameCount: nil,
            accentHex: "#EC4899"
        ),
        CloudWallpaperPack(
            id: "anime_cyber_visor_protocol",
            posterSeedId: 18962,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "赛博视界 · 瞳孔开机",
            titleEn: "Cyber Visor · Wake Protocol",
            subtitleZh: "雨夜暗调闭目休眠面罩 → 上滑青紫全息环与荧光星眸瞬间开机（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "OLED rain-night standby visor awakening into cyan-magenta holographic rings & glowing optics (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "赛博机能"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Cyberpunk"],
            transitionPreset: "aodGaze",
            particlePreset: "starlight",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_cyber_visor_protocol.tendies",
            thumbPath: "wallpapers/thumbs/anime_cyber_visor_protocol.jpg",
            previewPath: "wallpapers/previews/anime_cyber_visor_protocol.webp",
            sizeBytes: 4074056,
            sha256: "d1a6e86bc7fa2fdb37a6b752ece9a070266f05817a2bbf9ba2f6cb5dbb05cbc3",
            fps: nil,
            frameCount: nil,
            accentHex: "#06B6D4"
        ),
        CloudWallpaperPack(
            id: "anime_rainy_crossing_sunbreak",
            posterSeedId: 18963,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "雨岸平交道 · 破云霞光",
            titleEn: "Rainy Crossing · Sunbreak",
            subtitleZh: "海岸电车细雨透明伞 → 上滑积雨云裂开万丈琥珀丁达尔日光（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Rain-speckled clear umbrella by a coastal railway clearing into amber cumulonimbus sunbeams (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "新海光影"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Sunbreak"],
            transitionPreset: "curtainRise",
            particlePreset: "sunbeamRays",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_rainy_crossing_sunbreak.tendies",
            thumbPath: "wallpapers/thumbs/anime_rainy_crossing_sunbreak.jpg",
            previewPath: "wallpapers/previews/anime_rainy_crossing_sunbreak.webp",
            sizeBytes: 2651447,
            sha256: "70a46a61200491c3340b0e418ca0dd7963eada3a7541a9d513333c74f68a5d65",
            fps: nil,
            frameCount: nil,
            accentHex: "#F59E0B"
        ),
        CloudWallpaperPack(
            id: "anime_kitsune_torii_lanterns",
            posterSeedId: 18964,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "狐面鸟居 · 千灯夜祭",
            titleEn: "Kitsune Torii · Lantern Festival",
            subtitleZh: "幽蓝夜雾未燃纸灯巫女 → 上滑千灯通明金枫描金振袖灵火四起（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Misty midnight shrine maiden awakening a vermilion-gold lantern festival with maple filigree & sparks (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "和风怪谈"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Shrine"],
            transitionPreset: "aodGaze",
            particlePreset: "embers",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_kitsune_torii_lanterns.tendies",
            thumbPath: "wallpapers/thumbs/anime_kitsune_torii_lanterns.jpg",
            previewPath: "wallpapers/previews/anime_kitsune_torii_lanterns.webp",
            sizeBytes: 2527833,
            sha256: "1a54ed3306a1ff5ba87edbca00c674977ea66ff53928653c827d135ba73e9b34",
            fps: nil,
            frameCount: nil,
            accentHex: "#EF4444"
        ),
        CloudWallpaperPack(
            id: "anime_crimson_velvet_cutin",
            posterSeedId: 18965,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "猩红爵士 · 破屏切入",
            titleEn: "Crimson Velvet · Cut-In",
            subtitleZh: "纯黑高对比黑白礼帽乐手 → 上滑猩红金箔波普切入与琥珀双眸觉醒（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "High-contrast monochrome phantom musician erupting into crimson, ivory & gold-leaf shards (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "潮酷撞色"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Acid Jazz"],
            transitionPreset: "burstZoom",
            particlePreset: "starlight",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_crimson_velvet_cutin.tendies",
            thumbPath: "wallpapers/thumbs/anime_crimson_velvet_cutin.jpg",
            previewPath: "wallpapers/previews/anime_crimson_velvet_cutin.webp",
            sizeBytes: 3583140,
            sha256: "c3c265c512d886c49175c540c84221c3313d236f4acd8e5a358e2ae483bc6699",
            fps: nil,
            frameCount: nil,
            accentHex: "#DC2626"
        ),
        CloudWallpaperPack(
            id: "anime_rooftop_meteor_observatory",
            posterSeedId: 18966,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "天台星镜 · 流星夜话",
            titleEn: "Rooftop Observatory · Meteors",
            subtitleZh: "静谧暮色黄铜望远镜少女 → 上滑银河星瀑与青紫双色流星雨降临（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Twilight rooftop refractor telescope awakening beneath a luminous Milky Way & turquoise meteor shower (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "星空流星"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Meteors"],
            transitionPreset: "crossfade",
            particlePreset: "meteorShower",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_rooftop_meteor_observatory.tendies",
            thumbPath: "wallpapers/thumbs/anime_rooftop_meteor_observatory.jpg",
            previewPath: "wallpapers/previews/anime_rooftop_meteor_observatory.webp",
            sizeBytes: 2419178,
            sha256: "13420d63c5c68ccab8656e02313061deee190ce9d686519adeb55245165e7407",
            fps: nil,
            frameCount: nil,
            accentHex: "#6366F1"
        ),
        CloudWallpaperPack(
            id: "anime_lofi_window_cat_study",
            posterSeedId: 18967,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "深夜窗猫 · 暖灯可可",
            titleEn: "Midnight Desk · Cat & Cocoa",
            subtitleZh: "熄灯雨夜阁楼耳机少女与黑猫 → 上滑绿罩银行台灯点亮琥珀暖夜（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Cool moonlit rainy-night Lo-Fi desk switching on a honey-amber green banker lamp beside a black cat (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "Lo-Fi 治愈"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Lo-Fi Cozy"],
            transitionPreset: "crossfade",
            particlePreset: "snowfall",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_lofi_window_cat_study.tendies",
            thumbPath: "wallpapers/thumbs/anime_lofi_window_cat_study.jpg",
            previewPath: "wallpapers/previews/anime_lofi_window_cat_study.webp",
            sizeBytes: 2307648,
            sha256: "50533cf91fa7601758d3e54a054624ec53acef4d9adab5df32062cb4396f61f0",
            fps: nil,
            frameCount: nil,
            accentHex: "#D97706"
        ),
        CloudWallpaperPack(
            id: "anime_celestial_witch_astrolabe",
            posterSeedId: 18968,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "星穹魔女 · 古铜星盘",
            titleEn: "Astral Witch · Celestial Astrolabe",
            subtitleZh: "苍白月色沉睡古铜浑天仪 → 上滑熔金星环、水晶蓝蝶与紫瞳齐醒（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Silver-braided witch awakening her antique bronze astrolabe with molten-gold rings & crystal butterflies (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "西幻魔法"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Fantasy"],
            transitionPreset: "burstZoom",
            particlePreset: "starlight",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_celestial_witch_astrolabe.tendies",
            thumbPath: "wallpapers/thumbs/anime_celestial_witch_astrolabe.jpg",
            previewPath: "wallpapers/previews/anime_celestial_witch_astrolabe.webp",
            sizeBytes: 4204542,
            sha256: "ad570ad2fb3f7d70053371af1368888d94c29b54dfa6491be5c6a1e86c6ad464",
            fps: nil,
            frameCount: nil,
            accentHex: "#8B5CF6"
        ),
        CloudWallpaperPack(
            id: "anime_mecha_hangar_launch",
            posterSeedId: 18969,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "格纳库整备 · 光翼出击",
            titleEn: "Orbital Hangar · Wing Ignition",
            subtitleZh: "冷冽暗调钛白机甲待机态 → 上滑碧眼启动、天蓝等离子光翼与探照金光出击（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Cold titanium mecha in dark hangar standby igniting emerald optics, plasma wings & launch floodlights (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "机甲科幻"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Mecha"],
            transitionPreset: "burstZoom",
            particlePreset: "embers",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_mecha_hangar_launch.tendies",
            thumbPath: "wallpapers/thumbs/anime_mecha_hangar_launch.jpg",
            previewPath: "wallpapers/previews/anime_mecha_hangar_launch.webp",
            sizeBytes: 3744473,
            sha256: "695f578cd0d8a9d3f42741f10acd192575bcb27134c91c760e5e36dd9432cc89",
            fps: nil,
            frameCount: nil,
            accentHex: "#0EA5E9"
        ),
        CloudWallpaperPack(
            id: "anime_jade_pavilion_sword_lotus",
            posterSeedId: 18970,
            category: "anime",
            kind: "anime3DMorph",
            titleZh: "松崖剑意 · 破晓青莲",
            titleEn: "Cliff Pine Swordswoman · Lotus Dawn",
            subtitleZh: "墨夜松巅持鞘待发女剑修 → 上滑破晓金云、灵力青莲与玉剑流光绽放（真机 3D 陀螺仪 + 景深挡时间）",
            subtitleEn: "Moonlit cliff-pine swordswoman awakening golden sunrise clouds, luminous lotus & jade sword aura (3D Gyro + Clock Depth)",
            badgeZh: "次元 3D",
            badgeEn: "Anime 3D",
            tagsZh: ["原创二次元", "3D 陀螺仪", "景深挡时间", "国风仙侠"],
            tagsEn: ["Original Anime", "3D Gyro", "Clock Depth", "Xianxia"],
            transitionPreset: "curtainRise",
            particlePreset: "fireflies",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/anime_jade_pavilion_sword_lotus.tendies",
            thumbPath: "wallpapers/thumbs/anime_jade_pavilion_sword_lotus.jpg",
            previewPath: "wallpapers/previews/anime_jade_pavilion_sword_lotus.webp",
            sizeBytes: 3069073,
            sha256: "f3c5b1cb45285e7f37b595a0deaa1fffa6c33bfc469617247e30fec837ad0298",
            fps: nil,
            frameCount: nil,
            accentHex: "#10B981"
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
