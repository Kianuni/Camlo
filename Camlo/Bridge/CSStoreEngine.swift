//
//  CSStoreEngine.swift
//  Camlo · 开幕
//
//  Fast LaunchServices CSStore2 ("bdsl") + pathleak fallback for locating com.apple.PosterBoard.
//

import Foundation

final class CSStoreEngine: @unchecked Sendable {
    static let shared = CSStoreEngine()

    private let fm = FileManager.default
    private let stateLock = NSLock()
    private let cachedStorePathKey = "camlo_csstore_path_v1"
    private var appContainersMap: [String: String]?
    private var salvagedAppPaths: [String] = []
    private var lastStatSig: String = ""
    private var didMissInSession = false

    private init() {}

    static func normalizeVarPath(_ rawPath: String) -> String {
        var p = (rawPath as NSString).standardizingPath
        if p.hasPrefix("/private/var/") {
            p = String(p.dropFirst(8))
        }
        return p
    }

    static func canonicalPrivatePath(_ rawPath: String) -> String {
        let p = (rawPath as NSString).standardizingPath
        if p == "/var" {
            return "/private/var"
        }
        if p.hasPrefix("/var/") {
            return "/private" + p
        }
        return p
    }

    func invalidate() {
        stateLock.lock()
        appContainersMap = nil
        salvagedAppPaths = []
        lastStatSig = ""
        didMissInSession = false
        stateLock.unlock()
    }

    private func probeMaxInode() -> UInt64 {
        let probeURL = fm.temporaryDirectory.appendingPathComponent(".camlo_probe_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: probeURL) }
        do {
            try "1".write(to: probeURL, atomically: true, encoding: .utf8)
            var st = stat()
            if stat(probeURL.path, &st) == 0, st.st_ino > 0 {
                return st.st_ino + 4096
            }
        } catch {}
        return 20_000_000
    }

    private func statSignature(at path: String) -> (sig: String, size: Int64)? {
        var st = stat()
        guard stat(path, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG else { return nil }
        let sig = "\(st.st_dev):\(st.st_ino):\(st.st_size):\(st.st_mtimespec.tv_sec):\(st.st_mtimespec.tv_nsec)"
        return (sig, st.st_size)
    }

    private func pickNewestStore(inCachesDir cachesDir: String) -> String? {
        guard let entries = try? fm.contentsOfDirectory(atPath: cachesDir) else { return nil }
        var bestPath: String?
        var bestSec: Int = -1
        var bestNsec: Int = -1
        for name in entries where name.hasPrefix("com.apple.LaunchServices-") && name.hasSuffix(".csstore") {
            let full = (cachesDir as NSString).appendingPathComponent(name)
            var st = stat()
            guard stat(full, &st) == 0,
                  (st.st_mode & S_IFMT) == S_IFREG,
                  st.st_size >= 0x1000,
                  st.st_size <= 64 * 1024 * 1024 else { continue }
            if st.st_mtimespec.tv_sec > bestSec ||
                (st.st_mtimespec.tv_sec == bestSec && st.st_mtimespec.tv_nsec > bestNsec) {
                bestSec = st.st_mtimespec.tv_sec
                bestNsec = st.st_mtimespec.tv_nsec
                bestPath = full
            }
        }
        return bestPath
    }

    private static func isHexASCII(_ b: UInt8) -> Bool {
        (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x46) || (b >= 0x61 && b <= 0x66)
    }

    private static func parseUUID36(_ ptr: UnsafePointer<UInt8>) -> String? {
        for idx in 0..<36 {
            let b = ptr[idx]
            if idx == 8 || idx == 13 || idx == 18 || idx == 23 {
                if b != 0x2D { return nil }
            } else if !isHexASCII(b) {
                return nil
            }
        }
        var upper = [UInt8](repeating: 0, count: 36)
        for idx in 0..<36 {
            let b = ptr[idx]
            upper[idx] = (b >= 0x61 && b <= 0x66) ? (b - 32) : b
        }
        return String(bytes: upper, encoding: .ascii)
    }

    private static func salvageAppUUIDPaths(_ data: Data) -> [String] {
        var apps = Set<String>()
        let slashApp = Array("/Containers/Data/Application/".utf8)
        let tlvData: [UInt8] = [0x04, 0, 0, 0, 1, 1, 0, 0, 0x44, 0x61, 0x74, 0x61]
        let tlvApp: [UInt8] = tlvData + [0x0b, 0, 0, 0, 1, 1, 0, 0, 0x41, 0x70, 0x70, 0x6c, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x00, 0x24, 0, 0, 0, 1, 1, 0, 0]

        data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.bindMemory(to: UInt8.self).baseAddress else { return }
            let n = rawBuf.count
            guard n > 96 else { return }
            func matches(_ offset: Int, _ pattern: [UInt8]) -> Bool {
                guard offset + pattern.count + 36 <= n else { return false }
                return memcmp(base.advanced(by: offset), pattern, pattern.count) == 0
            }
            var i = 0
            let limit = n - 64
            while i <= limit {
                let b = base[i]
                if b == 0x2F && base[i + 1] == 0x43, matches(i, slashApp),
                   let u = parseUUID36(base.advanced(by: i + slashApp.count)) {
                    apps.insert("/var/mobile/Containers/Data/Application/" + u)
                    i += slashApp.count + 36
                    continue
                } else if b == 0x04 && base[i + 4] == 1 && base[i + 5] == 1, matches(i, tlvApp),
                          let u = parseUUID36(base.advanced(by: i + tlvApp.count)) {
                    apps.insert("/var/mobile/Containers/Data/Application/" + u)
                    i += tlvApp.count + 36
                    continue
                }
                i += 1
            }
        }
        return Array(apps)
    }

    private func parseStoreFile(at storePath: String) -> Bool {
        guard let before = statSignature(at: storePath),
              before.size >= 0x1000,
              before.size <= 64 * 1024 * 1024,
              let data = try? Data(contentsOf: URL(fileURLWithPath: storePath)),
              let after = statSignature(at: storePath),
              before.sig == after.sig else {
            return false
        }

        let salvaged = Self.salvageAppUUIDPaths(data)
        if let raw = csstore_parse_data(data),
           let rawApps = raw["appContainers"] as? [String: String],
           !rawApps.isEmpty {
            appContainersMap = rawApps
            salvagedAppPaths = salvaged
            lastStatSig = before.sig
            return true
        }

        if salvaged.count >= 2 {
            appContainersMap = nil
            salvagedAppPaths = salvaged
            lastStatSig = before.sig
            return true
        }
        return false
    }

    private func ensureSnapshotLoaded() {
        stateLock.lock()
        defer { stateLock.unlock() }

        if appContainersMap != nil || !salvagedAppPaths.isEmpty || didMissInSession {
            return
        }

        let wq = WorseQueryBridge.shared
        guard wq.hasUsableAppGroupContainer else { return }

        if let saved = UserDefaults.standard.string(forKey: cachedStorePathKey), !saved.isEmpty {
            let cachesDir = (saved as NSString).deletingLastPathComponent
            let libraryDir = (cachesDir as NSString).deletingLastPathComponent
            let containerRoot = libraryDir.hasSuffix("/Library") ? (libraryDir as NSString).deletingLastPathComponent : ""
            var tempGrants: [String] = []
            func tryGrant(_ p: String) -> Bool {
                guard !p.isEmpty else { return false }
                if fm.isReadableFile(atPath: p) || wq.hasActiveAccess(path: p) { return true }
                if wq.grantAccess(path: p, requireWrite: false).0 {
                    tempGrants.append(p)
                    return true
                }
                return false
            }
            if tryGrant(cachesDir) || tryGrant(containerRoot) {
                let target = pickNewestStore(inCachesDir: cachesDir) ?? saved
                if !fm.isReadableFile(atPath: target) { _ = tryGrant(target) }
                let ok = parseStoreFile(at: target)
                for g in tempGrants.reversed() { wq.releaseAccess(path: g) }
                if ok {
                    UserDefaults.standard.set(target, forKey: cachedStorePathKey)
                    return
                }
            } else {
                for g in tempGrants.reversed() { wq.releaseAccess(path: g) }
            }
        }

        let maxInode = probeMaxInode()
        let candidates = csstore_scan_latest_paths(maxInode)
        for discovered in candidates {
            let cachesDir = (discovered as NSString).deletingLastPathComponent
            let libraryDir = (cachesDir as NSString).deletingLastPathComponent
            let containerRoot = libraryDir.hasSuffix("/Library") ? (libraryDir as NSString).deletingLastPathComponent : ""
            var newlyGranted: [String] = []
            func ensure(_ p: String) -> Bool {
                guard !p.isEmpty else { return false }
                if fm.isReadableFile(atPath: p) || wq.hasActiveAccess(path: p) { return true }
                if wq.grantAccess(path: p, requireWrite: false).0 {
                    newlyGranted.append(p)
                    return true
                }
                return false
            }
            var granted = fm.isReadableFile(atPath: cachesDir) || wq.hasActiveAccess(path: cachesDir)
            if !granted && discovered.contains("/Containers/") {
                granted = ensure(cachesDir) || ensure(containerRoot)
            }
            let targetFile = granted ? (pickNewestStore(inCachesDir: cachesDir) ?? discovered) : discovered
            if !fm.isReadableFile(atPath: targetFile) && targetFile.contains("/Containers/") {
                _ = ensure(containerRoot)
                if !fm.isReadableFile(atPath: targetFile) { _ = ensure(targetFile) }
            }
            let ok = parseStoreFile(at: targetFile)
            for g in newlyGranted.reversed() { wq.releaseAccess(path: g) }
            if ok {
                UserDefaults.standard.set(targetFile, forKey: cachedStorePathKey)
                return
            }
        }
        didMissInSession = true
    }

    private func readBundleIDFromContainer(_ path: String) -> String? {
        let realDir = Self.canonicalPrivatePath(path)
        var buf = [CChar](repeating: 0, count: 512)
        var len = getxattr(realDir, "com.apple.containermanager.identifier", &buf, 511, 0, 0)
        if len > 0 {
            buf[min(len, buf.count - 1)] = 0
            let bid = String(cString: buf)
            if !bid.isEmpty { return bid }
        }

        let wq = WorseQueryBridge.shared
        let wasActive = wq.hasActiveAccess(path: realDir)
        guard wq.grantAccess(path: realDir, requireWrite: false).0 else { return nil }
        defer {
            if !wasActive { wq.releaseAccess(path: realDir) }
        }

        buf = [CChar](repeating: 0, count: 512)
        len = getxattr(realDir, "com.apple.containermanager.identifier", &buf, 511, 0, 0)
        if len > 0 {
            buf[min(len, buf.count - 1)] = 0
            let bid = String(cString: buf)
            if !bid.isEmpty { return bid }
        }

        let url = URL(fileURLWithPath: realDir)
        for metaName in [".com.apple.mobile_container_manager.metadata.plist", "com.apple.mobile_container_manager.metadata.plist"] {
            let metaURL = url.appendingPathComponent(metaName)
            if let data = try? Data(contentsOf: metaURL),
               let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
               let id = plist["MCMMetadataIdentifier"] as? String, !id.isEmpty {
                return id
            }
        }
        return nil
    }

    /// Resolves `/var/mobile/Containers/Data/Application/<UUID>` for `com.apple.PosterBoard`.
    func resolvePosterBoardContainerPath() -> String {
        let targetBID = "com.apple.PosterBoard"

        // 0. Instant MCM direct query when permitted (<2ms)
        if let mcmDirect = csstore_mcm_find_app_container(targetBID), !mcmDirect.isEmpty {
            return Self.normalizeVarPath(mcmDirect)
        }

        // 1. Direct CSStore2 bundleID map (<50ms)
        ensureSnapshotLoaded()
        stateLock.lock()
        let directHit = appContainersMap?.first(where: { $0.value.caseInsensitiveCompare(targetBID) == .orderedSame })?.key
        let salvaged = salvagedAppPaths
        stateLock.unlock()

        if let directHit, !directHit.isEmpty {
            return directHit
        }

        // 2. Check MCM / salvaged app container list via xattr / metadata plist
        var candidateDirs: [String] = []
        if let mcm = csstore_mcm_list_containers()?["/var/mobile/Containers/Data/Application"], mcm.count > 1 {
            candidateDirs = mcm
        } else if !salvaged.isEmpty {
            candidateDirs = salvaged
        } else {
            // 3. Fallback to bounded multi-threaded pathleak scan
            let maxInode = min(max(probeMaxInode() + 16_384, 2_000_000), 90_000_000)
            candidateDirs = pathleak("/var/mobile/Containers/Data/Application", maxInode) ?? []
        }

        for dir in candidateDirs {
            if let bid = readBundleIDFromContainer(dir),
               bid.caseInsensitiveCompare(targetBID) == .orderedSame {
                return Self.normalizeVarPath(dir)
            }
        }
        return ""
    }
}
