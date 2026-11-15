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

    static let seedFallbackPacks: [CloudWallpaperPack] = [
        CloudWallpaperPack(
            id: "titanium_silk_flow",
            posterSeedId: 18901,
            category: "motion",
            kind: "motionLoop",
            titleZh: "钛金丝绸流体",
            titleEn: "Titanium Silk Flow",
            subtitleZh: "纯数学生成 3D 钛金波形 · 零失真丝滑无限循环",
            subtitleEn: "Procedural 3D Titanium Satin Wave Loop",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["极简金属", "丝绸波形", "无缝循环"],
            tagsEn: ["Titanium", "Silk Wave", "Seamless"],
            transitionPreset: "crossfade",
            particlePreset: "starlight",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/titanium_silk_flow.tendies",
            thumbPath: "wallpapers/thumbs/titanium_silk_flow.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: 15,
            frameCount: 20,
            accentHex: "#9BA5B8"
        ),
        CloudWallpaperPack(
            id: "polar_aurora_curtain",
            posterSeedId: 18902,
            category: "motion",
            kind: "motionLoop",
            titleZh: "极光星瀑",
            titleEn: "Polar Aurora Curtain",
            subtitleZh: "北境冰川夜幕翡翠极光流动 · 湖面倒影微漾与星辉闪烁",
            subtitleEn: "Arctic Emerald Aurora Ribbons with Fjord Shimmer",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["极光风光", "星点闪烁", "湖面微漾"],
            tagsEn: ["Aurora", "Starlight", "Nature"],
            transitionPreset: "crossfade",
            particlePreset: "auroraRibbon",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/polar_aurora_curtain.tendies",
            thumbPath: "wallpapers/thumbs/polar_aurora_curtain.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: 14,
            frameCount: 20,
            accentHex: "#34D399"
        ),
        CloudWallpaperPack(
            id: "sunset_ocean_shimmer",
            posterSeedId: 18903,
            category: "motion",
            kind: "motionLoop",
            titleZh: "落日海面金波",
            titleEn: "Golden Ocean Sunset",
            subtitleZh: "暮色熔金海平线 · 碎金海浪缓缓流动",
            subtitleEn: "Amber Twilight Sea Horizon & Shimmering Waves",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["落日治愈", "金色波光", "氛围风景"],
            tagsEn: ["Sunset", "Ocean", "Ambient"],
            transitionPreset: "crossfade",
            particlePreset: "sunbeamRays",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/sunset_ocean_shimmer.tendies",
            thumbPath: "wallpapers/thumbs/sunset_ocean_shimmer.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: 14,
            frameCount: 20,
            accentHex: "#F59E0B"
        ),
        CloudWallpaperPack(
            id: "cyber_neon_rain",
            posterSeedId: 18904,
            category: "motion",
            kind: "motionLoop",
            titleZh: "赛博霓虹雨夜",
            titleEn: "Cyber Neon Rain",
            subtitleZh: "深蓝细雨斜落 · 霓虹湿滑街面光晕呼吸律动",
            subtitleEn: "Cyberpunk Drizzle & Pulsing Neon Street Reflections",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["赛博朋克", "雨夜光影", "霓虹脉冲"],
            tagsEn: ["Cyberpunk", "Rainy Night", "Neon"],
            transitionPreset: "crossfade",
            particlePreset: "meteorShower",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/cyber_neon_rain.tendies",
            thumbPath: "wallpapers/thumbs/cyber_neon_rain.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: 15,
            frameCount: 20,
            accentHex: "#38BDF8"
        ),
        CloudWallpaperPack(
            id: "abyssal_jellyfish_glow",
            posterSeedId: 18905,
            category: "motion",
            kind: "motionLoop",
            titleZh: "深海荧光水母",
            titleEn: "Abyssal Glow Jellyfish",
            subtitleZh: "幽暗深海生物荧光温柔脉动 · 浮游星点缓慢升腾",
            subtitleEn: "Bioluminescent Jellyfish Pulse & Drifting Abyss Glow",
            badgeZh: "动态循环",
            badgeEn: "Motion Loop",
            tagsZh: ["深海幽境", "OLED极黑", "荧光脉动"],
            tagsEn: ["Abyss", "OLED Black", "Bioluminescent"],
            transitionPreset: "crossfade",
            particlePreset: "fireflies",
            supportsClockDepth: false,
            packagePath: "wallpapers/packages/abyssal_jellyfish_glow.tendies",
            thumbPath: "wallpapers/thumbs/abyssal_jellyfish_glow.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: 14,
            frameCount: 20,
            accentHex: "#818CF8"
        ),
        CloudWallpaperPack(
            id: "neon_ronin_slash",
            posterSeedId: 18906,
            category: "morph",
            kind: "morphPair",
            titleZh: "霓虹浪人·拔刀",
            titleEn: "Neon Ronin Slash",
            subtitleZh: "解锁瞬间拔出猩红等离子长刀 · 主体时钟景深叠加余烬特效",
            subtitleEn: "Slide to Draw Crimson Plasma Katana with Clock Depth",
            badgeZh: "景深变身",
            badgeEn: "Depth Morph",
            tagsZh: ["二次元/科幻", "时钟景深", "滑动拔刀"],
            tagsEn: ["Ronin", "Clock Depth", "Flash Morph"],
            transitionPreset: "flashAwaken",
            particlePreset: "embers",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/neon_ronin_slash.tendies",
            thumbPath: "wallpapers/thumbs/neon_ronin_slash.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: nil,
            frameCount: nil,
            accentHex: "#F43F5E"
        ),
        CloudWallpaperPack(
            id: "lunar_earthrise_portal",
            posterSeedId: 18907,
            category: "morph",
            kind: "morphPair",
            titleZh: "月面地出星门",
            titleEn: "Lunar Earthrise Portal",
            subtitleZh: "静谧寒月滑向瑰丽星云地出奇观 · 宇航员前景景深穿透时钟",
            subtitleEn: "Silent Lunar Horizon Ignites Cosmic Earthrise & Halo",
            badgeZh: "景深变身",
            badgeEn: "Depth Morph",
            tagsZh: ["太空史诗", "推进变身", "时钟景深"],
            tagsEn: ["Space", "Burst Zoom", "Clock Depth"],
            transitionPreset: "burstZoom",
            particlePreset: "starlight",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/lunar_earthrise_portal.tendies",
            thumbPath: "wallpapers/thumbs/lunar_earthrise_portal.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: nil,
            frameCount: nil,
            accentHex: "#60A5FA"
        ),
        CloudWallpaperPack(
            id: "kyoto_sakura_dawn",
            posterSeedId: 18908,
            category: "morph",
            kind: "morphPair",
            titleZh: "京都樱吹雪",
            titleEn: "Kyoto Sakura Dawn",
            subtitleZh: "蓝调拂晓鸟居滑向粉金晨曦 · 配花瓣飘落与古建景深遮罩",
            subtitleEn: "Blue-Hour Torii Blooms into Golden Sunrise & Petals",
            badgeZh: "景深变身",
            badgeEn: "Depth Morph",
            tagsZh: ["唯美和风", "樱瓣粒子", "时钟景深"],
            tagsEn: ["Kyoto", "Sakura Petals", "Clock Depth"],
            transitionPreset: "curtainRise",
            particlePreset: "sakura",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/kyoto_sakura_dawn.tendies",
            thumbPath: "wallpapers/thumbs/kyoto_sakura_dawn.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: nil,
            frameCount: nil,
            accentHex: "#F472B6"
        ),
        CloudWallpaperPack(
            id: "frost_dragon_awaken",
            posterSeedId: 18909,
            category: "morph",
            kind: "morphPair",
            titleZh: "冰霜巨龙觉醒",
            titleEn: "Frost Dragon Awaken",
            subtitleZh: "闭目沉睡冰龙上滑睁开冰蓝电瞳 · 3D 视差景深叠加极光波纹",
            subtitleEn: "Sleeping Glacier Dragon Opens Ice-Blue Eyes on Unlock",
            badgeZh: "景深变身",
            badgeEn: "Depth Morph",
            tagsZh: ["暗黑幻想", "全息视差", "时钟景深"],
            tagsEn: ["Dragon", "Holo Parallax", "Clock Depth"],
            transitionPreset: "holoCard",
            particlePreset: "auroraRibbon",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/frost_dragon_awaken.tendies",
            thumbPath: "wallpapers/thumbs/frost_dragon_awaken.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: nil,
            frameCount: nil,
            accentHex: "#22D3EE"
        ),
        CloudWallpaperPack(
            id: "silver_gt_apex",
            posterSeedId: 18910,
            category: "morph",
            kind: "morphPair",
            titleZh: "银翼超跑脉冲",
            titleEn: "Silver GT Apex",
            subtitleZh: "暗调超跑轮廓上滑点亮矩阵灯组与流星光束 · OLED 质感首选",
            subtitleEn: "Dark Slate Hypercar Ignites Matrix LEDs & Light Streaks",
            badgeZh: "景深变身",
            badgeEn: "Depth Morph",
            tagsZh: ["未来座驾", "熄屏脉冲", "时钟景深"],
            tagsEn: ["Hypercar", "AOD Pulse", "Clock Depth"],
            transitionPreset: "aodGaze",
            particlePreset: "meteorShower",
            supportsClockDepth: true,
            packagePath: "wallpapers/packages/silver_gt_apex.tendies",
            thumbPath: "wallpapers/thumbs/silver_gt_apex.jpg",
            sizeBytes: 0,
            sha256: "",
            fps: nil,
            frameCount: nil,
            accentHex: "#94A3B8"
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

            let ordered = preferMirror
                ? [ghFast, ghProxy, ghProxyNet, jsdMirror, jsDelivr, rawURLString]
                : [rawURLString, jsDelivr, ghFast, ghProxy, ghProxyNet, jsdMirror]

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
        if !hasSyncedOnce || packs.allSatisfy({ $0.sizeBytes == 0 }) {
            await refreshCatalog(force: false)
        }
    }

    func refreshCatalog(force: Bool = true) async {
        if isRefreshingCatalog { return }
        if hasSyncedOnce && !force && !packs.allSatisfy({ $0.sizeBytes == 0 }) { return }

        isRefreshingCatalog = true
        syncErrorMessage = nil
        defer { isRefreshingCatalog = false }

        let urls = AppSourceManager.shared.candidateRawURLs(for: "wallpapers/catalog.json")
        var lastError: Error?

        for url in urls {
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
                request.setValue("Camlo/\(CamloDevice.appVersion)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
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
                lastError = error
            }
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

            let tempURL = try await downloadVerifiedArchive(
                from: urls,
                trackID: pack.id,
                expectedSize: Int64(pack.sizeBytes),
                expectedSHA256: pack.sha256.isEmpty ? nil : pack.sha256,
                isOfficialChannel: true
            )
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
            let msg: String
            if isOfficialChannel {
                msg = Bi(
                    "官方精选壁纸包尚未上传至远端仓库（HTTP 404），请切换至上方 CAPlayground / Nugget 社区库下载，或在开幕工坊本地制作",
                    "Official cloud packs are not yet published on the remote repo (HTTP 404). Switch to CAPlayground / Nugget channels above or create locally in Studio."
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
