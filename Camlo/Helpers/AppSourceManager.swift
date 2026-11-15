//
//  AppSourceManager.swift
//  Camlo · 开幕
//
//  Manages signing-tool repository subscription links (Feather / SideStore / AltStore / ESign / TrollApps),
//  Global & Mainland-China mirror switching, and in-app OTA release update checking.
//

import Foundation
import Combine
import UIKit

enum SourceRouteMode: String, CaseIterable, Identifiable {
    case githubDirect = "direct"
    case cnMirror = "cn_mirror"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .githubDirect:
            return Bi("GitHub 官方直连", "GitHub Direct")
        case .cnMirror:
            return Bi("国内加速镜像", "CN Accelerated")
        }
    }
}

enum SigningClientTarget: String, CaseIterable, Identifiable {
    case feather
    case sidestore
    case altstore
    case esign
    case trollapps

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feather: return "Feather"
        case .sidestore: return "SideStore"
        case .altstore: return "AltStore"
        case .esign: return Bi("轻松签 ESign", "ESign")
        case .trollapps: return "TrollApps"
        }
    }

    var symbolName: String {
        switch self {
        case .feather: return "leaf.fill"
        case .sidestore: return "shippingbox.fill"
        case .altstore: return "arrow.down.app.fill"
        case .esign: return "signature"
        case .trollapps: return "sparkles.rectangle.stack.fill"
        }
    }

    var usesESignFormat: Bool {
        self == .esign
    }

    func deepLinkURL(for sourceURL: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        let encoded = sourceURL.addingPercentEncoding(withAllowedCharacters: allowed) ?? sourceURL

        switch self {
        case .feather:
            return URL(string: "feather://source/\(sourceURL)")
        case .sidestore:
            return URL(string: "sidestore://source?url=\(encoded)")
        case .altstore:
            return URL(string: "altstore://source?url=\(encoded)")
        case .esign:
            return URL(string: "esign://addsource?url=\(encoded)")
        case .trollapps:
            return URL(string: "trollapps://add?url=\(encoded)")
        }
    }
}

struct RemoteVersionInfo: Equatable, Sendable {
    let version: String
    let buildVersion: String?
    let dateString: String
    let changelog: String
    let downloadURL: String
    let sizeBytes: Int64
}

@MainActor
final class AppSourceManager: ObservableObject {
    static let shared = AppSourceManager()

    nonisolated static let defaultRepoSlug = "Kianuni/Camlo"
    nonisolated static let mirrorPrefix = "https://ghfast.top/"

    @Published var routeMode: SourceRouteMode {
        didSet {
            UserDefaults.standard.set(routeMode.rawValue, forKey: "camlo_source_route_mode")
        }
    }

    @Published var repoSlug: String {
        didSet {
            let trimmed = repoSlug.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? Self.defaultRepoSlug : trimmed, forKey: "camlo_source_repo_slug")
        }
    }

    @Published var githubToken: String {
        didSet {
            UserDefaults.standard.set(githubToken.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "camlo_source_github_token")
        }
    }

    @Published private(set) var isCheckingUpdate: Bool = false
    @Published private(set) var latestRelease: RemoteVersionInfo?
    @Published private(set) var hasNewerUpdate: Bool = false
    @Published private(set) var lastCheckStatus: String = ""

    nonisolated static var defaultRouteMode: SourceRouteMode {
        if let rawMode = UserDefaults.standard.string(forKey: "camlo_source_route_mode"),
           let explicit = SourceRouteMode(rawValue: rawMode) {
            return explicit
        }
        let regionCode = Locale.current.region?.identifier.uppercased() ?? ""
        let tzID = TimeZone.current.identifier
        let primaryLang = Locale.preferredLanguages.first?.lowercased() ?? ""
        if regionCode == "CN"
            || tzID == "Asia/Shanghai"
            || tzID == "Asia/Chongqing"
            || primaryLang.hasPrefix("zh-hans") {
            return .cnMirror
        }
        return .githubDirect
    }

    nonisolated static var prefersCNMirror: Bool {
        defaultRouteMode == .cnMirror
    }

    nonisolated static var currentGitHubToken: String {
        (UserDefaults.standard.string(forKey: "camlo_source_github_token") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func currentEffectiveRepoSlug() -> String {
        let savedSlug = UserDefaults.standard.string(forKey: "camlo_source_repo_slug") ?? defaultRepoSlug
        let cleaned = savedSlug.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://github.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return cleaned.contains("/") ? cleaned : defaultRepoSlug
    }

    /// 仅为 Camlo 主仓库直连 GitHub 域名附加可选私有测试 Token，绝不向第三方社区源或镜像代理转发凭据。
    nonisolated static func applyGitHubAuthIfNeeded(to request: inout URLRequest) {
        let token = currentGitHubToken
        guard !token.isEmpty,
              let url = request.url,
              let host = url.host?.lowercased(),
              host == "raw.githubusercontent.com"
                || host == "api.github.com"
                || host == "github.com"
                || host == "objects.githubusercontent.com" else {
            return
        }
        let slugLower = currentEffectiveRepoSlug().lowercased()
        let pathLower = url.path.lowercased()
        guard pathLower.contains("/\(slugLower)/") else {
            return
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private init() {
        self.routeMode = Self.defaultRouteMode
        let savedSlug = UserDefaults.standard.string(forKey: "camlo_source_repo_slug") ?? Self.defaultRepoSlug
        self.repoSlug = savedSlug.isEmpty ? Self.defaultRepoSlug : savedSlug
        self.githubToken = UserDefaults.standard.string(forKey: "camlo_source_github_token") ?? ""
    }

    private var normalizedSlug: String {
        let cleaned = repoSlug.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://github.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return cleaned.contains("/") ? cleaned : Self.defaultRepoSlug
    }

    var activeAltStoreRepoURL: String {
        let rawBase = "https://raw.githubusercontent.com/\(normalizedSlug)/main"
        switch routeMode {
        case .githubDirect:
            return "\(rawBase)/apps.json"
        case .cnMirror:
            return "\(Self.mirrorPrefix)\(rawBase)/repo_cn.json"
        }
    }

    var effectiveRepoSlug: String {
        normalizedSlug
    }

    /// 根据当前网络线路模式（大陆镜像加速 / GitHub 直连）生成仓库内静态资源的候选下载 URL 列表（含多镜像备用兜底）
    func candidateRawURLs(for relativeRepoPath: String) -> [URL] {
        CloudGalleryManager.buildRepoURLs(
            pathOrURL: relativeRepoPath,
            repoSlug: normalizedSlug,
            branch: "main"
        )
    }

    var activeESignRepoURL: String {
        let rawBase = "https://raw.githubusercontent.com/\(normalizedSlug)/main"
        switch routeMode {
        case .githubDirect:
            return "\(rawBase)/esign.json"
        case .cnMirror:
            return "\(Self.mirrorPrefix)\(rawBase)/esign_cn.json"
        }
    }

    var githubReleasesPageURL: URL? {
        URL(string: "https://github.com/\(normalizedSlug)/releases")
    }

    func copyRepoURL(esignFormat: Bool) -> String {
        let targetURL = esignFormat ? activeESignRepoURL : activeAltStoreRepoURL
        UIPasteboard.general.string = targetURL
        CamloHaptics.notify(.success)
        return targetURL
    }

    func openInSigningClient(_ client: SigningClientTarget, onFallbackCopied: @escaping (String) -> Void) {
        let sourceURL = client.usesESignFormat ? activeESignRepoURL : activeAltStoreRepoURL
        UIPasteboard.general.string = sourceURL
        CamloHaptics.selection()

        guard let deepURL = client.deepLinkURL(for: sourceURL) else {
            onFallbackCopied(sourceURL)
            return
        }

        UIApplication.shared.open(deepURL, options: [:]) { opened in
            if !opened {
                Task { @MainActor in
                    onFallbackCopied(sourceURL)
                }
            }
        }
    }

    func checkForUpdates() {
        guard !isCheckingUpdate else { return }
        isCheckingUpdate = true
        lastCheckStatus = ""

        let slug = normalizedSlug
        let rawApps = "https://raw.githubusercontent.com/\(slug)/main/apps.json"
        let rawRepo = "https://raw.githubusercontent.com/\(slug)/main/repo.json"
        let rawRepoCN = "https://raw.githubusercontent.com/\(slug)/main/repo_cn.json"
        let candidateURLs: [String]
        if !Self.currentGitHubToken.isEmpty {
            candidateURLs = [rawApps, rawRepo]
        } else if routeMode == .cnMirror {
            candidateURLs = [
                "\(Self.mirrorPrefix)\(rawRepoCN)",
                "https://gh-proxy.com/\(rawRepoCN)",
                "https://cdn.jsdmirror.com/gh/\(slug)@main/repo_cn.json",
                rawApps,
                rawRepo
            ]
        } else {
            candidateURLs = [
                rawApps,
                "\(Self.mirrorPrefix)\(rawRepoCN)",
                "https://gh-proxy.com/\(rawRepoCN)",
                "https://cdn.jsdmirror.com/gh/\(slug)@main/repo_cn.json",
                rawRepo
            ]
        }

        let currentVer = CamloDevice.appVersion
        let currentBuild = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        let bundleID = Bundle.main.bundleIdentifier ?? "com.kianuni.Camlo"

        Task.detached(priority: .userInitiated) {
            let fetched = await Self.fetchLatestFromCandidates(candidateURLs, bundleID: bundleID)
            await MainActor.run {
                self.isCheckingUpdate = false
                switch fetched {
                case .success(let info):
                    self.latestRelease = info
                    let newer = Self.isRemoteNewer(
                        remoteVer: info.version,
                        remoteBuild: info.buildVersion,
                        localVer: currentVer,
                        localBuild: currentBuild
                    )
                    self.hasNewerUpdate = newer
                    if newer {
                        self.lastCheckStatus = Bi(
                            "发现新版本 v\(info.version)（当前 v\(currentVer)），可在签名工具中一键更新",
                            "New version v\(info.version) available (current v\(currentVer))"
                        )
                        CamloHaptics.notify(.success)
                    } else {
                        self.lastCheckStatus = Bi(
                            "当前已是最新版本 (v\(currentVer))",
                            "You are up to date (v\(currentVer))"
                        )
                        CamloHaptics.selection()
                    }
                case .failure(let err):
                    self.lastCheckStatus = err.localizedDescription
                    CamloHaptics.notify(.warning)
                }
            }
        }
    }

    // MARK: - Networking & SemVer Comparison

    nonisolated private static func fetchLatestFromCandidates(
        _ urls: [String],
        bundleID: String
    ) async -> Result<RemoteVersionInfo, Error> {
        var lastError: Error?
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)

        for raw in urls {
            guard let u = URL(string: raw) else { continue }
            do {
                var req = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
                req.setValue("Camlo/\(CamloDevice.appVersion)", forHTTPHeaderField: "User-Agent")
                Self.applyGitHubAuthIfNeeded(to: &req)
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw NSError(
                        domain: "CamloRepo",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: Bi("软件源暂未发布或仓库尚未公开上线", "Repository source is not reachable yet")]
                    )
                }
                if let parsed = parseRepoJSON(data, bundleID: bundleID) {
                    return .success(parsed)
                }
            } catch {
                lastError = error
            }
        }

        return .failure(
            lastError ?? NSError(
                domain: "CamloRepo",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: Bi("无法连接软件源，请切换「国内加速镜像」或检查网络", "Could not connect to app source")]
            )
        )
    }

    nonisolated private static func parseRepoJSON(_ data: Data, bundleID: String) -> RemoteVersionInfo? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let apps = root["apps"] as? [[String: Any]] else {
            return nil
        }

        let matchedApp = apps.first(where: { ($0["bundleIdentifier"] as? String) == bundleID }) ?? apps.first
        guard let app = matchedApp else { return nil }

        if let versions = app["versions"] as? [[String: Any]], let latest = versions.first {
            let ver = (latest["version"] as? String) ?? "1.0.0"
            let buildVer = latest["buildVersion"] as? String
            let date = (latest["date"] as? String) ?? ""
            let desc = (latest["localizedDescription"] as? String) ?? ""
            let dl = (latest["downloadURL"] as? String) ?? ""
            let size = (latest["size"] as? NSNumber)?.int64Value ?? 0
            return RemoteVersionInfo(
                version: ver,
                buildVersion: buildVer,
                dateString: date,
                changelog: desc,
                downloadURL: dl,
                sizeBytes: size
            )
        } else if let ver = app["version"] as? String {
            return RemoteVersionInfo(
                version: ver,
                buildVersion: app["buildVersion"] as? String,
                dateString: (app["versionDate"] as? String) ?? "",
                changelog: (app["versionDescription"] as? String) ?? (app["localizedDescription"] as? String) ?? "",
                downloadURL: (app["downloadURL"] as? String) ?? "",
                sizeBytes: (app["size"] as? NSNumber)?.int64Value ?? 0
            )
        }
        return nil
    }

    nonisolated static func isRemoteNewer(
        remoteVer: String,
        remoteBuild: String?,
        localVer: String,
        localBuild: String
    ) -> Bool {
        let rParts = remoteVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { Int($0) ?? 0 }
        let lParts = localVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { Int($0) ?? 0 }
        let maxCount = max(rParts.count, lParts.count)
        for i in 0..<maxCount {
            let rv = i < rParts.count ? rParts[i] : 0
            let lv = i < lParts.count ? lParts[i] : 0
            if rv != lv { return rv > lv }
        }
        if let rbStr = remoteBuild, let rb = Int(rbStr), let lb = Int(localBuild), rb > lb {
            return true
        }
        return false
    }
}
