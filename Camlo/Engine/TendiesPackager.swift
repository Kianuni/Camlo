//
//  TendiesPackager.swift
//  Camlo · 开幕
//
//  Manages the local Camlo Vault, compiles Morph & Video specs into complete PosterBoard
//  descriptors, exports standard .tendies archives, and safely imports/inspects external .tendies.
//

import Foundation
import Combine
import UIKit
import ZIPFoundation

@MainActor
final class TendiesVaultStore: ObservableObject {
    static let shared = TendiesVaultStore()

    @Published var items: [TendiesVaultItem] = []

    private let fm = FileManager.default

    private init() {
        CamloPaths.ensureDirectories()
        loadCatalog()
    }

    func loadCatalog() {
        guard let data = try? Data(contentsOf: CamloPaths.catalogJSON),
              let decoded = try? JSONDecoder().decode([TendiesVaultItem].self, from: data) else {
            items = []
            return
        }
        items = decoded.filter { item in
            let dir = CamloPaths.packagesDir.appendingPathComponent(item.storageFolderName)
            return fm.fileExists(atPath: dir.path)
        }
        let packagesRoot = CamloPaths.packagesDir
        Task.detached(priority: .utility) {
            Self.healAllPackagesCAML(under: packagesRoot)
        }
    }

    nonisolated private static func healAllPackagesCAML(under root: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else { return }
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "main.caml" {
            PosterBoardBridge.healParameterizedCAMLIfNeeded(at: fileURL)
        }
    }

    func saveCatalog() {
        CamloPaths.ensureDirectories()
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: CamloPaths.catalogJSON, options: .atomic)
        }
    }

    func toggleSelection(for id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isSelected.toggle()
        saveCatalog()
    }

    func delete(_ item: TendiesVaultItem) {
        let pkgDir = CamloPaths.packagesDir.appendingPathComponent(item.storageFolderName)
        try? fm.removeItem(at: pkgDir)
        if let thumb = item.thumbnailFilename {
            try? fm.removeItem(at: CamloPaths.thumbnailsDir.appendingPathComponent(thumb))
        }
        items.removeAll { $0.id == item.id }
        saveCatalog()
    }

    func thumbnailImage(for item: TendiesVaultItem) -> UIImage? {
        guard let thumb = item.thumbnailFilename else { return nil }
        let url = CamloPaths.thumbnailsDir.appendingPathComponent(thumb)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Build From Studio Specs

    func createMorphPackage(spec: MorphCompileSpec) throws -> TendiesVaultItem {
        CamloPaths.ensureDirectories()
        let itemID = UUID()
        let folderName = "CamloMorph_\(itemID.uuidString)"
        let descrUUID = UUID().uuidString.uppercased()
        let pkgRoot = CamloPaths.packagesDir.appendingPathComponent(folderName, isDirectory: true)
        let descrDir = pkgRoot.appendingPathComponent(descrUUID, isDirectory: true)

        let dayMetrics = PosterStyleGenerator.analyzePalette(of: spec.lockImage)
        let nightMetrics: WallpaperPaletteMetrics?
        if spec.enableDayNightMode {
            nightMetrics = PosterStyleGenerator.analyzePalette(
                of: spec.nightLockImage ?? PosterStyleGenerator.synthesizeNightImage(from: spec.lockImage)
            )
        } else {
            nightMetrics = nil
        }

        let wallpaperDir = try Self.scaffoldPosterDescriptor(
            at: descrDir,
            enableGyro: spec.enableGyroParallax,
            enableDayNight: spec.enableDayNightMode,
            canvasProfile: spec.canvasProfile,
            posterStyle: spec.posterStyle,
            dayMetrics: dayMetrics,
            nightMetrics: nightMetrics
        )
        try CAMLCompiler.writeMorphWallpaperDirectory(spec: spec, into: wallpaperDir)
        PosterBoardBridge.synchronizeCollectionsIdentifier(in: descrDir)

        let thumbName = try saveThumbnail(from: spec.lockImage, itemID: itemID)
        let cleanTitle = spec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Bi("滑动变身壁纸", "Morph Wallpaper")
            : spec.title.trimmingCharacters(in: .whitespacesAndNewlines)

        var summaryParts = [spec.preset.title]
        if spec.canvasProfile == .duoDualScreen {
            summaryParts.append(Bi("Duo 双屏", "Duo Dual"))
        }
        if spec.enableGyroParallax {
            summaryParts.append(Bi("3D 陀螺仪", "3D Gyro"))
        }
        if spec.enableDayNightMode {
            summaryParts.append(Bi("昼夜双生", "Day/Night"))
        }
        if spec.lockLiveSequence != nil || spec.unlockLiveSequence != nil {
            summaryParts.append(Bi("实况动态", "Live Motion"))
        }
        if spec.lockSubjectCutout != nil || spec.unlockSubjectCutout != nil {
            summaryParts.append(Bi("主体破框", "Depth Cutout"))
        }
        if spec.particlePreset != .none {
            summaryParts.append(spec.particlePreset.title)
        }
        if spec.posterStyle.homePairing == .legibilityBlur {
            summaryParts.append(Bi("柔焦主屏", "Soft Home"))
        }

        let item = TendiesVaultItem(
            id: itemID,
            title: cleanTitle,
            createdAt: Date(),
            kind: .morph,
            storageFolderName: folderName,
            descriptorFolderNames: [descrUUID],
            targetExtension: .wpKit,
            thumbnailFilename: thumbName,
            subtitleSummary: summaryParts.joined(separator: " · "),
            isSelected: true
        )
        items.insert(item, at: 0)
        saveCatalog()
        return item
    }

    func createVideoPackage(spec: VideoCompileSpec) throws -> TendiesVaultItem {
        CamloPaths.ensureDirectories()
        let itemID = UUID()
        let folderName = "CamloVideo_\(itemID.uuidString)"
        let descrUUID = UUID().uuidString.uppercased()
        let pkgRoot = CamloPaths.packagesDir.appendingPathComponent(folderName, isDirectory: true)
        let descrDir = pkgRoot.appendingPathComponent(descrUUID, isDirectory: true)

        let metrics = spec.sequence.previewImages.first.map { PosterStyleGenerator.analyzePalette(of: $0) }
            ?? .neutralFallback

        let wallpaperDir = try Self.scaffoldPosterDescriptor(
            at: descrDir,
            enableGyro: spec.enableGyroParallax,
            enableDayNight: false,
            canvasProfile: spec.canvasProfile,
            posterStyle: spec.posterStyle,
            dayMetrics: metrics,
            nightMetrics: nil
        )
        try CAMLCompiler.writeVideoWallpaperDirectory(spec: spec, into: wallpaperDir)
        PosterBoardBridge.synchronizeCollectionsIdentifier(in: descrDir)

        var thumbName: String?
        if let firstFrame = spec.sequence.previewImages.first {
            thumbName = try? saveThumbnail(from: firstFrame, itemID: itemID)
        }

        let cleanTitle = spec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Bi("动态锁屏壁纸", "Motion Wallpaper")
            : spec.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let durText = String(format: "%.1fs · %dfps", spec.sequence.durationSeconds, spec.sequence.fps)
        var summaryParts = [durText, spec.loopStyle.title]
        if spec.canvasProfile == .duoDualScreen {
            summaryParts.append(Bi("Duo 双屏", "Duo Dual"))
        }
        if spec.enableGyroParallax {
            summaryParts.append(Bi("3D 陀螺仪", "3D Gyro"))
        }
        if spec.particlePreset != .none {
            summaryParts.append(spec.particlePreset.title)
        }
        if spec.posterStyle.homePairing == .legibilityBlur {
            summaryParts.append(Bi("柔焦主屏", "Soft Home"))
        }

        let item = TendiesVaultItem(
            id: itemID,
            title: cleanTitle,
            createdAt: Date(),
            kind: .video,
            storageFolderName: folderName,
            descriptorFolderNames: [descrUUID],
            targetExtension: .wpKit,
            thumbnailFilename: thumbName,
            subtitleSummary: summaryParts.joined(separator: " · "),
            isSelected: true
        )
        items.insert(item, at: 0)
        saveCatalog()
        return item
    }

    // MARK: - Export Standard .tendies Archive

    func exportTendiesFile(for item: TendiesVaultItem) throws -> URL {
        CamloPaths.ensureDirectories()
        let safeName = item.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let finalBase = safeName.isEmpty ? "CamloWallpaper" : safeName

        let stagingRoot = URL.temporaryDirectory.appendingPathComponent("CamloStage_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stagingRoot) }

        let entries = item.resolvedDescriptorEntries
        let uniqueExtensions = Set(entries.map(\.extensionBundleID))
        let hasPreservedIdentity = entries.contains(where: \.preserveIdentity)
        let matchedTarget = uniqueExtensions.count == 1
            ? PBExtensionTarget.allCases.first(where: { $0.extensionIdentifier == uniqueExtensions.first })
            : nil

        let srcPkg = CamloPaths.packagesDir.appendingPathComponent(item.storageFolderName, isDirectory: true)
        let zipSourceURL: URL

        if !hasPreservedIdentity, let target = matchedTarget {
            let descrContainerName: String
            switch target {
            case .wpKit: descrContainerName = "descriptors"
            case .photos: descrContainerName = "video-descriptors"
            case .mercury: descrContainerName = "mercury-descriptors"
            }
            let stageDescrParent = stagingRoot.appendingPathComponent(descrContainerName, isDirectory: true)
            try fm.createDirectory(at: stageDescrParent, withIntermediateDirectories: true)

            for entry in entries {
                let folderLastName = (entry.folderName as NSString).lastPathComponent
                let src = srcPkg.appendingPathComponent(entry.folderName)
                let dst = stageDescrParent.appendingPathComponent(folderLastName)
                if fm.fileExists(atPath: src.path) {
                    try fm.copyItem(at: src, to: dst)
                    PosterBoardBridge.normalizeDescriptorForCurrentOS(in: dst, extensionBundleID: entry.extensionBundleID)
                }
            }
            zipSourceURL = stageDescrParent
        } else {
            let containerDir = stagingRoot.appendingPathComponent("Container", isDirectory: true)
            let extBase = containerDir.appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/61/Extensions", isDirectory: true)
            for entry in entries {
                let extID = entry.extensionBundleID
                guard !extID.isEmpty, !extID.contains("/"), ![".", ".."].contains(extID) else { continue }
                let folderLastName = (entry.folderName as NSString).lastPathComponent
                let src = srcPkg.appendingPathComponent(entry.folderName)
                let dstParent = extBase.appendingPathComponent("\(extID)/descriptors", isDirectory: true)
                let dst = dstParent.appendingPathComponent(folderLastName, isDirectory: true)
                if fm.fileExists(atPath: src.path) {
                    try fm.createDirectory(at: dstParent, withIntermediateDirectories: true)
                    if fm.fileExists(atPath: dst.path) {
                        try fm.removeItem(at: dst)
                    }
                    try fm.copyItem(at: src, to: dst)
                    PosterBoardBridge.normalizeDescriptorForCurrentOS(in: dst, extensionBundleID: extID)
                    try? fm.removeItem(at: dst.appendingPathComponent(PosterBoardBridge.camloMarkerFilename))
                }
            }
            zipSourceURL = containerDir
        }

        let outURL = CamloPaths.exportsDir.appendingPathComponent("\(finalBase).tendies")
        if fm.fileExists(atPath: outURL.path) {
            try fm.removeItem(at: outURL)
        }
        try fm.zipItem(at: zipSourceURL, to: outURL, shouldKeepParent: true, compressionMethod: .deflate)
        return outURL
    }

    // MARK: - Import External .tendies (Single-Pass Streaming Extract & Bottom-Up Bundle Discovery)

    private struct LocatedPosterBundle {
        let directory: URL
        let extensionBundleID: String
        let keepFolderName: Bool
    }

    nonisolated static func canonicalFileSystemPath(_ rawPath: String) -> String {
        var p = (rawPath as NSString).standardizingPath
        if p == "/var" {
            p = "/private/var"
        } else if p.hasPrefix("/var/") {
            p = "/private" + p
        } else if p == "/tmp" {
            p = "/private/tmp"
        } else if p.hasPrefix("/tmp/") {
            p = "/private" + p
        }
        while p.count > 1 && p.hasSuffix("/") {
            p.removeLast()
        }
        return p
    }

    private func extractTendiesArchive(at sourceURL: URL, into destinationRoot: URL) throws {
        let archive: Archive
        do {
            archive = try Archive(url: sourceURL, accessMode: .read, pathEncoding: nil)
        } catch {
            throw NSError(domain: "CamloImport", code: -1, userInfo: [NSLocalizedDescriptionKey: Bi("无法打开 .tendies 压缩包，请确认文件未损坏", "Cannot read .tendies archive")])
        }

        try fm.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        let resolvedRootPath = Self.canonicalFileSystemPath(destinationRoot.resolvingSymlinksInPath().path)
        let resolvedRootURL = URL(fileURLWithPath: resolvedRootPath, isDirectory: true)
        let rootPrefix = resolvedRootPath == "/" ? "/" : resolvedRootPath + "/"

        var entryCount = 0
        var totalUncompressed: UInt64 = 0
        let maxEntries = 16_384
        let maxExpandedBytes: UInt64 = 768 * 1024 * 1024

        for entry in archive {
            entryCount += 1
            totalUncompressed &+= UInt64(entry.uncompressedSize)
            if entryCount > maxEntries || totalUncompressed > maxExpandedBytes {
                throw NSError(domain: "CamloImport", code: -4, userInfo: [NSLocalizedDescriptionKey: Bi("壁纸压缩包体积或文件数量超过安全限制", "Archive exceeds safety size/count limit")])
            }

            let normalized = entry.path.replacingOccurrences(of: "\\", with: "/")
            let rawParts = normalized.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            if normalized.hasPrefix("/") || rawParts.contains("..") || entry.type == .symlink {
                throw NSError(domain: "CamloImport", code: -2, userInfo: [NSLocalizedDescriptionKey: Bi("检测到非法路径穿越或符号链接条目，已安全拦截导入", "Unsafe path traversal or symlink entry rejected")])
            }
            let parts = rawParts.filter { $0 != "." }
            guard !parts.isEmpty else { continue }
            if parts.contains(where: { $0.isEmpty || $0 == ".." || $0.contains("/") || $0.contains("\0") }) {
                throw NSError(domain: "CamloImport", code: -2, userInfo: [NSLocalizedDescriptionKey: Bi("检测到非法路径穿越条目，已安全拦截导入", "Unsafe path traversal entry rejected")])
            }

            // Skip Finder metadata / AppleDouble resource forks / Camlo legacy markers directly during stream unpack.
            let containsJunk = parts.contains { part in
                part == "__MACOSX"
                    || part == ".DS_Store"
                    || part == ".lock"
                    || part == PosterBoardBridge.camloMarkerFilename
                    || part.hasPrefix("._")
            }
            if containsJunk { continue }

            let targetURL = parts.reduce(resolvedRootURL) { $0.appendingPathComponent($1) }.standardizedFileURL
            let targetPath = Self.canonicalFileSystemPath(targetURL.path)
            guard targetPath == resolvedRootPath || targetPath.hasPrefix(rootPrefix) else {
                throw NSError(domain: "CamloImport", code: -2, userInfo: [NSLocalizedDescriptionKey: Bi("检测到非法路径穿越条目，已安全拦截导入", "Unsafe path traversal entry rejected")])
            }

            switch entry.type {
            case .directory:
                try fm.createDirectory(at: targetURL, withIntermediateDirectories: true)
            case .file:
                try fm.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: targetURL.path) {
                    try? fm.removeItem(at: targetURL)
                }
                _ = try archive.extract(entry, to: targetURL, skipCRC32: false)
            case .symlink:
                throw NSError(domain: "CamloImport", code: -2, userInfo: [NSLocalizedDescriptionKey: Bi("检测到非法符号链接条目，已安全拦截导入", "Unsafe symlink entry rejected")])
            }
        }
    }

    private func locateExtractedPosterBundles(in root: URL) -> [LocatedPosterBundle] {
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        let wpKitBuckets: Set<String> = ["descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors"]
        let videoBuckets: Set<String> = ["video-descriptor", "video-descriptors", "photo-descriptor", "photo-descriptors"]
        let mercuryBuckets: Set<String> = ["mercury-descriptor", "mercury-descriptors"]

        var bucketCandidates: [(URL, String)] = []
        var markerCandidates: [URL] = []

        while let item = enumerator.nextObject() as? URL {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            let name = item.lastPathComponent
            if name == "__MACOSX" {
                enumerator.skipDescendants()
                continue
            }

            let comps = item.pathComponents
            let lowerName = name.lowercased()

            // Container layout: .../Extensions/<extensionBundleID>/(descriptors|ordered-descriptors)/<descriptorDir>
            if (lowerName == "descriptors" || lowerName == "ordered-descriptors"),
               let extIdx = comps.lastIndex(where: { $0.caseInsensitiveCompare("Extensions") == .orderedSame }),
               comps.indices.contains(extIdx + 1) {
                let providerID = comps[extIdx + 1]
                if !providerID.isEmpty, !providerID.contains("/"), ![".", ".."].contains(providerID),
                   let children = childSubdirectories(of: item), !children.isEmpty {
                    bucketCandidates.append(contentsOf: children.map { ($0, providerID) })
                    enumerator.skipDescendants()
                    continue
                }
            }

            if wpKitBuckets.contains(lowerName),
               let children = childSubdirectories(of: item), !children.isEmpty {
                bucketCandidates.append(contentsOf: children.map { ($0, PBExtensionTarget.wpKit.extensionIdentifier) })
                enumerator.skipDescendants()
                continue
            }

            if mercuryBuckets.contains(lowerName),
               let children = childSubdirectories(of: item), !children.isEmpty {
                bucketCandidates.append(contentsOf: children.map { ($0, PBExtensionTarget.mercury.extensionIdentifier) })
                enumerator.skipDescendants()
                continue
            }

            if videoBuckets.contains(lowerName),
               let children = childSubdirectories(of: item), !children.isEmpty {
                let bucketHasVideoCAML = fm.fileExists(atPath: item.appendingPathComponent("VideoCAML").path)
                for child in children {
                    let childHasVideoCAML = bucketHasVideoCAML
                        || fm.fileExists(atPath: child.appendingPathComponent("VideoCAML").path)
                    let extID = childHasVideoCAML
                        ? PBExtensionTarget.wpKit.extensionIdentifier
                        : PBExtensionTarget.photos.extensionIdentifier
                    bucketCandidates.append((child, extID))
                }
                enumerator.skipDescendants()
                continue
            }

            // Bottom-up fallback marker check for bare / unbucketed descriptor folders (supports versions/0, versions/1, etc.)
            let hasRoleMarker = fm.fileExists(atPath: item.appendingPathComponent("com.apple.posterkit.role.identifier").path)
            let hasDescrID = fm.fileExists(atPath: item.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier").path)
            let hasVersions = fm.fileExists(atPath: item.appendingPathComponent("versions").path)
            if hasRoleMarker || hasDescrID || hasVersions {
                markerCandidates.append(item)
                enumerator.skipDescendants()
            }
        }

        let rawPairs: [(URL, String)] = bucketCandidates.isEmpty
            ? markerCandidates.map { ($0, inferredExtensionIdentifier(for: $0)) }
            : deduplicatedShallowest(bucketCandidates)

        return rawPairs.map { url, extID in
            let isCollections = extID.localizedCaseInsensitiveContains("CollectionsPoster")
            return LocatedPosterBundle(
                directory: url,
                extensionBundleID: extID,
                keepFolderName: !isCollections
            )
        }
    }

    private func childSubdirectories(of directory: URL) -> [URL]? {
        guard let children = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return children.filter { child in
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return isDir && child.lastPathComponent != "__MACOSX"
        }
    }

    private func inferredExtensionIdentifier(for descriptorURL: URL) -> String {
        let comps = descriptorURL.pathComponents
        if let extIdx = comps.lastIndex(where: { $0.caseInsensitiveCompare("Extensions") == .orderedSame }),
           comps.indices.contains(extIdx + 1) {
            let candidate = comps[extIdx + 1]
            if !candidate.isEmpty, !candidate.contains("/"), ![".", ".."].contains(candidate) {
                return candidate
            }
        }
        let parentName = descriptorURL.deletingLastPathComponent().lastPathComponent.lowercased()
        if parentName.hasPrefix("mercury-descriptor") {
            return PBExtensionTarget.mercury.extensionIdentifier
        }
        if parentName.hasPrefix("video-descriptor") || parentName.hasPrefix("photo-descriptor") {
            let hasVideoCAML = fm.fileExists(atPath: descriptorURL.appendingPathComponent("VideoCAML").path)
            return hasVideoCAML ? PBExtensionTarget.wpKit.extensionIdentifier : PBExtensionTarget.photos.extensionIdentifier
        }
        return PBExtensionTarget.wpKit.extensionIdentifier
    }

    private func deduplicatedShallowest(_ candidates: [(URL, String)]) -> [(URL, String)] {
        let canonicalEntries = candidates.map { entry -> (url: URL, ext: String, canonicalPath: String) in
            let path = Self.canonicalFileSystemPath(entry.0.resolvingSymlinksInPath().path)
            return (entry.0, entry.1, path)
        }
        let sorted = canonicalEntries.sorted {
            URL(fileURLWithPath: $0.canonicalPath).pathComponents.count < URL(fileURLWithPath: $1.canonicalPath).pathComponents.count
        }
        var kept: [(URL, String)] = []
        var keptPaths: [String] = []
        for entry in sorted {
            let p = entry.canonicalPath
            let isNested = keptPaths.contains { existing in
                p == existing || p.hasPrefix(existing + "/")
            }
            if !isNested {
                kept.append((entry.url, entry.ext))
                keptPaths.append(p)
            }
        }
        return kept
    }

    @discardableResult
    func importExternalTendies(
        from sourceURL: URL,
        preferredTitle: String? = nil,
        preferredKind: VaultItemKind = .imported,
        preferredSummary: String? = nil,
        cloudPackID: String? = nil
    ) throws -> TendiesVaultItem {
        CamloPaths.ensureDirectories()
        let tempExtract = URL.temporaryDirectory.appendingPathComponent("CamloImport_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempExtract) }

        try extractTendiesArchive(at: sourceURL, into: tempExtract)

        let discoveredSources = locateExtractedPosterBundles(in: tempExtract)
        guard !discoveredSources.isEmpty else {
            throw NSError(domain: "CamloImport", code: -3, userInfo: [NSLocalizedDescriptionKey: Bi("未在压缩包内找到有效的锁屏壁纸描述符目录 (descriptors)", "No valid PosterBoard descriptors found inside archive")])
        }

        let itemID = UUID()
        let rawTitle = sourceURL.deletingPathExtension().lastPathComponent
        let pkgFolderName = "Imported_\(itemID.uuidString)"
        let pkgDest = CamloPaths.packagesDir.appendingPathComponent(pkgFolderName, isDirectory: true)
        try fm.createDirectory(at: pkgDest, withIntermediateDirectories: true)

        var savedDescrNames: [String] = []
        var savedEntries: [VaultDescriptorEntry] = []

        for (idx, discovered) in discoveredSources.enumerated() {
            let relName: String
            if discovered.keepFolderName {
                let origName = discovered.directory.lastPathComponent
                let directDest = pkgDest.appendingPathComponent(origName, isDirectory: true)
                if !fm.fileExists(atPath: directDest.path) {
                    relName = origName
                } else {
                    let groupDir = pkgDest.appendingPathComponent("g\(idx)", isDirectory: true)
                    try fm.createDirectory(at: groupDir, withIntermediateDirectories: true)
                    relName = "g\(idx)/\(origName)"
                }
            } else {
                relName = UUID().uuidString.uppercased()
            }

            let dst = pkgDest.appendingPathComponent(relName, isDirectory: true)
            try fm.moveItem(at: discovered.directory, to: dst)
            if discovered.keepFolderName {
                PosterBoardBridge.normalizeDescriptorForCurrentOS(in: dst, extensionBundleID: discovered.extensionBundleID)
            } else {
                PosterBoardBridge.synchronizeCollectionsIdentifier(in: dst)
            }
            savedDescrNames.append(relName)
            savedEntries.append(VaultDescriptorEntry(
                folderName: relName,
                extensionBundleID: discovered.extensionBundleID,
                preserveIdentity: discovered.keepFolderName
            ))
        }

        let uniqueExts = Array(Set(savedEntries.map(\.extensionBundleID)))
        let detectedTarget: PBExtensionTarget
        if uniqueExts.count == 1, let only = uniqueExts.first,
           let matched = PBExtensionTarget.allCases.first(where: { $0.extensionIdentifier == only }) {
            detectedTarget = matched
        } else {
            detectedTarget = .wpKit
        }

        let previewThumb = extractFirstPreviewImage(in: pkgDest)
        var thumbFilename: String?
        if let previewThumb {
            thumbFilename = try? saveThumbnail(from: previewThumb, itemID: itemID)
        }

        let summary: String
        if uniqueExts.count > 1 {
            summary = Bi("共 \(savedDescrNames.count) 组壁纸 · 跨 \(uniqueExts.count) 个系统扩展", "\(savedDescrNames.count) poster(s) · \(uniqueExts.count) extensions")
        } else {
            let extTitle = PBProviderCatalog.sectionTitle(for: uniqueExts.first ?? detectedTarget.extensionIdentifier)
            summary = Bi("共 \(savedDescrNames.count) 组壁纸 · \(extTitle)", "\(savedDescrNames.count) poster(s) · \(extTitle)")
        }
        let trimmedPreferred = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalTitle = !trimmedPreferred.isEmpty ? trimmedPreferred : (rawTitle.isEmpty ? "Tendies" : rawTitle)
        let finalSummary = preferredSummary ?? summary
        let normalizedCloudID = cloudPackID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cid = normalizedCloudID, !cid.isEmpty {
            let staleItems = items.filter { $0.cloudPackID == cid }
            for stale in staleItems {
                try? fm.removeItem(at: CamloPaths.packagesDir.appendingPathComponent(stale.storageFolderName))
                if let thumb = stale.thumbnailFilename {
                    try? fm.removeItem(at: CamloPaths.thumbnailsDir.appendingPathComponent(thumb))
                }
            }
            items.removeAll { $0.cloudPackID == cid }
        }
        let newItem = TendiesVaultItem(
            id: itemID,
            title: finalTitle,
            createdAt: Date(),
            kind: preferredKind,
            storageFolderName: pkgFolderName,
            descriptorFolderNames: savedDescrNames,
            targetExtension: detectedTarget,
            thumbnailFilename: thumbFilename,
            subtitleSummary: finalSummary,
            isSelected: true,
            cloudPackID: (normalizedCloudID?.isEmpty == false) ? normalizedCloudID : nil,
            descriptorEntries: savedEntries
        )
        items.insert(newItem, at: 0)
        saveCatalog()
        return newItem
    }

    // MARK: - X-Ray Package Inspector

    func inspectPackage(_ item: TendiesVaultItem) -> TendiesInspectionReport {
        Self.inspectPackageFile(item)
    }

    nonisolated static func inspectPackageFile(_ item: TendiesVaultItem) -> TendiesInspectionReport {
        let fm = FileManager.default
        let pkgDir = CamloPaths.packagesDir.appendingPathComponent(item.storageFolderName, isDirectory: true)
        var totalLayers = 0
        var stateNamesSet = Set<String>()
        var transitionCount = 0
        var animationCount = 0
        var hasFloating = false
        var hasEmitter = false
        var detectedType = "LayeredAnimation"
        var hasGyroParallax = false
        var isAppearanceAware = false
        var hasDuoDualCanvas = false
        var canvasW = 390
        var canvasH = 844
        var assets: [(name: String, image: UIImage)] = []
        var totalBytes: Int64 = 0

        if let enumerator = fm.enumerator(at: pkgDir, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard vals?.isRegularFile == true else { continue }
                totalBytes += Int64(vals?.fileSize ?? 0)

                let lower = fileURL.lastPathComponent.lowercased()
                if lower == "wallpaper.plist",
                   let data = try? Data(contentsOf: fileURL),
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    if (plist["appearanceAware"] as? Bool) == true {
                        isAppearanceAware = true
                    }
                    if (plist["wantsDeviceMotion"] as? Bool) == true {
                        hasGyroParallax = true
                    }
                    if let assetsDict = plist["assets"] as? [String: Any],
                       let lockAndHome = assetsDict["lockAndHome"] as? [String: Any] {
                        if lockAndHome["dark"] != nil {
                            isAppearanceAware = true
                        }
                        if let def = lockAndHome["default"] as? [String: Any],
                           let t = def["type"] as? String, !t.isEmpty {
                            detectedType = t
                            if t == "ParameterizedCA" {
                                hasGyroParallax = true
                            }
                        }
                    }
                } else if lower.hasSuffix(".caml"), let xml = try? String(contentsOf: fileURL, encoding: .utf8) {
                    let layerHits = Self.regexCount("<CA[A-Za-z]*Layer\\b", in: xml)
                    totalLayers += layerHits
                    let explicitTransitions = Self.regexCount("<LKStateTransition\\b", in: xml)
                    transitionCount += explicitTransitions
                    animationCount += Self.regexCount("<animation\\b", in: xml)
                    if xml.contains("<CAEmitterLayer") {
                        hasEmitter = true
                    }
                    let propGroupsSlice: Substring? = {
                        guard let start = xml.range(of: "<wallpaperPropertyGroups"),
                              let end = xml.range(of: "</wallpaperPropertyGroups>", range: start.upperBound..<xml.endIndex) else {
                            return nil
                        }
                        return xml[start.lowerBound..<end.upperBound]
                    }()
                    let hasParameterizedFloatingGroups = propGroupsSlice?.range(
                        of: "<view\\s+type=\"string\"\\s+value=\"Floating\"\\s*/>",
                        options: [.regularExpression, .caseInsensitive]
                    ) != nil
                    if (fileURL.path.lowercased().contains("floating") && layerHits > 2) ||
                       xml.contains("id=\"float_lock\"") ||
                       xml.contains("id=\"float_unlock\"") ||
                       hasParameterizedFloatingGroups {
                        hasFloating = true
                    }
                    if xml.contains("<wallpaperParallaxGroups") && xml.contains("<NSDictionary") {
                        hasGyroParallax = true
                    }
                    if xml.contains("<wallpapers") && xml.contains("BACKGROUND_INNER") {
                        hasDuoDualCanvas = true
                    }
                    for st in ["Sleep", "Locked", "Unlock"] where xml.contains("LKState name=\"\(st)\"") {
                        stateNamesSet.insert(st)
                    }
                    if xml.contains("<wallpaperPropertyGroups") && xml.contains("<v_lock") {
                        stateNamesSet.formUnion(["Sleep", "Locked", "Unlock"])
                        if explicitTransitions == 0 {
                            transitionCount += Self.regexCount("<v_home\\b", in: xml)
                        }
                    }
                    if let boundsMatch = Self.firstCapture("bounds=\"0 0 ([0-9]+) ([0-9]+)\"", in: xml),
                       boundsMatch.count == 2,
                       let w = Int(boundsMatch[0]), let h = Int(boundsMatch[1]), w > 0, h > 0 {
                        canvasW = w
                        canvasH = h
                    }
                } else if (lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".heic")),
                          assets.count < 12,
                          let imgData = try? Data(contentsOf: fileURL),
                          let img = autoreleasepool(invoking: {
                              UIImage.downsampledRetina(from: imgData, maxPixelDimension: 420) ?? UIImage(data: imgData)
                          }) {
                    assets.append((fileURL.lastPathComponent, img))
                }
            }
        }

        let entries = item.resolvedDescriptorEntries
        let firstDesc = Self.locateFirstDescriptorDirectory(in: pkgDir, entries: entries, fm: fm)
        let styleSummary = firstDesc.map { PosterStyleGenerator.parseDescriptorStyleSummary(in: $0) }
        let descriptorCount = Self.resolveDescriptorCount(in: pkgDir, entries: entries, fm: fm)

        return TendiesInspectionReport(
            item: item,
            descriptorCount: descriptorCount,
            canvasWidth: canvasW,
            canvasHeight: canvasH,
            totalLayers: totalLayers,
            stateNames: ["Sleep", "Locked", "Unlock"].filter { stateNamesSet.contains($0) },
            transitionCount: transitionCount,
            animationCount: animationCount,
            hasFloatingDepth: hasFloating,
            hasEmitterParticles: hasEmitter,
            wallpaperType: detectedType,
            hasGyroParallax: hasGyroParallax,
            isAppearanceAware: isAppearanceAware,
            clockFontIdentifier: styleSummary?.clockFontIdentifier,
            hasHomeLegibilityBlur: styleSummary?.hasLegibilityBlur ?? false,
            hasDuoDualCanvas: hasDuoDualCanvas,
            assetImages: assets,
            packageSizeBytes: totalBytes
        )
    }

    nonisolated private static func locateFirstDescriptorDirectory(
        in pkgDir: URL,
        entries: [VaultDescriptorEntry],
        fm: FileManager
    ) -> URL? {
        func isDirectory(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }

        for entry in entries {
            let candidates = [
                pkgDir.appendingPathComponent(entry.folderName, isDirectory: true),
                pkgDir.appendingPathComponent("descriptors", isDirectory: true)
                    .appendingPathComponent(entry.folderName, isDirectory: true),
                pkgDir.appendingPathComponent("extensions/\(entry.extensionBundleID)/descriptors/\(entry.folderName)", isDirectory: true),
                pkgDir.appendingPathComponent("Extensions/\(entry.extensionBundleID)/descriptors/\(entry.folderName)", isDirectory: true)
            ]
            if let match = candidates.first(where: isDirectory) {
                return match
            }
        }

        let descriptorsRoot = pkgDir.appendingPathComponent("descriptors", isDirectory: true)
        if let first = firstChildDirectory(in: descriptorsRoot, fm: fm) {
            return first
        }
        for extContainer in ["extensions", "Extensions"] {
            let extRoot = pkgDir.appendingPathComponent(extContainer, isDirectory: true)
            if let extDirs = try? fm.contentsOfDirectory(at: extRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for extDir in extDirs where isDirectory(extDir) {
                    if let first = firstChildDirectory(in: extDir.appendingPathComponent("descriptors", isDirectory: true), fm: fm) {
                        return first
                    }
                }
            }
        }
        return firstChildDirectory(in: pkgDir, fm: fm)
    }

    nonisolated private static func resolveDescriptorCount(
        in pkgDir: URL,
        entries: [VaultDescriptorEntry],
        fm: FileManager
    ) -> Int {
        if !entries.isEmpty {
            return max(1, entries.count)
        }
        var count = childDirectoryCount(in: pkgDir.appendingPathComponent("descriptors", isDirectory: true), fm: fm)
        for extContainer in ["extensions", "Extensions"] {
            let extRoot = pkgDir.appendingPathComponent(extContainer, isDirectory: true)
            if let extDirs = try? fm.contentsOfDirectory(at: extRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for extDir in extDirs {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: extDir.path, isDirectory: &isDir), isDir.boolValue {
                        count += childDirectoryCount(in: extDir.appendingPathComponent("descriptors", isDirectory: true), fm: fm)
                    }
                }
            }
        }
        if count > 0 {
            return count
        }
        return max(0, childDirectoryCount(in: pkgDir, fm: fm))
    }

    nonisolated private static func firstChildDirectory(in dir: URL, fm: FileManager) -> URL? {
        guard let children = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return children.first { child in
            (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && child.lastPathComponent != "__MACOSX"
        }
    }

    nonisolated private static func childDirectoryCount(in dir: URL, fm: FileManager) -> Int {
        guard let children = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return children.filter { child in
            (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && child.lastPathComponent != "__MACOSX"
        }.count
    }

    // MARK: - Private Scaffolding & Helpers

    nonisolated static func seedPlistData(named name: String) throws -> Data {
        if let bundleURL = Bundle.main.url(forResource: "PosterSeed", withExtension: "bundle") {
            let fileURL = bundleURL.appendingPathComponent(name)
            if let data = try? Data(contentsOf: fileURL) {
                return data
            }
        }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        if let directURL = Bundle.main.url(forResource: base, withExtension: ext),
           let data = try? Data(contentsOf: directURL) {
            return data
        }
        throw NSError(domain: "CamloSeed", code: -99, userInfo: [NSLocalizedDescriptionKey: "Missing embedded PosterSeed resource: \(name)"])
    }

    /// Scaffolds an Apple CollectionsPoster-compatible descriptor directory and returns the `.wallpaper` directory URL.
    private static func scaffoldPosterDescriptor(
        at descrDir: URL,
        enableGyro: Bool,
        enableDayNight: Bool,
        canvasProfile: CanvasDisplayProfile = .standardPhone,
        posterStyle: PosterStyleSpec,
        dayMetrics: WallpaperPaletteMetrics,
        nightMetrics: WallpaperPaletteMetrics?
    ) throws -> URL {
        let useParameterized = enableGyro || (canvasProfile == .duoDualScreen)
        let fm = FileManager.default
        let ver1Dir = descrDir.appendingPathComponent("versions/1", isDirectory: true)
        let contentsDir = ver1Dir.appendingPathComponent("contents", isDirectory: true)
        let supplements0Dir = ver1Dir.appendingPathComponent("supplements/0", isDirectory: true)
        let baseIDInt = useParameterized ? 7920 : 7400
        let baseIDString = String(baseIDInt)
        let wallpaperBundleName = useParameterized
            ? "7920.Camlo_3D-390w-844h@3x~iphone.wallpaper"
            : "7400.WWDC_2022-390w-844h@3x~iphone.wallpaper"
        let wallpaperDir = contentsDir.appendingPathComponent(wallpaperBundleName, isDirectory: true)
        try fm.createDirectory(at: wallpaperDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: supplements0Dir, withIntermediateDirectories: true)

        // Root descriptor metadata
        try baseIDString.data(using: .utf8)?.write(to: descrDir.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier"), options: .atomic)
        try "PRPosterRoleLockScreen".data(using: .utf8)?.write(to: descrDir.appendingPathComponent("com.apple.posterkit.role.identifier"), options: .atomic)
        try seedPlistData(named: "providerInfo.plist").write(to: descrDir.appendingPathComponent("providerInfo.plist"), options: .atomic)

        // Smart runtime snapshot metadata, clock typography/color & Home Screen pairing plists
        let lockSnapshotData = try PosterStyleGenerator.buildRuntimeSnapshotMetadataData(
            color: dayMetrics.averageColor,
            contrast: dayMetrics.averageContrast,
            seedData: seedPlistData(named: "RuntimeSnapshotMetadata-lock.plist")
        )
        let homeBaseColor: RGBAColor
        switch posterStyle.homePairing {
        case .matchedSolid:    homeBaseColor = dayMetrics.matchedSolidColor
        case .matchedGradient: homeBaseColor = dayMetrics.matchedGradientColor
        default:               homeBaseColor = dayMetrics.averageColor
        }
        let homeSnapshotData = try PosterStyleGenerator.buildRuntimeSnapshotMetadataData(
            color: homeBaseColor,
            contrast: dayMetrics.averageContrast,
            seedData: seedPlistData(named: "RuntimeSnapshotMetadata-home.plist")
        )
        let titleStyleData = try PosterStyleGenerator.buildTitleStyleConfigurationData(
            spec: posterStyle,
            metrics: dayMetrics,
            seedData: seedPlistData(named: "titleStyleConfiguration.plist")
        )
        let homeConfigData = try PosterStyleGenerator.buildHomeScreenConfigurationData(
            spec: posterStyle,
            metrics: dayMetrics,
            seedData: seedPlistData(named: "homescreenConfiguration.plist")
        )

        try homeSnapshotData.write(to: ver1Dir.appendingPathComponent("RuntimeSnapshotMetadata-home.plist"), options: .atomic)
        try lockSnapshotData.write(to: ver1Dir.appendingPathComponent("RuntimeSnapshotMetadata-lock.plist"), options: .atomic)
        try seedPlistData(named: "complicationLayout.plist").write(to: ver1Dir.appendingPathComponent("com.apple.posterkit.provider.instance.complicationLayout.plist"), options: .atomic)
        try titleStyleData.write(to: ver1Dir.appendingPathComponent("com.apple.posterkit.provider.instance.titleStyleConfiguration.plist"), options: .atomic)
        try homeConfigData.write(to: supplements0Dir.appendingPathComponent("com.apple.posterkit.provider.supplementURL.homescreenConfiguration.plist"), options: .atomic)

        // versions/1/contents metadata
        try seedPlistData(named: "configurableOptions.plist").write(to: contentsDir.appendingPathComponent(".com.apple.posterkit.provider.contents.configurableOptions.plist"), options: .atomic)
        try seedPlistData(named: "otherMetadata.plist").write(to: contentsDir.appendingPathComponent("com.apple.posterkit.provider.contents.otherMetadata.plist"), options: .atomic)

        let userInfoDict: [String: Any] = [
            "wallpaperRepresentingIdentifier": baseIDInt,
            "wallpaperRepresentingFileName": wallpaperBundleName,
            "posterEnvironmentOverrides": Data("{}".utf8)
        ]
        let userInfoData = try PropertyListSerialization.data(fromPropertyList: userInfoDict, format: .binary, options: 0)
        try userInfoData.write(to: contentsDir.appendingPathComponent("com.apple.posterkit.provider.contents.userInfo"), options: .atomic)

        var prominentColorDict: [String: Any] = [
            "default": dayMetrics.matchedGradientColor.hexRGBString
        ]
        if enableDayNight, let nightMetrics {
            prominentColorDict["dark"] = nightMetrics.matchedGradientColor.hexRGBString
        }

        let resolvedTitleColor = PosterStyleGenerator.resolveClockColor(mode: posterStyle.clockColorMode, metrics: dayMetrics)
            ?? dayMetrics.smartContrastClockColor
        let preferredTitleHex = resolvedTitleColor.hexRGBString + "02"

        var lockAndHomeDict: [String: Any] = [:]
        let wallpaperPlistDict: [String: Any]

        if useParameterized {
            lockAndHomeDict["default"] = [
                "assetFileName": "wallpaper.ca",
                "identifier": 7920,
                "name": "Lavender",
                "type": "ParameterizedCA"
            ]
            if enableDayNight {
                lockAndHomeDict["dark"] = [
                    "assetFileName": "wallpaper_dark.ca",
                    "identifier": 7921,
                    "name": "Lavender Dark",
                    "type": "ParameterizedCA"
                ]
            }
            wallpaperPlistDict = [
                "appearanceAware": enableDayNight,
                "contentVersion": canvasProfile == .duoDualScreen ? 1.11 : 1.07,
                "family": "Marble",
                "identifier": 7920,
                "logicalScreenClass": "any",
                "name": "Lavender",
                "preferredProminentColor": prominentColorDict,
                "preferredTitleColor": [preferredTitleHex],
                "requiresLandscapeScaling": true,
                "version": canvasProfile == .duoDualScreen ? 7 : 6,
                "wantsDeviceMotion": true,
                "assets": [
                    "lockAndHome": lockAndHomeDict
                ]
            ]
        } else {
            lockAndHomeDict["default"] = [
                "backgroundAnimationFileName": "7400.WWDC_2022_Background-390w-844h@3x~iphone.ca",
                "floatingAnimationFileNameKey": "7400.WWDC_2022_Floating-390w-844h@3x~iphone.ca",
                "foregroundAnimationFileName": "7400.WWDC_2022_Foreground-390w-844h@3x~iphone.ca",
                "identifier": 7400,
                "name": "WWDC 2022",
                "type": "LayeredAnimation"
            ]
            if enableDayNight {
                lockAndHomeDict["dark"] = [
                    "backgroundAnimationFileName": "7401.WWDC_2022_Dark_Background-390w-844h@3x~iphone.ca",
                    "floatingAnimationFileNameKey": "7401.WWDC_2022_Dark_Floating-390w-844h@3x~iphone.ca",
                    "foregroundAnimationFileName": "7401.WWDC_2022_Dark_Foreground-390w-844h@3x~iphone.ca",
                    "identifier": 7401,
                    "name": "WWDC 2022 Dark",
                    "type": "LayeredAnimation"
                ]
            }
            var dict: [String: Any] = [
                "appearanceAware": enableDayNight,
                "family": "WWDC22",
                "identifier": 7400,
                "logicalScreenClass": "390w-844h@3x~iphone",
                "name": "WWDC 2022",
                "preferredProminentColor": prominentColorDict,
                "version": 1,
                "assets": [
                    "lockAndHome": lockAndHomeDict
                ]
            ]
            if posterStyle.clockColorMode != .systemAuto {
                dict["preferredTitleColor"] = [preferredTitleHex]
            }
            wallpaperPlistDict = dict
        }

        let wpData = try PropertyListSerialization.data(fromPropertyList: wallpaperPlistDict, format: .binary, options: 0)
        try wpData.write(to: wallpaperDir.appendingPathComponent("Wallpaper.plist"), options: .atomic)

        return wallpaperDir
    }

    private func saveThumbnail(from image: UIImage, itemID: UUID) throws -> String {
        let thumb = image.aspectFilled(to: CGSize(width: 390, height: 844))
        let name = "thumb_\(itemID.uuidString).jpg"
        let url = CamloPaths.thumbnailsDir.appendingPathComponent(name)
        if let data = thumb.jpegData(compressionQuality: 0.80) {
            try data.write(to: url, options: .atomic)
        }
        return name
    }

    private func extractFirstPreviewImage(in dir: URL) -> UIImage? {
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return nil }
        var fallbackImage: UIImage?
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent.lowercased()
            guard name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") || name.hasSuffix(".png") || name.hasSuffix(".heic") else { continue }
            guard !name.hasPrefix("particle_") else { continue }
            if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data), img.size.width >= 120 {
                if name.contains("lock") || name.contains("0.") || name.contains("frame_0") || name.contains("background") {
                    return img
                }
                if fallbackImage == nil {
                    fallbackImage = img
                }
            }
        }
        return fallbackImage
    }

    nonisolated private static func regexCount(_ pattern: String, in text: String) -> Int {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        return re.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    nonisolated private static func firstCapture(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []),
              let match = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1 else { return nil }
        var out: [String] = []
        for i in 1..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                out.append(String(text[r]))
            }
        }
        return out
    }
}
