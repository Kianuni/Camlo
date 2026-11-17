//
//  PosterBoardBridge.swift
//  Camlo · 开幕
//
//  Manages PosterBoard container discovery, safe descriptor injection, multi-ID randomization,
//  non-destructive GalleryCache refresh, and Camlo-tagged descriptor cleanup.
//

import Foundation
import Combine
import UIKit

enum PBExtensionTarget: String, Codable, CaseIterable, Identifiable {
    case wpKit = "wpKit"
    case photos = "photos"
    case mercury = "mercury"

    var id: String { rawValue }

    var extensionIdentifier: String {
        switch self {
        case .wpKit: return "com.apple.WallpaperKit.CollectionsPoster"
        case .photos: return "com.apple.PhotosUIPrivate.PhotosPosterProvider"
        case .mercury: return "com.apple.MercuryPoster"
        }
    }

    var displayName: String {
        switch self {
        case .wpKit: return Bi("机型专属栏 / 收藏 (CollectionsPoster)", "Device Collection / Collections")
        case .photos: return Bi("实况视频 (PhotosPoster)", "Photos / Video Poster")
        case .mercury: return Bi("水星流体 (MercuryPoster)", "Mercury Poster")
        }
    }

    static func resolveStoreVersion(in containerPath: String) -> String {
        let fm = FileManager.default
        let wq = WorseQueryBridge.shared
        let storeRoot = URL(fileURLWithPath: containerPath)
            .appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore")
        _ = wq.grantAccess(path: storeRoot.path, requireWrite: false)

        let children = (try? fm.contentsOfDirectory(atPath: storeRoot.path)) ?? []
        let numericDescending = children.compactMap { Int($0) }.sorted(by: >)
        for ver in numericDescending {
            let verStr = String(ver)
            let verURL = storeRoot.appendingPathComponent(verStr)
            _ = wq.grantAccess(path: verURL.path, requireWrite: false)
            let extURL = verURL.appendingPathComponent("Extensions")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: extURL.path, isDirectory: &isDir), isDir.boolValue {
                return verStr
            }
        }
        if let highest = numericDescending.first {
            return String(highest)
        }
        return "61"
    }

    func resolvedDescriptorsRelPath(in containerPath: String) -> String {
        let ver = Self.resolveStoreVersion(in: containerPath)
        return "Library/Application Support/PRBPosterExtensionDataStore/\(ver)/Extensions/\(extensionIdentifier)/descriptors"
    }
}

@MainActor
final class PosterBoardBridge: ObservableObject {
    static let shared = PosterBoardBridge()
    nonisolated static let camloMarkerFilename = ".camlo_origin"
    nonisolated static let uuidTitlesDefaultsKey = "camlo_uuid_titles_v1"
    private static let trackedNamesDefaultsKey = "camlo_injected_descriptor_names_v2"
    nonisolated private static let nextDescendingIDKey = "camlo_next_descending_wp_id_v1"
    private static let itemDescriptorMapKey = "camlo_item_descriptor_map_v1"
    nonisolated private static let savedContainerPathKey = "camlo_pb_container_path"

    nonisolated static func recordDescriptorTitles(_ mapping: [String: String]) {
        guard !mapping.isEmpty else { return }
        var stored = UserDefaults.standard.dictionary(forKey: uuidTitlesDefaultsKey) as? [String: String] ?? [:]
        for (rawUUID, rawTitle) in mapping {
            let uuid = rawUUID.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uuid.isEmpty, !title.isEmpty else { continue }
            stored[uuid.uppercased()] = title
        }
        UserDefaults.standard.set(stored, forKey: uuidTitlesDefaultsKey)
    }

    nonisolated static func recordedTitlesByUUID() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: uuidTitlesDefaultsKey) as? [String: String] ?? [:]
    }

    func untrackDeletedDescriptors(_ uuids: Set<String>) {
        guard !uuids.isEmpty else { return }
        let upperUUIDs = Set(uuids.map { $0.uppercased() })

        var tracked = UserDefaults.standard.stringArray(forKey: Self.trackedNamesDefaultsKey) ?? []
        tracked.removeAll { uuids.contains($0) || upperUUIDs.contains($0.uppercased()) }
        UserDefaults.standard.set(tracked, forKey: Self.trackedNamesDefaultsKey)

        if var map = UserDefaults.standard.dictionary(forKey: Self.itemDescriptorMapKey) as? [String: String] {
            for (key, value) in map where uuids.contains(value) || upperUUIDs.contains(value.uppercased()) {
                map.removeValue(forKey: key)
            }
            UserDefaults.standard.set(map, forKey: Self.itemDescriptorMapKey)
        }

        if var titleMap = UserDefaults.standard.dictionary(forKey: Self.uuidTitlesDefaultsKey) as? [String: String] {
            for key in Array(titleMap.keys) where uuids.contains(key) || upperUUIDs.contains(key.uppercased()) {
                titleMap.removeValue(forKey: key)
            }
            UserDefaults.standard.set(titleMap, forKey: Self.uuidTitlesDefaultsKey)
        }
    }

    @Published var containerPath: String {
        didSet {
            let trimmed = containerPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: Self.savedContainerPathKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: Self.savedContainerPathKey)
            }
        }
    }
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var hasContainerAccess: Bool = false
    @Published private(set) var activeAppGroup: String = ""
    @Published private(set) var statusSummary: String = ""
    @Published var respringNonce: UUID? = nil

    private var respringWatchdogTask: Task<Void, Never>? = nil
    private let fm = FileManager.default

    private init() {
        self.containerPath = UserDefaults.standard.string(forKey: Self.savedContainerPathKey) ?? ""
        self.activeAppGroup = WorseQueryBridge.shared.activeAppGroup
    }

    func bootstrapIfNeeded() {
        guard !isScanning else { return }
        if hasContainerAccess && !containerPath.isEmpty { return }
        refreshContainerAccess(forceRescan: false)
    }

    nonisolated private static func verifyPosterBoardContainer(
        _ resolved: String
    ) -> (ok: Bool, missing: Bool, message: String) {
        let fm = FileManager.default
        let wq = WorseQueryBridge.shared
        let canonical = CSStoreEngine.canonicalPrivatePath(resolved)
        let rootGrant = wq.grantAccess(path: resolved, requireWrite: true)
        guard rootGrant.0 else {
            return (false, rootGrant.1 == -255, rootGrant.2)
        }
        guard fm.fileExists(atPath: canonical) else {
            return (false, true, Bi("目标容器路径不存在", "Target container path does not exist"))
        }

        var buf = [CChar](repeating: 0, count: 512)
        let len = getxattr(canonical, "com.apple.containermanager.identifier", &buf, 511, 0, 0)
        if len > 0 {
            buf[min(len, buf.count - 1)] = 0
            let bid = String(cString: buf)
            if !bid.isEmpty && bid.caseInsensitiveCompare("com.apple.PosterBoard") != .orderedSame {
                return (
                    false,
                    true,
                    Bi("已缓存容器属于 \(bid)，非 PosterBoard", "Cached container belongs to \(bid), not PosterBoard")
                )
            }
        }
        return (true, false, "")
    }

    private func resolveContainerForDirectAction(emptyErrorMessage: String) -> (ok: Bool, path: String, error: String) {
        let wq = WorseQueryBridge.shared
        var targetContainer = containerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        var rootGrant: (Bool, Int64, String) = (false, 0, "")
        var isValid = false

        if !targetContainer.isEmpty {
            rootGrant = wq.grantAccess(path: targetContainer)
            isValid = rootGrant.0 && fm.fileExists(atPath: targetContainer)
        }

        if !isValid && wq.hasUsableAppGroupContainer {
            CSStoreEngine.shared.invalidate()
            let recovered = CSStoreEngine.shared.resolvePosterBoardContainerPath()
            if !recovered.isEmpty {
                let recoveredGrant = wq.grantAccess(path: recovered)
                if recoveredGrant.0 && fm.fileExists(atPath: recovered) {
                    targetContainer = recovered
                    rootGrant = recoveredGrant
                    isValid = true
                    UserDefaults.standard.set(recovered, forKey: Self.savedContainerPathKey)
                    self.containerPath = recovered
                    self.activeAppGroup = wq.activeAppGroup
                    self.hasContainerAccess = true
                    self.statusSummary = Bi("已就绪 · 支持免电脑一键直写锁屏", "Ready · Direct 1-Tap Apply Enabled")
                } else {
                    targetContainer = recovered
                    rootGrant = recoveredGrant
                }
            }
        }

        guard isValid else {
            if targetContainer.isEmpty {
                return (false, "", emptyErrorMessage)
            }
            return (false, "", rootGrant.0 ? Bi("目标容器路径不存在", "Target container path does not exist") : rootGrant.2)
        }

        if !self.hasContainerAccess {
            self.hasContainerAccess = true
            self.activeAppGroup = wq.activeAppGroup
            self.statusSummary = Bi("已就绪 · 支持免电脑一键直写锁屏", "Ready · Direct 1-Tap Apply Enabled")
        }
        return (true, targetContainer, "")
    }

    func refreshContainerAccess(forceRescan: Bool) {
        guard !isScanning else { return }
        isScanning = true
        statusSummary = Bi("正在解析 CSStore2 并校验容器访问权限…", "Scanning CSStore2 & verifying container access…")
        let previousPath = containerPath.trimmingCharacters(in: .whitespacesAndNewlines)

        Task.detached(priority: .userInitiated) {
            let wq = WorseQueryBridge.shared
            let groupID = wq.refreshAppGroup()
            let groupUsable = wq.hasUsableAppGroupContainer

            var granted = false
            var resolvedPath = ""
            var lastDiagnosticError = ""
            var previousMissing = false

            if !forceRescan && !previousPath.isEmpty {
                let check = Self.verifyPosterBoardContainer(previousPath)
                if check.ok {
                    granted = true
                    resolvedPath = CSStoreEngine.normalizeVarPath(previousPath)
                } else {
                    previousMissing = check.missing
                    if !check.missing {
                        lastDiagnosticError = check.message
                    }
                    CSStoreEngine.shared.invalidate()
                }
            }

            if !granted && groupUsable {
                if forceRescan {
                    CSStoreEngine.shared.invalidate()
                }
                let found = CSStoreEngine.shared.resolvePosterBoardContainerPath()
                if !found.isEmpty {
                    let check = Self.verifyPosterBoardContainer(found)
                    if check.ok {
                        granted = true
                        resolvedPath = CSStoreEngine.normalizeVarPath(found)
                    } else {
                        resolvedPath = check.missing ? "" : CSStoreEngine.normalizeVarPath(found)
                        lastDiagnosticError = check.message
                    }
                } else if forceRescan && !previousPath.isEmpty {
                    let check = Self.verifyPosterBoardContainer(previousPath)
                    if check.ok {
                        granted = true
                        resolvedPath = CSStoreEngine.normalizeVarPath(previousPath)
                    } else {
                        previousMissing = check.missing
                        if !check.missing {
                            lastDiagnosticError = check.message
                        }
                    }
                }
            }

            let finalMessage: String
            if granted {
                finalMessage = Bi("已就绪 · 支持免电脑一键直写锁屏", "Ready · Direct 1-Tap Apply Enabled")
            } else if !groupUsable {
                finalMessage = Bi("当前签名未携带可用 App Group，免电脑直写不可用，但可完整制作并导出 .tendies", "App Group entitlement missing; direct apply unavailable, .tendies export works normally")
            } else if !lastDiagnosticError.isEmpty {
                finalMessage = lastDiagnosticError
            } else {
                finalMessage = Bi("暂未定位到 PosterBoard 容器（可先点击下方「唤起 PosterBoard」后再重新扫描，或导出 .tendies）", "PosterBoard container not located yet (launch PosterBoard below then rescan, or export .tendies)")
            }

            let finalPath = resolvedPath
            let finalGranted = granted
            let shouldClearPrevious = previousMissing

            await MainActor.run {
                if finalGranted || !finalPath.isEmpty {
                    self.containerPath = finalPath
                } else if shouldClearPrevious {
                    self.containerPath = ""
                }
                self.activeAppGroup = groupID
                self.hasContainerAccess = finalGranted
                self.statusSummary = finalMessage
                self.isScanning = false
            }
        }
    }

    func validateManualPath(_ newPath: String) {
        let trimmed = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hasContainerAccess = false
            return
        }
        let res = WorseQueryBridge.shared.grantAccess(path: trimmed)
        hasContainerAccess = res.0 && fm.fileExists(atPath: trimmed)
        statusSummary = hasContainerAccess
            ? Bi("手动容器路径验证通过", "Manual container path verified")
            : res.2
    }

    // MARK: - Clean-Room Descriptor Normalization & ID Synchronization

    nonisolated static func sanitizeDescriptorTree(at root: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        var purgeTargets: [URL] = []
        while let entry = enumerator.nextObject() as? URL {
            let name = entry.lastPathComponent
            if name == "__MACOSX" {
                enumerator.skipDescendants()
                purgeTargets.append(entry)
            } else if name == ".DS_Store" || name == ".lock" || name == camloMarkerFilename || name.hasPrefix("._") {
                purgeTargets.append(entry)
            }
        }
        for target in purgeTargets {
            try? fm.removeItem(at: target)
        }
    }

    nonisolated static func numericVersionDirectories(in descriptorDir: URL) -> [URL] {
        let fm = FileManager.default
        let versionsRoot = descriptorDir.appendingPathComponent("versions", isDirectory: true)
        guard let children = try? fm.contentsOfDirectory(
            at: versionsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return children
            .compactMap { url -> (Int, URL)? in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                      let ver = Int(url.lastPathComponent) else { return nil }
                return (ver, url)
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }

    nonisolated static func seedFileIfMissing(_ seedFilename: String, to destinationURL: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destinationURL.path),
              let seedData = try? TendiesVaultStore.seedPlistData(named: seedFilename) else {
            return
        }
        try? fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? seedData.write(to: destinationURL, options: .atomic)
    }

    /// Normalizes a CollectionsPoster / community descriptor for iOS 26/27 multi-device PosterBoard loading:
    /// - Strips `__MACOSX`, `.DS_Store`, `.lock`, and `._*` AppleDouble junk files
    /// - Seeds missing PosterKit role/suggestion/homescreen/runtime plists across all `versions/<n>` directories
    /// - Removes hardware `productTypes` locks from `Wallpaper.plist` and foreign `.atx` device snapshots
    nonisolated static func normalizeDescriptorForCurrentOS(
        in descriptorDir: URL,
        extensionBundleID: String = PBExtensionTarget.wpKit.extensionIdentifier
    ) {
        sanitizeDescriptorTree(at: descriptorDir)
        let fm = FileManager.default
        let isCollections = extensionBundleID.localizedCaseInsensitiveContains("CollectionsPoster")
        let isMercury = extensionBundleID.localizedCaseInsensitiveContains("MercuryPoster")

        if isCollections {
            let roleURL = descriptorDir.appendingPathComponent("com.apple.posterkit.role.identifier")
            if !fm.fileExists(atPath: roleURL.path) {
                try? Data("PRPosterRoleLockScreen".utf8).write(to: roleURL, options: .atomic)
            }
            seedFileIfMissing("providerInfo.plist", to: descriptorDir.appendingPathComponent("providerInfo.plist"))

            let suggestionURL = descriptorDir.appendingPathComponent("com.apple.posterkit.provider.identifierURL.suggestionMetadata.plist")
            if fm.fileExists(atPath: suggestionURL.path),
               let suggestionData = try? Data(contentsOf: suggestionURL) {
                let isSeedCollision = suggestionData.range(of: Data("7400.DYNAMIC".utf8)) != nil
                    || suggestionData.range(of: Data("327BA8A0-00D9-445D-A8AB-7E64CED0914E".utf8)) != nil
                let isExtensionMismatch = extensionBundleID.caseInsensitiveCompare("com.apple.WallpaperKit.CollectionsPoster") != .orderedSame
                    && suggestionData.range(of: Data("com.apple.WallpaperKit.CollectionsPoster".utf8)) != nil
                if isSeedCollision || isExtensionMismatch {
                    try? fm.removeItem(at: suggestionURL)
                }
            }
        }

        for verDir in numericVersionDirectories(in: descriptorDir) {
            if isCollections {
                let suppDir = verDir.appendingPathComponent("supplements/0", isDirectory: true)
                seedFileIfMissing("homescreenConfiguration.plist", to: suppDir.appendingPathComponent("com.apple.posterkit.provider.supplementURL.homescreenConfiguration.plist"))
                seedFileIfMissing("RuntimeSnapshotMetadata-home.plist", to: verDir.appendingPathComponent("RuntimeSnapshotMetadata-home.plist"))
                seedFileIfMissing("RuntimeSnapshotMetadata-lock.plist", to: verDir.appendingPathComponent("RuntimeSnapshotMetadata-lock.plist"))
                seedFileIfMissing("complicationLayout.plist", to: verDir.appendingPathComponent("com.apple.posterkit.provider.instance.complicationLayout.plist"))
                seedFileIfMissing("titleStyleConfiguration.plist", to: verDir.appendingPathComponent("com.apple.posterkit.provider.instance.titleStyleConfiguration.plist"))

                let contentsDir = verDir.appendingPathComponent("contents", isDirectory: true)
                if fm.fileExists(atPath: contentsDir.path) {
                    seedFileIfMissing("configurableOptions.plist", to: contentsDir.appendingPathComponent(".com.apple.posterkit.provider.contents.configurableOptions.plist"))
                    seedFileIfMissing("otherMetadata.plist", to: contentsDir.appendingPathComponent("com.apple.posterkit.provider.contents.otherMetadata.plist"))
                }

                // Purge foreign (e.g. iPad/older-device) `.atx` snapshots so PosterBoard renders native device previews.
                if let snapEnum = fm.enumerator(at: verDir, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
                    for case let fileURL as URL in snapEnum where fileURL.pathExtension.lowercased() == "atx" {
                        try? fm.removeItem(at: fileURL)
                    }
                }
            } else if isMercury {
                let suppDir = verDir.appendingPathComponent("supplements/0", isDirectory: true)
                seedFileIfMissing("homescreenConfiguration.plist", to: suppDir.appendingPathComponent("com.apple.posterkit.provider.supplementURL.homescreenConfiguration.plist"))
            }

            let wwdcPlist = verDir
                .appendingPathComponent("contents/7400.WWDC_2022-390w-844h@3x~iphone.wallpaper/Wallpaper.plist")
            if fm.fileExists(atPath: wwdcPlist.path) {
                updatePlist(at: wwdcPlist) { dict in
                    if var assets = dict["assets"] as? [String: Any],
                       var lockAndHome = assets["lockAndHome"] as? [String: Any] {
                        var mutated = false
                        if var def = lockAndHome["default"] as? [String: Any],
                           let bgFile = def["backgroundAnimationFileName"] as? String,
                           bgFile.hasPrefix("7400.") {
                            def["identifier"] = 7400
                            lockAndHome["default"] = def
                            mutated = true
                        }
                        if var dark = lockAndHome["dark"] as? [String: Any],
                           let darkBG = dark["backgroundAnimationFileName"] as? String,
                           darkBG.hasPrefix("7401.") {
                            dark["identifier"] = 7401
                            lockAndHome["dark"] = dark
                            mutated = true
                        }
                        if mutated {
                            assets["lockAndHome"] = lockAndHome
                            dict["assets"] = assets
                        }
                    }
                }
            }
        }

        // Remove hardware productTypes restrictions anywhere inside the descriptor and heal non-motion `logicalScreenClass == "any"`.
        if isCollections,
           let enumerator = fm.enumerator(at: descriptorDir, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "Wallpaper.plist" {
                updatePlist(at: fileURL) { dict in
                    dict.removeValue(forKey: "productTypes")
                    let isMotion = (dict["wantsDeviceMotion"] as? Bool) == true
                    let isMarble = (dict["family"] as? String) == "Marble"
                    if !isMotion && !isMarble,
                       (dict["logicalScreenClass"] as? String) == "any" {
                        let parentName = fileURL.deletingLastPathComponent().lastPathComponent
                        dict["logicalScreenClass"] = parentName.localizedCaseInsensitiveContains("~ipad")
                            ? "810w-1080h@2x~ipad"
                            : "390w-844h@3x~iphone"
                    }
                }
            }
        }

        // Heal legacy Camlo ParameterizedCA (3D Gyroscope) descriptors whose `<wallpaperPropertyGroups>` was left empty.
        if let camlEnumerator = fm.enumerator(at: descriptorDir, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for case let fileURL as URL in camlEnumerator where fileURL.lastPathComponent == "main.caml" {
                healParameterizedCAMLIfNeeded(at: fileURL)
            }
        }
    }

    nonisolated static func healParameterizedCAMLIfNeeded(at camlURL: URL) {
        guard var xml = try? String(contentsOf: camlURL, encoding: .utf8) else {
            return
        }

        if xml.contains("<wallpapers") && xml.contains("BACKGROUND_INNER") {
            let rootTagPattern = "<CALayer\\b[^>]*\\bid=\"__capRootLayer__\"[^>]*>"
            let boundsAttrPattern = "\\bbounds=\"0\\s+0\\s+([0-9]+(?:\\.[0-9]+)?)\\s+([0-9]+(?:\\.[0-9]+)?)\""
            guard let rootTagRegex = try? NSRegularExpression(pattern: rootTagPattern),
                  let rootTagMatch = rootTagRegex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                  let tagRange = Range(rootTagMatch.range, in: xml),
                  let boundsRegex = try? NSRegularExpression(pattern: boundsAttrPattern) else {
                return
            }
            let rootTag = String(xml[tagRange])
            guard let boundsMatch = boundsRegex.firstMatch(in: rootTag, range: NSRange(rootTag.startIndex..., in: rootTag)),
                  boundsMatch.numberOfRanges >= 3,
                  let wRange = Range(boundsMatch.range(at: 1), in: rootTag),
                  let hRange = Range(boundsMatch.range(at: 2), in: rootTag),
                  let rootW = Double(rootTag[wRange]),
                  let rootH = Double(rootTag[hRange]),
                  rootW > 0, rootW < 1000 else {
                return
            }

            var duoMutated = false
            if xml.contains("<CATransformLayer ") {
                xml = xml
                    .replacingOccurrences(of: "<CATransformLayer ", with: "<CALayer ")
                    .replacingOccurrences(of: "</CATransformLayer>", with: "</CALayer>")
                duoMutated = true
            }

            if let multRegex = try? NSRegularExpression(
                pattern: "<retinaMultiplier\\s+type=\"(integer|real)\"\\s+value=\"(?:3|3\\.0+)\"\\s*/>"
            ) {
                let nsXML = xml as NSString
                let replaced = multRegex.stringByReplacingMatches(
                    in: xml,
                    range: NSRange(location: 0, length: nsXML.length),
                    withTemplate: "<retinaMultiplier type=\"integer\" value=\"1\"/>"
                )
                if replaced != xml {
                    xml = replaced
                    duoMutated = true
                }
            }

            func formatCenterCoord(_ v: Double) -> String {
                if abs(v - v.rounded()) < 0.0001 {
                    return String(Int(v.rounded()))
                }
                return String(format: "%.1f", v)
            }
            let rootCenterStr = "\(formatCenterCoord(rootW * 0.5)) \(formatCenterCoord(rootH * 0.5))"

            if let innerTagRegex = try? NSRegularExpression(
                pattern: "<CALayer\\b[^>]*\\b(?:name=\"(?:BACKGROUND_INNER|FLOATING_INNER)\"|id=\"(?:background_inner|floating_inner)\")[^>]*>"
            ),
               let posAttrRegex = try? NSRegularExpression(pattern: "\\bposition=\"[^\"]+\"") {
                let nsXML = xml as NSString
                let tagMatches = innerTagRegex.matches(in: xml, range: NSRange(location: 0, length: nsXML.length))
                let targetPosAttr = "position=\"\(rootCenterStr)\""
                var mutableXML = xml as NSString
                for match in tagMatches.reversed() {
                    let tagStr = mutableXML.substring(with: match.range)
                    let updatedTag = posAttrRegex.stringByReplacingMatches(
                        in: tagStr,
                        range: NSRange(location: 0, length: (tagStr as NSString).length),
                        withTemplate: targetPosAttr
                    )
                    if updatedTag != tagStr {
                        mutableXML = mutableXML.replacingCharacters(in: match.range, with: updatedTag) as NSString
                        duoMutated = true
                    }
                }
                xml = mutableXML as String
            }

            if duoMutated {
                try? xml.data(using: .utf8)?.write(to: camlURL, options: .atomic)
            }
            return
        }

        guard xml.contains("id=\"camlo_bg_parallax\""),
              !xml.contains("<wallpapers") else {
            return
        }

        var mutated = false
        if xml.contains("<CATransformLayer ") {
            xml = xml
                .replacingOccurrences(of: "<CATransformLayer ", with: "<CALayer ")
                .replacingOccurrences(of: "</CATransformLayer>", with: "</CALayer>")
            mutated = true
        }

        if xml.contains("<wallpaperPropertyGroups type=\"NSArray\"/>"),
           xml.contains("<LKState "),
           let floatingRange = xml.range(of: "<CALayer id=\"floating\"") {
            let statesStart = xml.range(of: "<states>")?.lowerBound ?? xml.endIndex
            let bgSection = String(xml[..<floatingRange.lowerBound])
            let flSection = String(xml[floatingRange.lowerBound..<min(statesStart, xml.endIndex)])

            let containerIDs: Set<String> = [
                "__capRootLayer__",
                "background",
                "floating",
                "camlo_bg_parallax",
                "camlo_bg_overscan",
                "camlo_fg_parallax",
                "camlo_fg_overscan",
                "camlo_fx_parallax"
            ]

            var layerMeta: [String: (name: String, view: String)] = [:]
            if let layerRegex = try? NSRegularExpression(
                pattern: "<CA[A-Za-z]*Layer\\b[^>]*\\bid=\"([^\"]+)\"[^>]*\\bname=\"([^\"]+)\""
            ) {
                for (section, viewName) in [(bgSection, "Background"), (flSection, "Floating")] {
                    let nsSection = section as NSString
                    let matches = layerRegex.matches(
                        in: section,
                        range: NSRange(location: 0, length: nsSection.length)
                    )
                    for match in matches where match.numberOfRanges >= 3 {
                        let id = nsSection.substring(with: match.range(at: 1))
                        let name = nsSection.substring(with: match.range(at: 2))
                        guard !containerIDs.contains(id) else { continue }
                        layerMeta[id] = (name: name, view: viewName)
                    }
                }
            }

            struct LegacyTriple {
                let targetId: String
                let keyPath: String
                var sleepVal: Double?
                var lockedVal: Double?
                var unlockVal: Double?
            }

            var orderedKeys: [String] = []
            var triples: [String: LegacyTriple] = [:]

            if let stateRegex = try? NSRegularExpression(
                pattern: "<LKState\\s+name=\"(Sleep|Locked|Unlock)\">([\\s\\S]*?)</LKState>"
            ),
               let setValueRegex = try? NSRegularExpression(
                   pattern: "<LKStateSetValue\\s+targetId=\"([^\"]+)\"\\s+keyPath=\"([^\"]+)\">\\s*<value\\s+type=\"[^\"]+\"\\s+value=\"([^\"]+)\"/>\\s*</LKStateSetValue>"
               ) {
                let nsXML = xml as NSString
                let stateMatches = stateRegex.matches(
                    in: xml,
                    range: NSRange(location: 0, length: nsXML.length)
                )
                for sMatch in stateMatches where sMatch.numberOfRanges >= 3 {
                    let stateName = nsXML.substring(with: sMatch.range(at: 1))
                    let body = nsXML.substring(with: sMatch.range(at: 2))
                    let nsBody = body as NSString
                    let valMatches = setValueRegex.matches(
                        in: body,
                        range: NSRange(location: 0, length: nsBody.length)
                    )
                    for vMatch in valMatches where vMatch.numberOfRanges >= 4 {
                        let targetId = nsBody.substring(with: vMatch.range(at: 1))
                        let keyPath = nsBody.substring(with: vMatch.range(at: 2))
                        let rawVal = nsBody.substring(with: vMatch.range(at: 3))
                        guard let numVal = Double(rawVal) else { continue }

                        let compoundKey = "\(targetId)|\(keyPath)"
                        if triples[compoundKey] == nil {
                            orderedKeys.append(compoundKey)
                            triples[compoundKey] = LegacyTriple(
                                targetId: targetId,
                                keyPath: keyPath,
                                sleepVal: nil,
                                lockedVal: nil,
                                unlockVal: nil
                            )
                        }
                        switch stateName {
                        case "Sleep":
                            triples[compoundKey]?.sleepVal = numVal
                        case "Locked":
                            triples[compoundKey]?.lockedVal = numVal
                        case "Unlock":
                            triples[compoundKey]?.unlockVal = numVal
                        default:
                            break
                        }
                    }
                }
            }

            func makeEntry(
                keyPath: String,
                layerName: String,
                sleepVal: Double,
                lockVal: Double,
                homeVal: Double,
                view: String
            ) -> String {
                let h = String(format: "%.4f", homeVal)
                let l = String(format: "%.4f", lockVal)
                let s = String(format: "%.4f", sleepVal)
                return """
                        <NSDictionary>
                          <image type="null"/>
                          <keyPath type="string" value="\(keyPath)"/>
                          <layerName type="string" value="\(layerName)"/>
                          <v_home type="real" value="\(h)"/>
                          <v_lock type="real" value="\(l)"/>
                          <v_sleep type="real" value="\(s)"/>
                          <view type="string" value="\(view)"/>
                        </NSDictionary>
                """
            }

            var groupEntries: [String] = []
            for key in orderedKeys {
                guard let triple = triples[key],
                      let meta = layerMeta[triple.targetId] else { continue }
                var locked = triple.lockedVal ?? 0.0
                let sleep = triple.sleepVal ?? locked
                let unlock = triple.unlockVal ?? locked
                if triple.targetId == "unlock_layer" && triple.keyPath == "opacity" && locked == 0.0 && unlock == 1.0 {
                    locked = 1.0
                }

                if triple.keyPath == "transform.scale.xy" {
                    let s = max(0.0, sleep)
                    let l = max(0.0, locked)
                    let h = max(0.0, unlock)
                    groupEntries.append(makeEntry(keyPath: "transform.scale.x", layerName: meta.name, sleepVal: s, lockVal: l, homeVal: h, view: meta.view))
                    groupEntries.append(makeEntry(keyPath: "transform.scale.y", layerName: meta.name, sleepVal: s, lockVal: l, homeVal: h, view: meta.view))
                } else {
                    groupEntries.append(makeEntry(keyPath: triple.keyPath, layerName: meta.name, sleepVal: sleep, lockVal: locked, homeVal: unlock, view: meta.view))
                }
            }

            if !groupEntries.isEmpty {
                let replacement = """
                      <wallpaperPropertyGroups type="NSArray">
                \(groupEntries.joined(separator: "\n"))
                      </wallpaperPropertyGroups>
                """
                xml = xml.replacingOccurrences(of: "      <wallpaperPropertyGroups type=\"NSArray\"/>", with: replacement)
                if xml.contains("<wallpaperPropertyGroups type=\"NSArray\"/>") {
                    xml = xml.replacingOccurrences(of: "<wallpaperPropertyGroups type=\"NSArray\"/>", with: replacement.trimmingCharacters(in: .whitespaces))
                }
                mutated = true
            }
        }

        if mutated {
            try? xml.data(using: .utf8)?.write(to: camlURL, options: .atomic)
        }
    }

    nonisolated static func synchronizeCollectionsIdentifier(
        in descriptorDir: URL,
        explicitID: Int? = nil,
        extensionBundleID: String = PBExtensionTarget.wpKit.extensionIdentifier
    ) {
        normalizeDescriptorForCurrentOS(in: descriptorDir, extensionBundleID: extensionBundleID)
        let fm = FileManager.default
        let wpID = explicitID ?? Int.random(in: 12000...98999)

        // Ensure descriptor identifier exists even if the imported pack omitted it.
        let descrIdURL = descriptorDir.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier")
        if !fm.fileExists(atPath: descrIdURL.path) {
            try? String(wpID).data(using: .utf8)?.write(to: descrIdURL, options: .atomic)
        }

        // Pre-scan any multi-item `WallpaperCollection.plist` so nested Wallpaper.plist IDs stay aligned with `order`.
        var collectionOrderMap: [Int: Int] = [:]
        if let colEnum = fm.enumerator(at: descriptorDir, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for case let fileURL as URL in colEnum where fileURL.lastPathComponent == "WallpaperCollection.plist" {
                if let data = fm.contents(atPath: fileURL.path),
                   let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
                   let order = dict["order"] as? [Int],
                   order.count > 1 {
                    for (idx, oldID) in order.enumerated() where collectionOrderMap[oldID] == nil {
                        collectionOrderMap[oldID] = 100_000 + ((wpID % 8_000) * 100) + idx
                    }
                }
            }
        }

        // Crucial for iOS 26/27: leave options empty so enumeration descends into `.wallpaper` and `.wallpaperCollection`
        // opaque packages and updates `Wallpaper.plist` / `WallpaperCollection.plist`.
        guard let enumerator = fm.enumerator(
            at: descriptorDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else { return }

        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            switch fileURL.lastPathComponent {
            case "com.apple.posterkit.provider.descriptor.identifier":
                try? String(wpID).data(using: .utf8)?.write(to: fileURL, options: .atomic)
            case "com.apple.posterkit.provider.contents.userInfo":
                updatePlist(at: fileURL) { dict in
                    dict["wallpaperRepresentingIdentifier"] = wpID
                }
            case "Wallpaper.plist":
                // Top-level identifier & productTypes removal only; nested assets.*.identifier stays tied to `.ca` filenames.
                updatePlist(at: fileURL) { dict in
                    dict["identifier"] = (dict["identifier"] as? Int).flatMap { collectionOrderMap[$0] } ?? wpID
                    dict.removeValue(forKey: "productTypes")
                }
            case "WallpaperCollection.plist":
                updatePlist(at: fileURL) { dict in
                    if let order = dict["order"] as? [Int], order.count > 1 {
                        dict["order"] = order.map { collectionOrderMap[$0] ?? $0 }
                    } else if let order = dict["order"] as? [Any], order.count == 1 {
                        dict["order"] = [wpID]
                    }
                }
            default:
                continue
            }
        }
    }

    nonisolated static func galleryDestinationHint(for items: [TendiesVaultItem]) -> String {
        var labels: [String] = []
        let extIDs = items.flatMap(\.resolvedDescriptorEntries).map(\.extensionBundleID)
        for extID in extIDs {
            let label: String
            if extID.localizedCaseInsensitiveContains("CollectionsPoster") {
                label = Bi("「收藏」与「专为 iPhone 设计的墙纸」", "Collections & Designed for iPhone")
            } else if extID.localizedCaseInsensitiveContains("MercuryPoster") {
                label = Bi("「天文 / 水星流体」", "Astronomy / Mercury")
            } else if extID.localizedCaseInsensitiveContains("PhotosPoster") {
                label = Bi("「照片」（点左下角图库选片）", "Photos")
            } else {
                label = extID.components(separatedBy: ".").last ?? extID
            }
            if !labels.contains(label) {
                labels.append(label)
            }
        }
        return labels.isEmpty ? Bi("「收藏」", "Collections") : labels.joined(separator: " · ")
    }

    nonisolated private static func updatePlist(at url: URL, mutate: (inout [String: Any]) -> Void) {
        guard let data = FileManager.default.contents(atPath: url.path),
              var dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return
        }
        mutate(&dict)
        if let out = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) {
            try? out.write(to: url, options: .atomic)
        }
    }

    nonisolated private static func nextDescendingWallpaperID() -> Int {
        let defaults = UserDefaults.standard
        let current = defaults.object(forKey: nextDescendingIDKey) as? Int ?? 19999
        let allocated = (10100...19999).contains(current) ? current : 19999
        let next = allocated > 10100 ? (allocated - 1) : 19999
        defaults.set(next, forKey: nextDescendingIDKey)
        return allocated
    }

    private func purgeLegacyMarkerDescriptors(in descriptorsDir: URL) {
        guard fm.fileExists(atPath: descriptorsDir.path),
              WorseQueryBridge.shared.grantAccess(path: descriptorsDir.path).0,
              let children = try? fm.contentsOfDirectory(
                  at: descriptorsDir,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: .skipsHiddenFiles
              ) else { return }

        for child in children {
            if fm.fileExists(atPath: child.appendingPathComponent(Self.camloMarkerFilename).path) {
                try? fm.removeItem(at: child)
            }
        }
    }

    // MARK: - Direct Apply to PosterBoard

    func applyTendiesItems(_ items: [TendiesVaultItem], autoRefreshGalleryCache: Bool = true) -> (Bool, String) {
        guard !items.isEmpty else {
            return (false, Bi("请至少选择一个壁纸包", "Select at least one wallpaper package"))
        }

        let resolved = resolveContainerForDirectAction(
            emptyErrorMessage: Bi("尚未定位到 PosterBoard 容器路径，请先导出 .tendies 或前往「设备」页刷新容器权限。", "PosterBoard container path is empty. Export as .tendies or refresh container access in System tab.")
        )
        guard resolved.ok else {
            return (false, resolved.error)
        }

        let targetContainer = resolved.path
        let wq = WorseQueryBridge.shared
        let storeVer = PBExtensionTarget.resolveStoreVersion(in: targetContainer)
        let extensionsRoot = URL(fileURLWithPath: targetContainer)
            .appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/\(storeVer)/Extensions")
        _ = wq.grantAccess(path: extensionsRoot.path)

        let extIDs = Set(items.flatMap(\.resolvedDescriptorEntries).map(\.extensionBundleID))
        var resolvedTargetDirsByExtID: [String: [URL]] = [:]

        for extID in extIDs {
            let knownTarget = PBExtensionTarget.allCases.first { $0.extensionIdentifier == extID }
            let dirURL: URL
            if let knownTarget {
                let rel = knownTarget.resolvedDescriptorsRelPath(in: targetContainer)
                dirURL = URL(fileURLWithPath: targetContainer).appendingPathComponent(rel)
            } else {
                dirURL = extensionsRoot
                    .appendingPathComponent(extID)
                    .appendingPathComponent("descriptors")
            }

            do {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            } catch {
                return (false, error.localizedDescription)
            }
            let subGrant = wq.grantAccess(path: dirURL.path)
            if !subGrant.0 {
                return (false, subGrant.2)
            }
            var destList: [URL] = [dirURL]

            // On iOS 26.4+ / iOS 27, if PosterBoard has also created alternate CollectionsPoster* / MercuryPoster*
            // extension directories (e.g. com.apple.Posters.CollectionsPosterApp.*), mirror there too.
            if (knownTarget == .wpKit || knownTarget == .mercury),
               wq.grantAccess(path: extensionsRoot.path).0,
               let extFolders = try? fm.contentsOfDirectory(at: extensionsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
                let needle = knownTarget == .mercury ? "MercuryPoster" : "CollectionsPoster"
                for extFolder in extFolders {
                    let extName = extFolder.lastPathComponent
                    if extName != extID && extName.localizedCaseInsensitiveContains(needle) {
                        let altDescrDir = extFolder.appendingPathComponent("descriptors")
                        if (try? fm.createDirectory(at: altDescrDir, withIntermediateDirectories: true)) != nil,
                           wq.grantAccess(path: altDescrDir.path).0 {
                            destList.append(altDescrDir)
                        }
                    }
                }
            }

            // Auto-purge legacy `.camlo_origin` marker descriptors before injecting new ones
            if knownTarget == .wpKit {
                for dURL in destList {
                    purgeLegacyMarkerDescriptors(in: dURL)
                }
            }

            resolvedTargetDirsByExtID[extID] = destList
        }

        // Assign descending IDs (19999 -> 10100) so newly applied wallpapers sort near the front of Collections,
        // and reuse per-item descriptor UUIDs so re-applying updates in place without duplicating cards.
        var trackedNames = Set(UserDefaults.standard.stringArray(forKey: Self.trackedNamesDefaultsKey) ?? [])
        var itemDescrMap = UserDefaults.standard.dictionary(forKey: Self.itemDescriptorMapKey) as? [String: String] ?? [:]
        var appliedTitlesByUUID: [String: String] = [:]

        for item in items {
            let pkgDir = CamloPaths.packagesDir.appendingPathComponent(item.storageFolderName)
            let entries = item.resolvedDescriptorEntries

            for (dIdx, entry) in entries.enumerated() {
                guard let destContainers = resolvedTargetDirsByExtID[entry.extensionBundleID], !destContainers.isEmpty else {
                    continue
                }
                let srcDescr = pkgDir.appendingPathComponent(entry.folderName)
                guard fm.fileExists(atPath: srcDescr.path) else { continue }

                let isCollections = entry.extensionBundleID.localizedCaseInsensitiveContains("CollectionsPoster")
                let shouldPreserveIdentity = !isCollections && (entry.preserveIdentity || entry.extensionBundleID.localizedCaseInsensitiveContains("MercuryPoster"))

                // Heal/normalize the vault copy in-place so future applies/exports stay clean
                Self.normalizeDescriptorForCurrentOS(in: srcDescr, extensionBundleID: entry.extensionBundleID)

                let mapKey = "\(item.id.uuidString)_\(dIdx)"
                let destName: String
                if shouldPreserveIdentity {
                    destName = srcDescr.lastPathComponent
                } else if let existing = itemDescrMap[mapKey], !existing.isEmpty {
                    destName = existing
                } else {
                    destName = UUID().uuidString.uppercased()
                }
                if !shouldPreserveIdentity {
                    itemDescrMap[mapKey] = destName
                }

                let assignedID = shouldPreserveIdentity ? 0 : Self.nextDescendingWallpaperID()

                for destContainer in destContainers {
                    let targetExtID = destContainer.deletingLastPathComponent().lastPathComponent
                    let destDescr = destContainer.appendingPathComponent(destName)
                    do {
                        if fm.fileExists(atPath: destDescr.path) {
                            try fm.removeItem(at: destDescr)
                        }
                        try fm.copyItem(at: srcDescr, to: destDescr)
                        // Ensure no foreign marker file exists inside PosterBoard's descriptor folder
                        Self.sanitizeDescriptorTree(at: destDescr)
                        if isCollections {
                            Self.synchronizeCollectionsIdentifier(
                                in: destDescr,
                                explicitID: assignedID,
                                extensionBundleID: targetExtID
                            )
                        }
                        trackedNames.insert(destName)
                        appliedTitlesByUUID[destName] = item.title
                    } catch {
                        return (false, error.localizedDescription)
                    }
                }
            }
        }

        Self.recordDescriptorTitles(appliedTitlesByUUID)
        UserDefaults.standard.set(Array(trackedNames), forKey: Self.trackedNamesDefaultsKey)
        UserDefaults.standard.set(itemDescrMap, forKey: Self.itemDescriptorMapKey)

        if autoRefreshGalleryCache {
            _ = refreshGalleryCacheNonDestructive()
        }

        return (true, "")
    }

    // MARK: - Maintenance & Cache Controls

    /// Clears only PosterBoard's transient GalleryCache and writes iOS 26.4+ / iOS 27 persistence & refresh keys.
    func refreshGalleryCacheNonDestructive() -> (Bool, String) {
        let resolved = resolveContainerForDirectAction(
            emptyErrorMessage: Bi("未找到 PosterBoard 容器路径", "PosterBoard container path not set")
        )
        guard resolved.ok else {
            return (false, resolved.error)
        }

        let targetContainer = resolved.path
        let wq = WorseQueryBridge.shared
        let ver = PBExtensionTarget.resolveStoreVersion(in: targetContainer)
        let extRoot = URL(fileURLWithPath: targetContainer)
            .appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/\(ver)/Extensions")
        var descrDirs: [URL] = [
            URL(fileURLWithPath: targetContainer).appendingPathComponent(PBExtensionTarget.wpKit.resolvedDescriptorsRelPath(in: targetContainer))
        ]
        if wq.grantAccess(path: extRoot.path).0,
           let allExts = try? fm.contentsOfDirectory(at: extRoot, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for e in allExts where e.lastPathComponent.localizedCaseInsensitiveContains("CollectionsPoster") {
                let d = e.appendingPathComponent("descriptors")
                if !descrDirs.contains(d) {
                    descrDirs.append(d)
                }
            }
        }
        for d in descrDirs {
            purgeLegacyMarkerDescriptors(in: d)
        }

        let galleryCacheURL = URL(fileURLWithPath: targetContainer)
            .appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/\(ver)/GalleryCache")
        if fm.fileExists(atPath: galleryCacheURL.path) {
            _ = wq.grantAccess(path: galleryCacheURL.path)
            if let items = try? fm.contentsOfDirectory(at: galleryCacheURL, includingPropertiesForKeys: nil) {
                for u in items { try? fm.removeItem(at: u) }
            }
        }

        // Write unprotected refresh + iOS 26.4+ / iOS 27 CollectionsPosterApp persistence keys
        let prefsDir = URL(fileURLWithPath: targetContainer).appendingPathComponent("Library/Preferences")
        try? fm.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: prefsDir.path) {
            _ = wq.grantAccess(path: prefsDir.path)
            let prefsFile = prefsDir.appendingPathComponent("com.apple.PosterBoard.unprotectedUserDefaults.plist")
            if fm.fileExists(atPath: prefsFile.path) {
                _ = wq.grantAccess(path: prefsFile.path)
            }
            var dict: [String: Any] = [:]
            if let existing = fm.contents(atPath: prefsFile.path),
               let parsed = (try? PropertyListSerialization.propertyList(from: existing, options: [], format: nil)) as? [String: Any] {
                dict = parsed
            }
            dict["PBF_LOCALE_DID_CHANGE"] = false
            dict["PBF_RESET_FILE_PROTECTIONS"] = true

            if ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0)) {
                var persisted = (dict["PersistedPosterContainerBundleIdentifiers"] as? [String]) ?? []
                if !persisted.contains("com.apple.Posters.CollectionsPosterApp") {
                    persisted.append("com.apple.Posters.CollectionsPosterApp")
                }
                dict["PersistedPosterContainerBundleIdentifiers"] = persisted

                let requiredMigrations = [
                    "com.apple.Posters.UnityPosterApp.ExtragalacticPoster",
                    "com.apple.Posters.WeatherPosterApp.WeatherPoster",
                    "com.apple.Posters.UnityPosterApp.Unity2025Poster",
                    "com.apple.Posters.UnityPosterApp.UnityPosterExtension",
                    "com.apple.Posters.UnityPosterApp.RhizomePoster",
                    "com.apple.Posters.KaleidoscopePosterApp.KaleidoscopePoster"
                ]
                var migrations = (dict["CompletedPosterBundleIdentifierMigrations"] as? [String]) ?? []
                for m in requiredMigrations where !migrations.contains(m) {
                    migrations.append(m)
                }
                dict["CompletedPosterBundleIdentifierMigrations"] = migrations
            }

            if let out = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) {
                try? out.write(to: prefsFile, options: .atomic)
            }
        }

        return (true, Bi("已刷新锁屏画廊缓存并写入 iOS 27 持久化键，请注销桌面或在后台上滑关闭 PosterBoard 后生效", "Gallery cache & iOS 27 persistence flags refreshed. Respring or force-close PosterBoard to reload."))
    }

    /// Removes only descriptors injected by Camlo (tracked in UserDefaults or legacy `.camlo_origin`), leaving system/other wallpapers intact.
    func removeCamloInjectedDescriptorsOnly() -> (Int, String?) {
        guard !containerPath.isEmpty else {
            return (0, Bi("未找到 PosterBoard 容器路径", "PosterBoard container path not set"))
        }
        let wq = WorseQueryBridge.shared
        guard wq.grantAccess(path: containerPath).0 else {
            return (0, Bi("无法获取 PosterBoard 容器读写权限", "Cannot grant PosterBoard container write access"))
        }

        let trackedNames = Set(UserDefaults.standard.stringArray(forKey: Self.trackedNamesDefaultsKey) ?? [])
        var removedCount = 0
        let ver = PBExtensionTarget.resolveStoreVersion(in: containerPath)
        let extRoot = URL(fileURLWithPath: containerPath)
            .appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/\(ver)/Extensions")

        var candidateDescrDirs: [URL] = PBExtensionTarget.allCases.map {
            URL(fileURLWithPath: containerPath).appendingPathComponent($0.resolvedDescriptorsRelPath(in: containerPath))
        }
        if wq.grantAccess(path: extRoot.path).0,
           let allExts = try? fm.contentsOfDirectory(at: extRoot, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for e in allExts where e.lastPathComponent.localizedCaseInsensitiveContains("CollectionsPoster")
                || e.lastPathComponent.localizedCaseInsensitiveContains("MercuryPoster") {
                let d = e.appendingPathComponent("descriptors")
                if !candidateDescrDirs.contains(d) {
                    candidateDescrDirs.append(d)
                }
            }
        }

        for dir in candidateDescrDirs {
            guard fm.fileExists(atPath: dir.path), wq.grantAccess(path: dir.path).0,
                  let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for child in children {
                let marker = child.appendingPathComponent(Self.camloMarkerFilename)
                if trackedNames.contains(child.lastPathComponent) || fm.fileExists(atPath: marker.path) {
                    if (try? fm.removeItem(at: child)) != nil {
                        removedCount += 1
                    }
                }
            }
        }
        UserDefaults.standard.removeObject(forKey: Self.trackedNamesDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.itemDescriptorMapKey)
        UserDefaults.standard.removeObject(forKey: Self.nextDescendingIDKey)
        UserDefaults.standard.removeObject(forKey: Self.uuidTitlesDefaultsKey)
        _ = refreshGalleryCacheNonDestructive()
        return (removedCount, nil)
    }

    func triggerRespring() {
        respringWatchdogTask?.cancel()
        respringWatchdogTask = nil

        Task { @MainActor in
            // Allow SwiftUI .alert dismissal transition (~0.25s) to finish restoring keyWindow
            try? await Task.sleep(nanoseconds: 260_000_000)

            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

            for scene in scenes {
                if let keyWin = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
                   let rootVC = keyWin.rootViewController {
                    if let presented = rootVC.presentedViewController, !presented.isBeingDismissed {
                        rootVC.dismiss(animated: false)
                    }
                    for _ in 0..<12 {
                        if rootVC.presentedViewController == nil &&
                           rootVC.transitionCoordinator == nil &&
                           !rootVC.isBeingDismissed {
                            break
                        }
                        try? await Task.sleep(nanoseconds: 40_000_000)
                    }
                    keyWin.makeKeyAndVisible()
                }
            }

            URLCache.shared.removeAllCachedResponses()
            let nonce = UUID()
            self.respringNonce = nonce

            self.respringWatchdogTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 6_500_000_000)
                guard !Task.isCancelled, self.respringNonce == nonce else { return }
                self.respringNonce = nil
                CamloShare.openPosterBoardApp()
            }
        }
    }

    func resetExtensionDescriptors(for target: PBExtensionTarget) -> (Bool, String) {
        guard !containerPath.isEmpty else {
            return (false, Bi("未找到 PosterBoard 容器路径", "PosterBoard container path not set"))
        }
        let wq = WorseQueryBridge.shared
        let rootGrant = wq.grantAccess(path: containerPath)
        guard rootGrant.0 else { return (false, rootGrant.2) }

        let dir = URL(fileURLWithPath: containerPath).appendingPathComponent(target.resolvedDescriptorsRelPath(in: containerPath))
        guard fm.fileExists(atPath: dir.path) else { return (true, "") }
        let subGrant = wq.grantAccess(path: dir.path)
        guard subGrant.0 else { return (false, subGrant.2) }

        do {
            let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            for url in contents {
                try fm.removeItem(at: url)
            }
            _ = refreshGalleryCacheNonDestructive()
            return (true, "")
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
