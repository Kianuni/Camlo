//
//  WorseQueryBridge.swift
//  Camlo · 开幕
//
//  Ported & hardened from Erosion-CN (GPL-3.0).
//

import Foundation
import Darwin
import MachO

final class WorseQueryBridge: @unchecked Sendable {
    static let shared = WorseQueryBridge()

    private let fm = FileManager.default
    private let handleLock = NSRecursiveLock()
    private let queryLock = NSLock()
    private var activeHandles: [String: Int64] = [:]
    private var handleOrder: [String] = []
    private let maxActiveHandles = 160
    private var preferredAltFlags: Bool? = nil
    private(set) var usableAppGroups: [String] = []
    private(set) var activeAppGroup: String = ""

    private init() {
        let detected = Self.detectAppGroups(fm: fm)
        self.usableAppGroups = detected.usable
        self.activeAppGroup = detected.primary
    }

    @discardableResult
    func refreshAppGroup() -> String {
        let detected = Self.detectAppGroups(fm: fm)
        queryLock.lock()
        usableAppGroups = detected.usable
        activeAppGroup = detected.primary
        queryLock.unlock()
        return detected.primary
    }

    var hasUsableAppGroupContainer: Bool {
        queryLock.lock()
        let groups = usableAppGroups
        let primary = activeAppGroup
        queryLock.unlock()
        if !groups.isEmpty { return true }
        guard !primary.isEmpty else { return false }
        return fm.containerURL(forSecurityApplicationGroupIdentifier: primary) != nil
    }

    private static func detectAppGroups(fm: FileManager) -> (usable: [String], primary: String) {
        let defaultGroup = "group.com.kianuni.Camlo.WQ"
        let legacyGroup = "group.com.jbdotparty.Erosion.WQ"
        var signedGroups: [String] = []

        if let task = SecTaskCreateFromSelf(nil),
           let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil),
           let groups = value as? [String], !groups.isEmpty {
            signedGroups = groups
        } else if let fallbackGroups = readMachOAppGroups(), !fallbackGroups.isEmpty {
            signedGroups = fallbackGroups
        }

        var candidates: [String] = []
        let bundleGroup = "group." + (Bundle.main.bundleIdentifier ?? "")
        for preferred in [bundleGroup, defaultGroup, legacyGroup] {
            if signedGroups.contains(preferred) && !candidates.contains(preferred) {
                candidates.append(preferred)
            }
        }
        for item in signedGroups where item.hasPrefix("group.") && !candidates.contains(item) {
            candidates.append(item)
        }

        let usable = candidates.filter { fm.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
        return (usable, usable.first ?? candidates.first ?? defaultGroup)
    }

    // MARK: - Mach-O Embedded Entitlements Fallback (for SideStore / Feather / Sideloadly resigners)

    private static func inRange(_ offset: Int, _ length: Int, _ total: Int) -> Bool {
        offset >= 0 && length >= 0 && offset <= total && length <= total - offset
    }

    private static func readU32(_ buf: UnsafeRawBufferPointer, _ offset: Int) -> UInt32? {
        guard inRange(offset, 4, buf.count), let base = buf.baseAddress else { return nil }
        var value: UInt32 = 0
        memcpy(&value, base.advanced(by: offset), 4)
        return value
    }

    private static func readU64(_ buf: UnsafeRawBufferPointer, _ offset: Int) -> UInt64? {
        guard inRange(offset, 8, buf.count), let base = buf.baseAddress else { return nil }
        var value: UInt64 = 0
        memcpy(&value, base.advanced(by: offset), 8)
        return value
    }

    private static func parseCSBlob(_ buf: UnsafeRawBufferPointer) -> [String: Any]? {
        guard let magicBE = readU32(buf, 0), UInt32(bigEndian: magicBE) == 0xfade0cc0,
              let totalBE = readU32(buf, 4),
              let countBE = readU32(buf, 8) else { return nil }
        let total = Int(UInt32(bigEndian: totalBE))
        let count = Int(UInt32(bigEndian: countBE))
        guard total >= 12, total <= buf.count, count >= 0, count <= (total - 12) / 8,
              let base = buf.baseAddress else { return nil }

        for i in 0..<count {
            guard let offBE = readU32(buf, 12 + i * 8 + 4) else { continue }
            let blobOffset = Int(UInt32(bigEndian: offBE))
            guard inRange(blobOffset, 8, total),
                  let blobMagicBE = readU32(buf, blobOffset),
                  let blobLenBE = readU32(buf, blobOffset + 4) else { continue }
            let blobMagic = UInt32(bigEndian: blobMagicBE)
            let blobLen = Int(UInt32(bigEndian: blobLenBE))
            guard blobMagic == 0xfade7171, blobLen > 8, inRange(blobOffset, blobLen, total) else { continue }
            let plistData = Data(bytes: base.advanced(by: blobOffset + 8), count: blobLen - 8)
            if let dict = (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any] {
                return dict
            }
        }
        return nil
    }

    private static func parseThinMachO(_ buf: UnsafeRawBufferPointer) -> [String: Any]? {
        guard let magic = readU32(buf, 0) else { return nil }
        let is64 = (magic == MH_MAGIC_64)
        guard is64 || magic == MH_MAGIC else { return nil }
        let headerSize = is64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size
        guard buf.count >= headerSize,
              let ncmds = readU32(buf, 16),
              let sizeofcmds = readU32(buf, 20) else { return nil }
        let cmdBytes = Int(sizeofcmds)
        let cmdCount = Int(ncmds)
        guard inRange(headerSize, cmdBytes, buf.count),
              cmdCount <= cmdBytes / MemoryLayout<load_command>.size,
              let base = buf.baseAddress else { return nil }

        var cursor = headerSize
        let end = headerSize + cmdBytes
        for _ in 0..<cmdCount {
            guard inRange(cursor, MemoryLayout<load_command>.size, end),
                  let cmd = readU32(buf, cursor),
                  let cmdsize = readU32(buf, cursor + 4) else { return nil }
            let step = Int(cmdsize)
            guard step >= MemoryLayout<load_command>.size, inRange(cursor, step, end) else { return nil }
            if cmd == UInt32(LC_CODE_SIGNATURE) {
                guard step >= MemoryLayout<linkedit_data_command>.size,
                      let dataoff = readU32(buf, cursor + 8),
                      let datasize = readU32(buf, cursor + 12) else { return nil }
                let sigOff = Int(dataoff)
                let sigSize = Int(datasize)
                guard inRange(sigOff, sigSize, buf.count) else { return nil }
                let slice = UnsafeRawBufferPointer(start: base.advanced(by: sigOff), count: sigSize)
                return parseCSBlob(slice)
            }
            cursor += step
        }
        return nil
    }

    private static func readMachOAppGroups() -> [String]? {
        let execPath: String?
        if let cPath = _dyld_get_image_name(0) {
            execPath = String(cString: cPath)
        } else {
            execPath = Bundle.main.executablePath
        }
        guard let path = execPath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) else {
            return nil
        }
        let parsed: [String: Any]? = data.withUnsafeBytes { buf in
            if let thin = parseThinMachO(buf) { return thin }
            guard buf.count >= MemoryLayout<fat_header>.size,
                  let magicBE = readU32(buf, 0),
                  let nfatBE = readU32(buf, 4),
                  let base = buf.baseAddress else { return nil }
            let magic = UInt32(bigEndian: magicBE)
            let isFat64 = (magic == FAT_MAGIC_64)
            guard isFat64 || magic == FAT_MAGIC else { return nil }
            let archCount = Int(UInt32(bigEndian: nfatBE))
            let stride = isFat64 ? MemoryLayout<fat_arch_64>.size : MemoryLayout<fat_arch>.size
            guard archCount >= 0, archCount <= (buf.count - MemoryLayout<fat_header>.size) / stride else { return nil }
            for i in 0..<archCount {
                let item = MemoryLayout<fat_header>.size + i * stride
                let sliceOff: Int
                let sliceLen: Int
                if isFat64 {
                    guard let offBE = readU64(buf, item + 8), let lenBE = readU64(buf, item + 16),
                          let o = Int(exactly: UInt64(bigEndian: offBE)),
                          let l = Int(exactly: UInt64(bigEndian: lenBE)) else { continue }
                    sliceOff = o
                    sliceLen = l
                } else {
                    guard let offBE = readU32(buf, item + 8), let lenBE = readU32(buf, item + 12) else { continue }
                    sliceOff = Int(UInt32(bigEndian: offBE))
                    sliceLen = Int(UInt32(bigEndian: lenBE))
                }
                guard inRange(sliceOff, sliceLen, buf.count) else { continue }
                let slice = UnsafeRawBufferPointer(start: base.advanced(by: sliceOff), count: sliceLen)
                if let p = parseThinMachO(slice) { return p }
            }
            return nil
        }
        return parsed?["com.apple.security.application-groups"] as? [String]
    }

    // MARK: - Sandbox Extension Token Grant

    private func canonicalRealPath(_ rawPath: String) -> String {
        let standardized = (rawPath as NSString).standardizingPath
        if standardized == "/var" {
            return "/private/var"
        }
        if standardized.hasPrefix("/var/") {
            return "/private" + standardized
        }
        return standardized
    }

    private func varSymlinkAliasPath(_ realPath: String) -> String {
        if realPath == "/private/var" {
            return "/var"
        }
        if realPath.hasPrefix("/private/var/") {
            return String(realPath.dropFirst(8))
        }
        return realPath
    }

    private func canOpenTarget(_ realPath: String) -> Bool {
        let fd = Darwin.open(realPath, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        if fd >= 0 {
            Darwin.close(fd)
            return true
        }
        return errno == EACCES || errno == EISDIR
    }

    /// Must be called while holding `handleLock`.
    private func touchHandleOrderLocked(_ realPath: String) {
        if let idx = handleOrder.firstIndex(of: realPath) {
            handleOrder.remove(at: idx)
        }
        handleOrder.append(realPath)
    }

    /// Must be called while holding `handleLock`.
    private func removeHandleLocked(for realPath: String) -> Int64? {
        handleOrder.removeAll { $0 == realPath }
        return activeHandles.removeValue(forKey: realPath)
    }

    private func reuseValidHandle(for realPath: String, requireWrite: Bool) -> Int64? {
        handleLock.lock()
        guard let existing = activeHandles[realPath] else {
            handleLock.unlock()
            return nil
        }
        if canOpenTarget(realPath),
           (!requireWrite || (fm.isReadableFile(atPath: realPath) && fm.isWritableFile(atPath: realPath))) {
            touchHandleOrderLocked(realPath)
            handleLock.unlock()
            return existing
        }
        _ = removeHandleLocked(for: realPath)
        handleLock.unlock()
        if existing >= 0 {
            worse_query_release(existing)
        }
        return nil
    }

    func grantAccess(path: String, requireWrite: Bool = true) -> (Bool, Int64, String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return (false, 0, Bi("目标路径为空", "Target path is empty"))
        }

        let realPath = canonicalRealPath(trimmed)
        let varPath = varSymlinkAliasPath(realPath)

        // Fast path: reuse an active handle if POSIX open and FileManager checks pass.
        if let existing = reuseValidHandle(for: realPath, requireWrite: requireWrite) {
            return (true, existing, "succeeded")
        }

        queryLock.lock()
        defer { queryLock.unlock() }

        // Re-check after acquiring queryLock in case another caller just granted it.
        if let existing = reuseValidHandle(for: realPath, requireWrite: requireWrite) {
            return (true, existing, "succeeded")
        }

        if usableAppGroups.isEmpty {
            let detected = Self.detectAppGroups(fm: fm)
            usableAppGroups = detected.usable
            if activeAppGroup.isEmpty {
                activeAppGroup = detected.primary
            }
        }

        var groupsToTry: [String] = []
        if !activeAppGroup.isEmpty && (usableAppGroups.isEmpty || usableAppGroups.contains(activeAppGroup)) {
            groupsToTry.append(activeAppGroup)
        }
        for groupID in usableAppGroups where !groupsToTry.contains(groupID) {
            groupsToTry.append(groupID)
        }
        if groupsToTry.isEmpty && !activeAppGroup.isEmpty {
            groupsToTry.append(activeAppGroup)
        }

        // On iOS 26 (majorVersion < 27), all container queries default to alt_flags = true; iOS 27+ defaults to false.
        let defaultAlt = ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27
        let altFirst = preferredAltFlags ?? defaultAlt
        let candidatePaths = (varPath != realPath) ? [realPath, varPath] : [realPath]

        func attemptQuery(useAlt: Bool) -> (res: Int64, matchedGroup: String?) {
            var lastErr: Int64 = -1
            for groupID in groupsToTry {
                for candidatePath in candidatePaths {
                    let r = worse_query(candidatePath, groupID, useAlt, false)
                    if r >= 0 {
                        if canOpenTarget(realPath) {
                            return (r, groupID)
                        }
                        worse_query_release(r)
                        lastErr = -8
                        continue
                    }
                    lastErr = r
                    if r == -1 || r == -2 {
                        return (r, nil)
                    }
                }
            }
            return (lastErr, nil)
        }

        var usedAlt = altFirst
        var (res, matchedGroup) = attemptQuery(useAlt: altFirst)
        if res < 0 && res != -1 && res != -2 {
            let retry = attemptQuery(useAlt: !altFirst)
            if retry.res >= 0 {
                res = retry.res
                matchedGroup = retry.matchedGroup
                usedAlt = !altFirst
            } else if retry.res != -1 && retry.res != -2 {
                res = retry.res
            }
        }

        var errorString: String?
        switch res {
        case -1: errorString = Bi("无法访问 App Group 容器（请使用保留 App Group 权限的签名工具安装）", "Cannot access App Group container (re-sign with App Group preserved)")
        case -2: errorString = Bi("解析系统容器函数失败", "Failed to resolve containermanager symbols")
        case -3: errorString = Bi("创建容器查询句柄失败", "Failed to create container query")
        case -4: errorString = Bi("创建符号链接失败", "Failed to create symlink")
        case -5: errorString = Bi("系统沙盒查询被拒绝（当前系统版本可能不支持免电脑直写，你仍可导出 .tendies 使用）", "Sandbox query denied (use .tendies export on this iOS build)")
        case -6: errorString = Bi("内核未下发沙盒扩展令牌", "Kernel did not issue sandbox extension token")
        case -7: errorString = Bi("消费沙盒扩展令牌失败", "Failed to consume sandbox extension token")
        case -8: errorString = Bi("内核未授予目标路径访问权限", "Kernel did not grant open permission for target path")
        case -255: errorString = Bi("目标容器路径不存在", "Target container path does not exist")
        default:
            if res < 0 {
                errorString = Bi("容器访问授权失败（错误码 \(res)）", "Container access grant failed (code \(res))")
            }
        }

        if errorString == nil && requireWrite {
            if !fm.isReadableFile(atPath: realPath) {
                errorString = Bi("容器路径仍不可读", "Target path remains unreadable")
            } else if !fm.isWritableFile(atPath: realPath) {
                errorString = Bi("容器路径仍不可写", "Target path remains unwritable")
            }
        }

        if res >= 0 && errorString == nil {
            if preferredAltFlags == nil {
                preferredAltFlags = usedAlt
            }
            if let matchedGroup, !matchedGroup.isEmpty, activeAppGroup != matchedGroup {
                activeAppGroup = matchedGroup
            }

            handleLock.lock()
            if let old = removeHandleLocked(for: realPath), old >= 0, old != res {
                worse_query_release(old)
            }
            while activeHandles.count >= maxActiveHandles {
                guard let victimKey = handleOrder.isEmpty ? activeHandles.keys.first : handleOrder.removeFirst() else {
                    break
                }
                if let victimHandle = activeHandles.removeValue(forKey: victimKey),
                   victimHandle >= 0, victimHandle != res {
                    worse_query_release(victimHandle)
                }
            }
            activeHandles[realPath] = res
            handleOrder.append(realPath)
            handleLock.unlock()
        } else if res >= 0 {
            worse_query_release(res)
        }

        if let errorString {
            return (false, res, errorString)
        }
        return (true, res, "succeeded")
    }

    func hasActiveAccess(path: String) -> Bool {
        let realPath = canonicalRealPath(path)
        handleLock.lock()
        defer { handleLock.unlock() }
        return activeHandles[realPath] != nil
    }

    func releaseAccess(path: String) {
        let realPath = canonicalRealPath(path)
        handleLock.lock()
        let handle = removeHandleLocked(for: realPath)
        handleLock.unlock()
        if let handle, handle >= 0 {
            worse_query_release(handle)
        }
    }

    func releaseAll() {
        handleLock.lock()
        let handles = Array(activeHandles.values)
        activeHandles.removeAll()
        handleOrder.removeAll()
        handleLock.unlock()
        for handle in handles where handle >= 0 {
            worse_query_release(handle)
        }
    }
}
