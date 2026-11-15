//
//  InstalledPosterManager.swift
//  Camlo · 开幕
//
//  Clean-room PosterBoard DataStore inspector, thumbnail cache, and batch deletion manager.
//

import Foundation
import Combine
import UIKit
import ImageIO
import CryptoKit

// MARK: - Poster Slot & Provider Metadata Catalog

enum CamloPosterSlot: String, CaseIterable, Identifiable, Sendable {
    case lockSwitcher
    case galleryTemplate

    var id: String { rawValue }

    var directoryName: String {
        switch self {
        case .lockSwitcher: return "configurations"
        case .galleryTemplate: return "descriptors"
        }
    }

    var shortLabel: String {
        switch self {
        case .lockSwitcher: return Bi("锁屏切换栏", "Active Switcher")
        case .galleryTemplate: return Bi("图库模板", "Gallery Template")
        }
    }
}

enum PBProviderCatalog {
    private struct Entry {
        let token: String
        let zhTitle: String
        let enTitle: String
        let sfSymbol: String
    }

    private static let entries: [Entry] = [
        Entry(token: "CollectionsPoster", zhTitle: "机型收藏 / 精选", enTitle: "Collections", sfSymbol: "rectangle.stack.fill"),
        Entry(token: "PhotosPosterProvider", zhTitle: "照片 / 实况", enTitle: "Photos", sfSymbol: "photo.stack.fill"),
        Entry(token: "MercuryPoster", zhTitle: "天文与水星流体", enTitle: "Astronomy", sfSymbol: "moon.stars.fill"),
        Entry(token: "KaleidoscopePoster", zhTitle: "万花筒", enTitle: "Kaleidoscope", sfSymbol: "sparkles.rectangle.stack"),
        Entry(token: "WeatherPoster", zhTitle: "天气", enTitle: "Weather", sfSymbol: "cloud.sun.fill"),
        Entry(token: "EmojiPoster", zhTitle: "表情符号", enTitle: "Emoji", sfSymbol: "face.smiling.fill"),
        Entry(token: "GradientPoster", zhTitle: "渐变配色", enTitle: "Gradient", sfSymbol: "paintpalette.fill"),
        Entry(token: "ColorPoster", zhTitle: "纯色", enTitle: "Color", sfSymbol: "circle.hexagongrid.fill"),
        Entry(token: "PridePoster", zhTitle: "彩虹", enTitle: "Pride", sfSymbol: "rainbow"),
        Entry(token: "Unity", zhTitle: "团结", enTitle: "Unity", sfSymbol: "figure.2.arms.open"),
        Entry(token: "WallpaperPoster", zhTitle: "壁纸集", enTitle: "Wallpapers", sfSymbol: "photo.on.rectangle.angled")
    ]

    nonisolated static func sectionTitle(for provider: String) -> String {
        for item in entries where provider.localizedCaseInsensitiveContains(item.token) {
            return Bi(item.zhTitle, item.enTitle)
        }
        let cleaned = provider
            .replacingOccurrences(of: "com.apple.Posters.", with: "")
            .replacingOccurrences(of: "com.apple.WallpaperKit.", with: "")
            .replacingOccurrences(of: "com.apple.", with: "")
        return cleaned.components(separatedBy: ".").last?.isEmpty == false
            ? (cleaned.components(separatedBy: ".").last ?? provider)
            : provider
    }

    nonisolated static func iconSymbol(for provider: String) -> String {
        for item in entries where provider.localizedCaseInsensitiveContains(item.token) {
            return item.sfSymbol
        }
        return "photo.artframe"
    }

    nonisolated static func defaultLabel(for provider: String, isCamlo: Bool) -> String {
        let base = sectionTitle(for: provider)
        return isCamlo ? "Camlo · \(base)" : base
    }
}

// MARK: - DataStore Index Model & Pruning

private struct PBRoleIndexFile: Decodable {
    var orderedPosterUUIDs: [String]?
    var posterUUIDs: [String]?
    var activePosterUUID: String?
    var selectedPosterUUID: String?
    var selectedConfigurationUUID: String?

    var allReferencedUUIDs: Set<String> {
        var set = Set<String>()
        orderedPosterUUIDs?.forEach { set.insert($0.uppercased()) }
        posterUUIDs?.forEach { set.insert($0.uppercased()) }
        if let activePosterUUID { set.insert(activePosterUUID.uppercased()) }
        if let selectedPosterUUID { set.insert(selectedPosterUUID.uppercased()) }
        if let selectedConfigurationUUID { set.insert(selectedConfigurationUUID.uppercased()) }
        return set
    }
}

private enum PBRoleIndexPruner {
    nonisolated static func pruneUUIDs(_ removedUUIDs: Set<String>, inDataStoreRoot storeRootPath: String) {
        guard !removedUUIDs.isEmpty else { return }
        let normalizedTargets = Set(removedUUIDs.map { $0.uppercased() })
        let fm = FileManager.default
        let wq = WorseQueryBridge.shared
        let storeURL = URL(fileURLWithPath: storeRootPath, isDirectory: true)

        let candidateDirs = [
            storeURL.appendingPathComponent("Collections", isDirectory: true),
            storeURL.appendingPathComponent("Roles", isDirectory: true)
        ]

        let decoder = PropertyListDecoder()
        for dirURL in candidateDirs {
            guard fm.fileExists(atPath: dirURL.path),
                  wq.grantAccess(path: dirURL.path).0,
                  let enumerator = fm.enumerator(
                      at: dirURL,
                      includingPropertiesForKeys: [.isRegularFileKey],
                      options: []
                  ) else { continue }

            for case let plistURL as URL in enumerator where plistURL.pathExtension.lowercased() == "plist" {
                guard let data = try? Data(contentsOf: plistURL),
                      let parsed = try? decoder.decode(PBRoleIndexFile.self, from: data),
                      !parsed.allReferencedUUIDs.isDisjoint(with: normalizedTargets) else {
                    continue
                }

                guard var rawDict = (try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                )) as? [String: Any] else { continue }

                var mutated = false
                for arrayKey in ["orderedPosterUUIDs", "posterUUIDs"] {
                    if let list = rawDict[arrayKey] as? [String] {
                        let filtered = list.filter { !normalizedTargets.contains($0.uppercased()) }
                        if filtered.count != list.count {
                            rawDict[arrayKey] = filtered
                            mutated = true
                        }
                    }
                }

                let remainingFallback = (rawDict["orderedPosterUUIDs"] as? [String])?.first
                    ?? (rawDict["posterUUIDs"] as? [String])?.first

                for singleKey in ["activePosterUUID", "selectedPosterUUID", "selectedConfigurationUUID"] {
                    if let current = rawDict[singleKey] as? String,
                       normalizedTargets.contains(current.uppercased()) {
                        if let replacement = remainingFallback {
                            rawDict[singleKey] = replacement
                        } else {
                            rawDict.removeValue(forKey: singleKey)
                        }
                        mutated = true
                    }
                }

                if mutated,
                   let serialized = try? PropertyListSerialization.data(fromPropertyList: rawDict, format: .binary, options: 0) {
                    _ = wq.grantAccess(path: plistURL.path)
                    try? serialized.write(to: plistURL, options: .atomic)
                }
            }
        }
    }
}

// MARK: - Clean-Room Thumbnail Renderer & Disk Cache

private enum CamloPosterThumbRenderer {
    nonisolated private static let maxPixelSize = 520

    nonisolated static func thumbnailData(for bundleURL: URL, modifiedAt: Date) -> Data? {
        CamloPaths.ensureDirectories()
        let keyMaterial = "v2:\(bundleURL.path):\(Int64(modifiedAt.timeIntervalSince1970))"
        let digest = SHA256.hash(data: Data(keyMaterial.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let cacheURL = CamloPaths.posterThumbsCacheDir.appendingPathComponent("\(digest).jpg")

        if let cached = try? Data(contentsOf: cacheURL), !cached.isEmpty {
            return cached
        }

        guard let sourceImageURL = selectRepresentativeImage(in: bundleURL),
              let jpegData = renderJPEGThumbnail(from: sourceImageURL) else {
            return nil
        }

        try? jpegData.write(to: cacheURL, options: .atomic)
        return jpegData
    }

    nonisolated private static func selectRepresentativeImage(in bundleURL: URL) -> URL? {
        let fm = FileManager.default
        let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp"]
        guard let enumerator = fm.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else { return nil }

        var scoredCandidates: [(score: Int, size: Int, url: URL)] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }
            guard let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  vals.isRegularFile == true else { continue }
            let byteSize = vals.fileSize ?? 0
            guard byteSize >= 4_096 else { continue }

            let lowerPath = fileURL.path.lowercased()
            var score = 10
            if lowerPath.contains("background") || lowerPath.contains("lock") { score += 40 }
            if lowerPath.contains("hero") || lowerPath.contains("poster") || lowerPath.contains("frame_0") { score += 25 }
            if lowerPath.contains("floating") || lowerPath.contains("emitter") || lowerPath.contains("particle") { score -= 30 }
            if lowerPath.contains("thumbnail") { score += 15 }
            scoredCandidates.append((score, byteSize, fileURL))
        }

        return scoredCandidates.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.size > $1.size
        }.first?.url
    }

    nonisolated private static func renderJPEGThumbnail(from imageURL: URL) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.78)
    }
}

// MARK: - Public Record & Observable Store

struct SystemPosterRecord: Identifiable, Equatable, Sendable {
    let id: String
    let uuid: String
    let title: String
    let providerID: String
    let sectionTitle: String
    let symbolName: String
    let numericTag: String?
    let bundlePath: String
    let dataStoreRoot: String
    let slot: CamloPosterSlot
    let isCamloOrigin: Bool
    let updatedAt: Date
    let previewJPEG: Data?
}

@MainActor
final class SystemPosterStore: ObservableObject {
    static let shared = SystemPosterStore()

    @Published private(set) var records: [SystemPosterRecord] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var isRemoving: Bool = false
    @Published var lastError: String? = nil

    private init() {}

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil

        let containerPath = PosterBoardBridge.shared.containerPath
        let recordedTitles = PosterBoardBridge.recordedTitlesByUUID()
        let trackedUUIDs = Set(
            (UserDefaults.standard.stringArray(forKey: "camlo_injected_descriptor_names_v2") ?? [])
                .map { $0.uppercased() }
        )

        let scanned = await Task.detached(priority: .userInitiated) { () -> (records: [SystemPosterRecord], error: String?) in
            guard !containerPath.isEmpty else {
                return ([], Bi("尚未定位到 PosterBoard 容器，请先在设置中授予目录权限。", "PosterBoard container is not configured yet."))
            }
            let wq = WorseQueryBridge.shared
            let rootGrant = wq.grantAccess(path: containerPath)
            guard rootGrant.0 else {
                return ([], rootGrant.2)
            }

            let fm = FileManager.default
            let storeVersion = PBExtensionTarget.resolveStoreVersion(in: containerPath)
            let storeRootURL = URL(fileURLWithPath: containerPath, isDirectory: true)
                .appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/\(storeVersion)", isDirectory: true)
            let extensionsRoot = storeRootURL.appendingPathComponent("Extensions", isDirectory: true)

            guard fm.fileExists(atPath: extensionsRoot.path) else {
                return ([], Bi("未发现系统锁屏扩展存储目录（\(storeVersion)）。", "No PosterBoard extension store found (\(storeVersion))."))
            }
            let extGrant = wq.grantAccess(path: extensionsRoot.path)
            guard extGrant.0 else {
                return ([], extGrant.2)
            }

            guard let providerDirs = try? fm.contentsOfDirectory(
                at: extensionsRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return ([], nil)
            }

            var output: [SystemPosterRecord] = []
            for providerURL in providerDirs {
                let isDir = (try? providerURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                let providerID = providerURL.lastPathComponent

                for slot in CamloPosterSlot.allCases {
                    let slotDir = providerURL.appendingPathComponent(slot.directoryName, isDirectory: true)
                    guard fm.fileExists(atPath: slotDir.path),
                          wq.grantAccess(path: slotDir.path).0,
                          let bundleDirs = try? fm.contentsOfDirectory(
                              at: slotDir,
                              includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                              options: [.skipsHiddenFiles]
                          ) else { continue }

                    for bundleURL in bundleDirs {
                        let vals = try? bundleURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                        guard vals?.isDirectory == true else { continue }

                        let uuid = bundleURL.lastPathComponent
                        guard !uuid.isEmpty, uuid != "__MACOSX" else { continue }

                        let markerExists = fm.fileExists(
                            atPath: bundleURL.appendingPathComponent(PosterBoardBridge.camloMarkerFilename).path
                        )
                        let isCamlo = markerExists || trackedUUIDs.contains(uuid.uppercased())
                        let modifiedAt = vals?.contentModificationDate ?? Date.distantPast
                        let numericTag = Self.readNumericTag(in: bundleURL)
                        let resolvedTitle = recordedTitles[uuid.uppercased()]
                            ?? recordedTitles[uuid]
                            ?? Self.readPosterTitle(in: bundleURL)
                            ?? PBProviderCatalog.defaultLabel(for: providerID, isCamlo: isCamlo)

                        let previewJPEG = CamloPosterThumbRenderer.thumbnailData(
                            for: bundleURL,
                            modifiedAt: modifiedAt
                        )

                        output.append(SystemPosterRecord(
                            id: "\(slot.rawValue)::\(providerID)::\(uuid)",
                            uuid: uuid,
                            title: resolvedTitle,
                            providerID: providerID,
                            sectionTitle: PBProviderCatalog.sectionTitle(for: providerID),
                            symbolName: PBProviderCatalog.iconSymbol(for: providerID),
                            numericTag: numericTag,
                            bundlePath: bundleURL.path,
                            dataStoreRoot: storeRootURL.path,
                            slot: slot,
                            isCamloOrigin: isCamlo,
                            updatedAt: modifiedAt,
                            previewJPEG: previewJPEG
                        ))
                    }
                }
            }

            output.sort { lhs, rhs in
                if lhs.isCamloOrigin != rhs.isCamloOrigin {
                    return lhs.isCamloOrigin
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            return (output, nil)
        }.value

        self.records = scanned.records
        self.lastError = scanned.error
        self.isScanning = false
    }

    func remove(_ targets: [SystemPosterRecord]) async throws -> Int {
        guard !targets.isEmpty else { return 0 }
        guard !isRemoving else { return 0 }

        isRemoving = true
        lastError = nil
        defer { isRemoving = false }

        let result = await Task.detached(priority: .userInitiated) { () -> Result<Int, Error> in
            let wq = WorseQueryBridge.shared
            let fm = FileManager.default
            var removedCount = 0
            var removedUUIDsByStore: [String: Set<String>] = [:]
            var allRemovedUUIDs = Set<String>()

            for target in targets {
                let targetURL = URL(fileURLWithPath: target.bundlePath, isDirectory: true)
                let parentPath = targetURL.deletingLastPathComponent().path
                _ = wq.grantAccess(path: parentPath)
                _ = wq.grantAccess(path: target.bundlePath)

                if fm.fileExists(atPath: target.bundlePath) {
                    do {
                        try fm.removeItem(at: targetURL)
                        removedCount += 1
                        allRemovedUUIDs.insert(target.uuid)
                        removedUUIDsByStore[target.dataStoreRoot, default: []].insert(target.uuid)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for (storeRoot, uuids) in removedUUIDsByStore {
                PBRoleIndexPruner.pruneUUIDs(uuids, inDataStoreRoot: storeRoot)
            }

            let deletedUUIDSnapshot = allRemovedUUIDs
            let finalRemovedCount = removedCount
            await MainActor.run {
                PosterBoardBridge.shared.untrackDeletedDescriptors(deletedUUIDSnapshot)
                if finalRemovedCount > 0 {
                    _ = PosterBoardBridge.shared.refreshGalleryCacheNonDestructive()
                }
            }
            return .success(removedCount)
        }.value

        switch result {
        case .success(let count):
            let removedIDs = Set(targets.map(\.id))
            records.removeAll { removedIDs.contains($0.id) }
            return count
        case .failure(let error):
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Private Metadata Readers

    nonisolated private static func readNumericTag(in bundleURL: URL) -> String? {
        let idFile = bundleURL.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier")
        if let raw = try? String(contentsOf: idFile, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.count <= 24 {
                return trimmed
            }
        }
        return nil
    }

    nonisolated private static func readPosterTitle(in bundleURL: URL) -> String? {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "Wallpaper.plist" {
                if let data = fm.contents(atPath: fileURL.path),
                   let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
                    for key in ["displayName", "localizedTitle", "title", "name", "family"] {
                        if let val = dict[key] as? String {
                            let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { return trimmed }
                        }
                    }
                }
            }
        }
        return nil
    }
}
