//
//  LiveCAPreviewView.swift
//  Camlo · 开幕
//
//  100% Camlo-native 120Hz Core Animation player powered by CAPackage +
//  CAStateController + CADisplayLink + CoreMotion. Renders LayeredAnimation,
//  ParameterizedCA (3D gyroscope parallax), appearanceAware Day/Night variants,
//  and Home Screen soft-focus pairing directly inside the app.
//

import SwiftUI
import UIKit
import QuartzCore

// MARK: - Resolved Descriptor Package Model

struct CAParallaxRule: Sendable {
    let layerName: String
    let keyPath: String
    let axis: String
    let mapMin: Double
    let mapMax: Double
}

enum ResolvedCARenderingMode: Sendable {
    case layered(backgroundURL: URL?, floatingURL: URL?, foregroundURL: URL?)
    case parameterized(caURL: URL)
    case still(imageURL: URL)

    var caBundleURL: URL? {
        if case .parameterized(let url) = self { return url }
        return nil
    }
}

struct ResolvedCAPackageVariant: Sendable {
    let renderMode: ResolvedCARenderingMode
}

struct ResolvedCAPackageDescriptor: Identifiable, Sendable {
    let id: String
    let title: String
    let wantsDeviceMotion: Bool
    let appearanceAware: Bool
    let hasDuoInnerVariant: Bool
    let defaultVariant: ResolvedCAPackageVariant
    let darkVariant: ResolvedCAPackageVariant?
    let styleSummary: ParsedPosterStyleSummary

    func variant(nightMode: Bool) -> ResolvedCAPackageVariant {
        if nightMode, let darkVariant {
            return darkVariant
        }
        return defaultVariant
    }
}

enum TendiesRuntimeResolver {
    static func resolveDescriptors(for item: TendiesVaultItem) -> [ResolvedCAPackageDescriptor] {
        let fm = FileManager.default
        let pkgDir = CamloPaths.packagesDir.appendingPathComponent(item.storageFolderName, isDirectory: true)
        guard fm.fileExists(atPath: pkgDir.path) else { return [] }

        var results: [ResolvedCAPackageDescriptor] = []
        let folderCandidates = item.descriptorFolderNames.isEmpty ? ["."] : item.descriptorFolderNames

        for (descrIdx, folderName) in folderCandidates.enumerated() {
            let descrDir = (folderName == ".")
                ? pkgDir
                : pkgDir.appendingPathComponent(folderName, isDirectory: true)
            guard fm.fileExists(atPath: descrDir.path) else { continue }

            let styleSummary = PosterStyleGenerator.parseDescriptorStyleSummary(in: descrDir)
            var wpPlistURLs: [URL] = []

            if let en = fm.enumerator(at: descrDir, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
                for case let url as URL in en where url.lastPathComponent == "Wallpaper.plist" {
                    wpPlistURLs.append(url)
                }
            }
            wpPlistURLs.sort { $0.path < $1.path }

            if !wpPlistURLs.isEmpty {
                for (wpIdx, plistURL) in wpPlistURLs.enumerated() {
                    if let resolved = parseWallpaperPlist(
                        at: plistURL,
                        fallbackTitle: item.title,
                        index: descrIdx * 10 + wpIdx,
                        styleSummary: styleSummary
                    ) {
                        results.append(resolved)
                    }
                }
            } else if let fallback = fallbackResolveDirectory(
                descrDir,
                title: item.title,
                index: descrIdx,
                styleSummary: styleSummary
            ) {
                results.append(fallback)
            }
        }

        return results
    }

    private static func parseWallpaperPlist(
        at plistURL: URL,
        fallbackTitle: String,
        index: Int,
        styleSummary: ParsedPosterStyleSummary
    ) -> ResolvedCAPackageDescriptor? {
        guard let data = try? Data(contentsOf: plistURL),
              let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return nil
        }

        let wpDir = plistURL.deletingLastPathComponent()
        let wantsMotion = (dict["wantsDeviceMotion"] as? Bool) ?? false
        let appearanceAware = (dict["appearanceAware"] as? Bool) ?? false
        let rawName = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = (!rawName.isEmpty && rawName != "WWDC 2022" && rawName != "Lavender")
            ? rawName
            : (index == 0 ? fallbackTitle : "\(fallbackTitle) #\(index + 1)")

        let assetsDict = dict["assets"] as? [String: Any]
        let lockAndHome = assetsDict?["lockAndHome"] as? [String: Any]

        let defaultVariant: ResolvedCAPackageVariant
        if let defEntry = lockAndHome?["default"] as? [String: Any],
           let parsed = parseVariantEntry(defEntry, in: wpDir) {
            defaultVariant = parsed
        } else if let direct = fallbackResolveDirectory(wpDir, title: title, index: index, styleSummary: styleSummary)?.defaultVariant {
            defaultVariant = direct
        } else {
            return nil
        }

        let darkVariant: ResolvedCAPackageVariant?
        if let darkEntry = lockAndHome?["dark"] as? [String: Any] {
            darkVariant = parseVariantEntry(darkEntry, in: wpDir)
        } else {
            darkVariant = nil
        }

        let isParam = {
            if case .parameterized = defaultVariant.renderMode { return true }
            return false
        }()
        let hasDuoInner: Bool = {
            guard let caURL = defaultVariant.renderMode.caBundleURL else { return false }
            let camlURL = caURL.appendingPathComponent("main.caml")
            guard let xml = try? String(contentsOf: camlURL, encoding: .utf8) else { return false }
            return xml.contains("<wallpapers") && xml.contains("BACKGROUND_INNER")
        }()

        return ResolvedCAPackageDescriptor(
            id: wpDir.path + "#\(index)",
            title: title,
            wantsDeviceMotion: wantsMotion || isParam,
            appearanceAware: appearanceAware || darkVariant != nil,
            hasDuoInnerVariant: hasDuoInner,
            defaultVariant: defaultVariant,
            darkVariant: darkVariant,
            styleSummary: styleSummary
        )
    }

    private static func parseVariantEntry(_ entry: [String: Any], in wpDir: URL) -> ResolvedCAPackageVariant? {
        let fm = FileManager.default
        let type = (entry["type"] as? String) ?? ""

        if type == "ParameterizedCA" || entry["assetFileName"] != nil {
            if let assetName = entry["assetFileName"] as? String {
                let caURL = wpDir.appendingPathComponent(assetName, isDirectory: true)
                if fm.fileExists(atPath: caURL.path) {
                    return ResolvedCAPackageVariant(renderMode: .parameterized(caURL: caURL))
                }
            }
        }

        let bgName = entry["backgroundAnimationFileName"] as? String
        let flName = (entry["floatingAnimationFileNameKey"] as? String) ?? (entry["floatingAnimationFileName"] as? String)
        let fgName = entry["foregroundAnimationFileName"] as? String

        if bgName != nil || flName != nil || fgName != nil {
            let bgURL = bgName.map { wpDir.appendingPathComponent($0, isDirectory: true) }
            let flURL = flName.map { wpDir.appendingPathComponent($0, isDirectory: true) }
            let fgURL = fgName.map { wpDir.appendingPathComponent($0, isDirectory: true) }
            return ResolvedCAPackageVariant(
                renderMode: .layered(
                    backgroundURL: bgURL.flatMap { fm.fileExists(atPath: $0.path) ? $0 : nil },
                    floatingURL: flURL.flatMap { fm.fileExists(atPath: $0.path) ? $0 : nil },
                    foregroundURL: fgURL.flatMap { fm.fileExists(atPath: $0.path) ? $0 : nil }
                )
            )
        }

        for imgKey in ["stillImageFileName", "backgroundImageFileName", "imageFileName"] {
            if let imgName = entry[imgKey] as? String {
                let imgURL = wpDir.appendingPathComponent(imgName)
                if fm.fileExists(atPath: imgURL.path) {
                    return ResolvedCAPackageVariant(renderMode: .still(imageURL: imgURL))
                }
            }
        }
        return nil
    }

    private static func fallbackResolveDirectory(
        _ dir: URL,
        title: String,
        index: Int,
        styleSummary: ParsedPosterStyleSummary
    ) -> ResolvedCAPackageDescriptor? {
        let fm = FileManager.default
        var caBundles: [URL] = []
        var imageCandidate: URL?

        if let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in en {
                if url.pathExtension.lowercased() == "ca" {
                    caBundles.append(url)
                    en.skipDescendants()
                } else if imageCandidate == nil {
                    let ext = url.pathExtension.lowercased()
                    if (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "heic") &&
                       !url.lastPathComponent.lowercased().hasPrefix("particle_") {
                        imageCandidate = url
                    }
                }
            }
        }

        if let bgCA = caBundles.first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains("background") }) {
            let flCA = caBundles.first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains("floating") })
            let fgCA = caBundles.first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains("foreground") })
            return ResolvedCAPackageDescriptor(
                id: dir.path + "#fallback_\(index)",
                title: title,
                wantsDeviceMotion: false,
                appearanceAware: false,
                hasDuoInnerVariant: false,
                defaultVariant: ResolvedCAPackageVariant(
                    renderMode: .layered(backgroundURL: bgCA, floatingURL: flCA, foregroundURL: fgCA)
                ),
                darkVariant: nil,
                styleSummary: styleSummary
            )
        }

        if let singleCA = caBundles.first {
            let camlURL = singleCA.appendingPathComponent("main.caml")
            let hasDuo = (try? String(contentsOf: camlURL, encoding: .utf8)).map {
                $0.contains("<wallpapers") && $0.contains("BACKGROUND_INNER")
            } ?? false
            return ResolvedCAPackageDescriptor(
                id: dir.path + "#singleca_\(index)",
                title: title,
                wantsDeviceMotion: singleCA.lastPathComponent.lowercased().contains("wallpaper"),
                appearanceAware: false,
                hasDuoInnerVariant: hasDuo,
                defaultVariant: ResolvedCAPackageVariant(renderMode: .parameterized(caURL: singleCA)),
                darkVariant: nil,
                styleSummary: styleSummary
            )
        }

        if let imageCandidate {
            return ResolvedCAPackageDescriptor(
                id: dir.path + "#still_\(index)",
                title: title,
                wantsDeviceMotion: false,
                appearanceAware: false,
                hasDuoInnerVariant: false,
                defaultVariant: ResolvedCAPackageVariant(renderMode: .still(imageURL: imageCandidate)),
                darkVariant: nil,
                styleSummary: styleSummary
            )
        }

        return nil
    }
}

// MARK: - LiveCAPreviewView

struct LiveCAPreviewView: View {
    let item: TendiesVaultItem

    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var motion = MotionTiltManager.shared
    @State private var descriptors: [ResolvedCAPackageDescriptor] = []
    @State private var selectedIndex: Int = 0
    @State private var stage: LockScreenStage = .locked
    @State private var nightMode: Bool = false
    @State private var showHomeScreen: Bool = false
    @State private var duoSurface: DuoScreenSurface = .outerCover
    @State private var interactiveParallaxInLayered: Bool = true
    @State private var hasDetectedParallaxRules: Bool = false
    @State private var loadErrorMessage: String?
    @State private var swipeProgress: CGFloat = 0
    @State private var sessionToken = UUID()

    private var activeDescriptor: ResolvedCAPackageDescriptor? {
        guard descriptors.indices.contains(selectedIndex) else { return descriptors.first }
        return descriptors[selectedIndex]
    }

    private var isGyroCapable: Bool {
        (activeDescriptor?.wantsDeviceMotion ?? false) || hasDetectedParallaxRules
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top Status & Capabilities Strip
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(motion.activeRefreshHz)Hz Core Animation")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.16), in: Capsule())
                .foregroundStyle(Color.accentColor)

                if isGyroCapable {
                    HStack(spacing: 4) {
                        Image(systemName: "gyroscope")
                            .font(.system(size: 10, weight: .bold))
                        Text(Bi("3D 陀螺仪", "3D Gyro"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15), in: Capsule())
                    .foregroundStyle(.purple)
                }

                if activeDescriptor?.appearanceAware == true {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 10, weight: .bold))
                        Text(Bi("昼夜双生", "Day/Night"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
                }

                Spacer()
            }

            if descriptors.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(descriptors.enumerated()), id: \.element.id) { idx, descr in
                            Button {
                                CamloHaptics.selection()
                                selectedIndex = idx
                            } label: {
                                Text(descr.title)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        selectedIndex == idx ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(selectedIndex == idx ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if activeDescriptor?.hasDuoInnerVariant == true {
                Picker("", selection: $duoSurface) {
                    ForEach(DuoScreenSurface.allCases) { surface in
                        Text(surface.localizedTitle).tag(surface)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Titanium Bezel Phone Stage
            let isDuo = (activeDescriptor?.hasDuoInnerVariant == true)
            let activeSurface: DuoScreenSurface = isDuo ? duoSurface : .outerCover
            let isLandscapeDuo = isDuo && (activeSurface == .innerUnfolded)
            let stageW: CGFloat = isLandscapeDuo ? 328 : 224
            let stageH: CGFloat = isLandscapeDuo ? 231 : (isDuo ? 326 : 484)
            let stageCorner: CGFloat = isLandscapeDuo ? 16 : 34
            ZStack {
                RoundedRectangle(cornerRadius: stageCorner, style: .continuous)
                    .fill(Color.black)

                if let descr = activeDescriptor {
                    CAPackageCanvasHostView(
                        descriptor: descr,
                        stage: stage,
                        nightMode: nightMode,
                        duoSurface: activeSurface,
                        showClock: !showHomeScreen,
                        gyroEnabled: isGyroCapable || interactiveParallaxInLayered,
                        sessionToken: sessionToken,
                        onParallaxDetected: { detected in
                            hasDetectedParallaxRules = detected
                        },
                        onLoadError: { errMsg in
                            loadErrorMessage = errMsg
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: stageCorner, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text(Bi("正在装载 CAML 舞台…", "Mounting CAML stage…"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                // Home Screen Soft-Focus & Icon Pairing Overlay
                if showHomeScreen, let descr = activeDescriptor {
                    homeScreenPairingOverlay(summary: descr.styleSummary)
                        .clipShape(RoundedRectangle(cornerRadius: stageCorner, style: .continuous))
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                }

                // Lock Screen Chrome (when viewing Lock Screen)
                if !showHomeScreen {
                    lockScreenChromeOverlay
                        .allowsHitTesting(false)
                }

                if isLandscapeDuo {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.24), .white.opacity(0.08), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 5)
                        .allowsHitTesting(false)
                }

                // Dynamic Island & Titanium Outer Frame
                VStack {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: isLandscapeDuo ? 50 : 68, height: isLandscapeDuo ? 14 : 19)
                        .padding(.top, 9)
                    Spacer()
                }
                .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: stageCorner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.32), .white.opacity(0.10), .white.opacity(0.24)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3.5
                    )
                    .allowsHitTesting(false)

                if let loadErrorMessage {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(loadErrorMessage)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(width: stageW, height: stageH)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isLandscapeDuo)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        // Vertical drag smoothly triggers Sleep/Locked/Unlock; 2D offset drives live tilt
                        let normX = max(-1.0, min(1.0, value.translation.width / 80.0))
                        let normY = max(-1.0, min(1.0, value.translation.height / 80.0))
                        motion.setManualDragTilt(x: normX, y: normY)

                        if value.translation.height < -14 {
                            swipeProgress = min(1, abs(value.translation.height) / 110)
                        } else if value.translation.height > 14 {
                            swipeProgress = 0
                        }
                    }
                    .onEnded { value in
                        motion.endManualDragTilt()
                        if value.translation.height < -48 {
                            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                                stage = .unlock
                                swipeProgress = 0
                            }
                            CamloHaptics.selection()
                        } else if value.translation.height > 48 && stage == .unlock {
                            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                                stage = .locked
                                swipeProgress = 0
                            }
                            CamloHaptics.selection()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                swipeProgress = 0
                            }
                        }
                    }
            )

            // Primary State Switcher: Sleep / Locked / Unlock
            HStack(spacing: 8) {
                ForEach(LockScreenStage.allCases, id: \.self) { st in
                    Button {
                        CamloHaptics.selection()
                        if showHomeScreen {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showHomeScreen = false
                            }
                        }
                        stage = st
                    } label: {
                        Label(st.title, systemImage: st.symbol)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                (!showHomeScreen && stage == st) ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                                in: Capsule()
                            )
                            .foregroundStyle((!showHomeScreen && stage == st) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Secondary Controls: Day/Night + Lock/Home + Gyro Orbit Demo
            HStack(spacing: 8) {
                if activeDescriptor?.appearanceAware == true {
                    Button {
                        CamloHaptics.selection()
                        nightMode.toggle()
                    } label: {
                        Label(
                            nightMode ? Bi("夜间外观", "Night") : Bi("日间外观", "Day"),
                            systemImage: nightMode ? "moon.stars.fill" : "sun.max.fill"
                        )
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            nightMode ? Color.indigo.opacity(0.22) : Color.orange.opacity(0.18),
                            in: Capsule()
                        )
                        .foregroundStyle(nightMode ? .indigo : .orange)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    CamloHaptics.selection()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        showHomeScreen.toggle()
                        if showHomeScreen {
                            stage = .unlock
                        }
                    }
                } label: {
                    Label(
                        showHomeScreen ? Bi("返回锁屏", "Lock Screen") : Bi("主屏效果", "Home Preview"),
                        systemImage: showHomeScreen ? "lock.fill" : "apps.iphone"
                    )
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        showHomeScreen ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemGroupedBackground),
                        in: Capsule()
                    )
                    .foregroundStyle(showHomeScreen ? Color.accentColor : .primary)
                }
                .buttonStyle(.plain)

                if isGyroCapable {
                    Button {
                        CamloHaptics.selection()
                        motion.isAutoOrbitDemo.toggle()
                    } label: {
                        Label(
                            motion.isAutoOrbitDemo ? Bi("停止摆动", "Stop Orbit") : Bi("3D 自动摆动", "3D Orbit"),
                            systemImage: motion.isAutoOrbitDemo ? "pause.circle.fill" : "move.3d"
                        )
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            motion.isAutoOrbitDemo ? Color.purple : Color.purple.opacity(0.14),
                            in: Capsule()
                        )
                        .foregroundStyle(motion.isAutoOrbitDemo ? .white : .purple)
                    }
                    .buttonStyle(.plain)

                    if !motion.isAutoOrbitDemo {
                        Button {
                            CamloHaptics.selection()
                            motion.recenter()
                        } label: {
                            Image(systemName: "scope")
                                .font(.caption2.weight(.bold))
                                .padding(6)
                                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(Bi("提示：支持手指上下轻扫触发「锁屏 ↔ 解锁」变身，或左右倾斜手机感受 120Hz 裸眼 3D 视差", "Tip: Swipe vertically to morph, or tilt your iPhone / drag horizontally for 120Hz 3D parallax."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            motion.startSession(token: sessionToken)
        }
        .task(id: item.id) {
            let target = item
            descriptors = []
            selectedIndex = 0
            stage = .locked
            nightMode = false
            duoSurface = .outerCover
            showHomeScreen = false
            hasDetectedParallaxRules = false
            loadErrorMessage = nil
            swipeProgress = 0
            let resolved = await Task.detached(priority: .userInitiated) {
                TendiesRuntimeResolver.resolveDescriptors(for: target)
            }.value
            guard !Task.isCancelled else { return }
            descriptors = resolved
        }
        .onDisappear {
            motion.stopSession(token: sessionToken)
        }
    }

    private var lockScreenChromeOverlay: some View {
        VStack {
            Spacer()
            if stage == .locked {
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 26, height: 26)
                            .overlay(Image(systemName: "flashlight.off.fill").font(.system(size: 11)).foregroundStyle(.white))
                        Spacer()
                        Text(swipeProgress > 0.2 ? Bi("松开体验变身…", "Release to Morph…") : Bi("上滑 / 拖动画布体验", "Swipe Up or Tilt"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.32), in: Capsule())
                        Spacer()
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 26, height: 26)
                            .overlay(Image(systemName: "camera.fill").font(.system(size: 11)).foregroundStyle(.white))
                    }
                    .padding(.horizontal, 18)

                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .frame(width: 78, height: 3.5)
                        .padding(.bottom, 7)
                }
            } else if stage == .unlock {
                Capsule()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 78, height: 3.5)
                    .padding(.bottom, 7)
            }
        }
    }

    private func homeScreenPairingOverlay(summary: ParsedPosterStyleSummary) -> some View {
        let mode = summary.homeModeSummary
        let tint = (summary.homeTintColor ?? RGBAColor(r: 0.18, g: 0.28, b: 0.48)).swiftUIColor
        return ZStack {
            switch mode {
            case .legibilityBlur:
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.18))
            case .clearMatch:
                Color.clear
            case .matchedGradient:
                LinearGradient(
                    colors: [tint.opacity(0.95), Color.black.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .matchedSolid:
                tint.opacity(0.96)
            }

            VStack(spacing: 14) {
                HStack {
                    Text(mode.title)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.45), in: Capsule())
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.top, 38)
                .padding(.horizontal, 14)

                let row1: [(String, Color)] = [
                    ("photo.fill", .blue),
                    ("camera.fill", .gray),
                    ("message.fill", .green),
                    ("safari.fill", .cyan)
                ]
                let row2: [(String, Color)] = [
                    ("music.note", .pink),
                    ("gearshape.fill", .slate ?? .indigo),
                    ("calendar", .red),
                    ("sparkles", .purple)
                ]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                    ForEach(Array((row1 + row2).enumerated()), id: \.offset) { _, icon in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(icon.1.gradient)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: icon.0)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                HStack(spacing: 12) {
                    ForEach(["phone.fill", "safari.fill", "message.fill", "music.note"], id: \.self) { sym in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.24))
                            .frame(width: 34, height: 34)
                            .overlay(Image(systemName: sym).font(.system(size: 14)).foregroundStyle(.white))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.bottom, 12)
            }
        }
    }
}

private extension Color {
    static let slate: Color? = Color(red: 0.36, green: 0.42, blue: 0.54)
}

// MARK: - UIViewRepresentable Host for CAPackage

private struct CAPackageCanvasHostView: UIViewRepresentable {
    let descriptor: ResolvedCAPackageDescriptor
    let stage: LockScreenStage
    let nightMode: Bool
    let duoSurface: DuoScreenSurface
    let showClock: Bool
    let gyroEnabled: Bool
    let sessionToken: UUID
    let onParallaxDetected: (Bool) -> Void
    let onLoadError: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionToken: sessionToken)
    }

    func makeUIView(context: Context) -> CamloLiveStageUIView {
        let view = CamloLiveStageUIView()
        context.coordinator.bind(to: view)
        return view
    }

    func updateUIView(_ uiView: CamloLiveStageUIView, context: Context) {
        let surfaceKey = descriptor.hasDuoInnerVariant ? duoSurface.rawValue : "std"
        let key = "\(descriptor.id)|night=\(nightMode)|surface=\(surfaceKey)|lang=\(LocalizationManager.effectiveLanguageCode)"
        if context.coordinator.loadedKey != key {
            context.coordinator.loadedKey = key
            let variant = descriptor.variant(nightMode: nightMode)
            let err = uiView.loadVariant(
                variant,
                styleSummary: descriptor.styleSummary,
                duoSurface: duoSurface
            )
            let detectedParallax = !uiView.parallaxTargets.isEmpty
            DispatchQueue.main.async {
                onParallaxDetected(detectedParallax)
                onLoadError(err)
            }
        }
        uiView.setGyroEnabled(gyroEnabled)
        uiView.setClockVisible(showClock)
        uiView.transition(to: stage)
    }

    static func dismantleUIView(_ uiView: CamloLiveStageUIView, coordinator: Coordinator) {
        coordinator.unbind()
        uiView.teardown()
    }

    final class Coordinator {
        let observerToken = UUID()
        var loadedKey: String?
        weak var stageView: CamloLiveStageUIView?

        init(sessionToken _: UUID) {}

        @MainActor
        func bind(to view: CamloLiveStageUIView) {
            stageView = view
            MotionTiltManager.shared.registerFrameObserver(token: observerToken) { [weak view] tx, ty in
                view?.applyParallaxTilt(x: tx, y: ty)
            }
        }

        @MainActor
        func unbind() {
            MotionTiltManager.shared.unregisterFrameObserver(token: observerToken)
            stageView = nil
        }
    }
}

// MARK: - Native CALayer Stage View

private final class CamloLiveStageUIView: UIView {
    struct ParallaxTarget {
        let layer: CALayer
        let keyPath: String
        let baseValue: Double
        let minOffset: Double
        let maxOffset: Double
        let axis: String
    }

    struct PropertyTarget {
        let layer: CALayer
        let keyPath: String
        let sleepValue: Double
        let lockValue: Double
        let homeValue: Double
    }

    private var currentStage: LockScreenStage = .locked
    private var activeDuoSurface: DuoScreenSurface = .outerCover
    private var gyroActive = false
    private var showClock = true

    private var stageControllers: [CamloCAStageController] = []
    private var docSize: CGSize = CGSize(width: 390, height: 844)
    private var isFlipped = false

    private let stageContainerLayer = CALayer()
    private var stillImageLayer: CALayer?
    private var clockLayer: CALayer?

    private var layeredBgLayer: CALayer?
    private var layeredFlLayer: CALayer?
    private var layeredFgLayer: CALayer?

    private(set) var parallaxTargets: [ParallaxTarget] = []
    private var propertyTargets: [PropertyTarget] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.masksToBounds = true
        stageContainerLayer.masksToBounds = true
        layer.addSublayer(stageContainerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutStageLayers()
        CATransaction.commit()
    }

    func loadVariant(
        _ variant: ResolvedCAPackageVariant,
        styleSummary: ParsedPosterStyleSummary,
        duoSurface: DuoScreenSurface = .outerCover
    ) -> String? {
        teardown()
        activeDuoSurface = duoSurface
        var errorMessages: [String] = []

        switch variant.renderMode {
        case .parameterized(let caURL):
            do {
                let stage = try CamloCAStageController(packageURL: caURL)
                stageControllers.append(stage)
                isFlipped = stage.isGeometryFlipped
                let root = stage.rootLayer
                root.masksToBounds = false
                stageContainerLayer.addSublayer(root)

                let selectedVariantDict = configureDuoDisplayVariantIfNeeded(in: stage, surface: duoSurface, fallbackSize: stage.documentSize)
                insertClockBetweenParameterizedPlanes(in: root, summary: styleSummary, surface: duoSurface)
                collectParallaxTargets(from: stage, variantDict: selectedVariantDict)
                collectPropertyTargets(from: stage, variantDict: selectedVariantDict, surface: duoSurface)
            } catch {
                errorMessages.append(error.localizedDescription)
            }

        case .layered(let bgURL, let flURL, let fgURL):
            var primaryDocSize: CGSize?
            var primaryFlipped = false

            if let bgURL {
                if let bg = try? CamloCAStageController(packageURL: bgURL) {
                    stageControllers.append(bg)
                    primaryDocSize = bg.documentSize
                    primaryFlipped = bg.isGeometryFlipped
                    bg.rootLayer.zPosition = 0
                    stageContainerLayer.addSublayer(bg.rootLayer)
                    layeredBgLayer = bg.rootLayer
                } else {
                    errorMessages.append(Bi("Background.ca 解析失败", "Failed to load Background.ca"))
                }
            }

            docSize = sanitizedSize(primaryDocSize ?? CGSize(width: 390, height: 844))
            isFlipped = primaryFlipped

            let cLayer = makeClockLayer(
                fontStyle: styleSummary.clockFontStyle,
                color: styleSummary.clockColor ?? defaultClockColor(for: styleSummary),
                flipped: false
            )
            cLayer.zPosition = 10
            stageContainerLayer.addSublayer(cLayer)
            clockLayer = cLayer

            if let flURL, let fl = try? CamloCAStageController(packageURL: flURL) {
                stageControllers.append(fl)
                fl.rootLayer.zPosition = 20
                stageContainerLayer.addSublayer(fl.rootLayer)
                layeredFlLayer = fl.rootLayer
            }
            if let fgURL, let fg = try? CamloCAStageController(packageURL: fgURL) {
                stageControllers.append(fg)
                fg.rootLayer.zPosition = 30
                stageContainerLayer.addSublayer(fg.rootLayer)
                layeredFgLayer = fg.rootLayer
            }

        case .still(let imageURL):
            docSize = CGSize(width: 390, height: 844)
            isFlipped = false
            if let data = try? Data(contentsOf: imageURL), let img = UIImage(data: data) {
                let sLayer = CALayer()
                sLayer.contents = img.cgImage
                sLayer.contentsGravity = .resizeAspectFill
                sLayer.bounds = CGRect(origin: .zero, size: docSize)
                sLayer.position = CGPoint(x: docSize.width * 0.5, y: docSize.height * 0.5)
                sLayer.zPosition = 0
                stageContainerLayer.addSublayer(sLayer)
                stillImageLayer = sLayer
                layeredBgLayer = sLayer
            }
            let cLayer = makeClockLayer(
                fontStyle: styleSummary.clockFontStyle,
                color: styleSummary.clockColor ?? defaultClockColor(for: styleSummary),
                flipped: false
            )
            cLayer.zPosition = 10
            stageContainerLayer.addSublayer(cLayer)
            clockLayer = cLayer
        }

        layoutStageLayers()
        transition(to: currentStage, immediate: true)
        return errorMessages.isEmpty ? nil : errorMessages.joined(separator: "\n")
    }

    func transition(to newStage: LockScreenStage, immediate: Bool = false) {
        let stageChanged = (newStage != currentStage) || immediate
        currentStage = newStage
        guard stageChanged else { return }

        let targetStateName: String
        switch newStage {
        case .sleep:  targetStateName = "Sleep"
        case .locked: targetStateName = "Locked"
        case .unlock: targetStateName = "Unlock"
        }

        var handledByStateController = false
        for controller in stageControllers {
            if controller.hasStateNamed(targetStateName) {
                if controller.transition(toStateNamed: targetStateName, speed: immediate ? 2.5 : 1.0) {
                    handledByStateController = true
                }
            } else if controller.hasStateNamed("Locked") {
                _ = controller.transition(toStateNamed: "Locked", speed: immediate ? 2.5 : 1.0)
            } else {
                controller.applyInitialStates()
            }
        }

        if !handledByStateController && !propertyTargets.isEmpty {
            CATransaction.begin()
            CATransaction.setDisableActions(immediate)
            CATransaction.setAnimationDuration(0.55)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            for target in propertyTargets {
                let value: Double
                switch newStage {
                case .sleep:  value = target.sleepValue
                case .locked: value = target.lockValue
                case .unlock: value = target.homeValue
                }
                target.layer.setValue(value, forKeyPath: target.keyPath)
            }
            CATransaction.commit()
        }

        if let stillImageLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(immediate)
            stillImageLayer.opacity = (newStage == .sleep) ? 0.52 : 1.0
            CATransaction.commit()
        }

        updateClockVisibilityOpacity(animated: !immediate)
    }

    func setClockVisible(_ visible: Bool) {
        guard visible != showClock else { return }
        showClock = visible
        updateClockVisibilityOpacity(animated: true)
    }

    func setGyroEnabled(_ enabled: Bool) {
        gyroActive = enabled
        if !enabled {
            applyParallaxTilt(x: 0, y: 0)
        }
    }

    func applyParallaxTilt(x: CGFloat, y: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if !parallaxTargets.isEmpty {
            let normX = gyroActive ? Double(max(-1.0, min(1.0, x))) : 0.0
            let normY = gyroActive ? Double(max(-1.0, min(1.0, y))) : 0.0
            for target in parallaxTargets {
                let norm = (target.axis.lowercased() == "y") ? normY : normX
                let span = (target.maxOffset - target.minOffset) * 0.5
                let delta = span * norm
                target.layer.setValue(target.baseValue + delta, forKeyPath: target.keyPath)
            }
        } else if layeredBgLayer != nil || layeredFlLayer != nil || layeredFgLayer != nil {
            let nx = gyroActive ? x : 0
            let ny = gyroActive ? y : 0
            let scale = gyroActive ? CGFloat(1.06) : CGFloat(1.0)
            let dxBase = nx * (docSize.width / 390.0)
            let dyBase = ny * (docSize.height / 844.0)

            if let bg = layeredBgLayer {
                var t = CATransform3DMakeTranslation(dxBase * 7.5, dyBase * 9.5, 0)
                t = CATransform3DScale(t, scale, scale, 1)
                bg.transform = t
            }
            if let fl = layeredFlLayer {
                var t = CATransform3DMakeTranslation(-dxBase * 12.0, -dyBase * 15.0, 0)
                t = CATransform3DScale(t, scale, scale, 1)
                fl.transform = t
            }
            if let fg = layeredFgLayer {
                fg.transform = CATransform3DMakeTranslation(-dxBase * 16.0, -dyBase * 20.0, 0)
            }
        }

        CATransaction.commit()
    }

    func teardown() {
        for controller in stageControllers {
            controller.teardown()
            controller.rootLayer.removeFromSuperlayer()
        }
        stageControllers.removeAll()
        stillImageLayer?.removeFromSuperlayer()
        stillImageLayer = nil
        clockLayer?.removeFromSuperlayer()
        clockLayer = nil
        layeredBgLayer = nil
        layeredFlLayer = nil
        layeredFgLayer = nil
        parallaxTargets.removeAll()
        propertyTargets.removeAll()
    }

    // MARK: - Private Geometry & Clock Helpers

    private func sanitizedSize(_ raw: CGSize) -> CGSize {
        let w = (raw.width > 1 && raw.width < 10000) ? raw.width : 390
        let h = (raw.height > 1 && raw.height < 10000) ? raw.height : 844
        return CGSize(width: w, height: h)
    }

    private func layoutStageLayers() {
        let viewW = max(bounds.width, 1)
        let viewH = max(bounds.height, 1)
        stageContainerLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        stageContainerLayer.position = CGPoint(x: viewW * 0.5, y: viewH * 0.5)

        let sx = viewW / max(docSize.width, 1)
        let sy = viewH / max(docSize.height, 1)
        let aspectScale = max(sx, sy)
        stageContainerLayer.sublayerTransform = CATransform3DMakeScale(aspectScale, aspectScale, 1)

        let center = CGPoint(x: viewW * 0.5, y: viewH * 0.5)
        let docCenter = CGPoint(x: docSize.width * 0.5, y: docSize.height * 0.5)
        let duoPlaneNames: Set<String> = ["BACKGROUND", "FLOATING", "BACKGROUND_INNER", "FLOATING_INNER"]
        for controller in stageControllers {
            let root = controller.rootLayer
            root.bounds = CGRect(origin: .zero, size: docSize)
            root.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            root.position = center
            if let sublayers = root.sublayers {
                for sub in sublayers where sub !== clockLayer {
                    if let name = sub.name?.uppercased(), duoPlaneNames.contains(name) {
                        sub.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                        sub.position = docCenter
                    }
                }
            }
        }
        if let stillImageLayer {
            stillImageLayer.bounds = CGRect(origin: .zero, size: docSize)
            stillImageLayer.position = center
        }
        if let clockLayer {
            clockLayer.bounds = CGRect(origin: .zero, size: docSize)
            if clockLayer.superlayer === stageContainerLayer {
                clockLayer.position = center
            } else {
                clockLayer.position = CGPoint(x: docSize.width * 0.5, y: docSize.height * 0.5)
            }
        }
    }

    private func updateClockVisibilityOpacity(animated: Bool) {
        guard let clockLayer else { return }
        let targetOpacity: Float
        if !showClock || currentStage == .unlock {
            targetOpacity = 0.0
        } else if currentStage == .sleep {
            targetOpacity = 0.58
        } else {
            targetOpacity = 1.0
        }
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.28)
        clockLayer.opacity = targetOpacity
        CATransaction.commit()
    }

    private func defaultClockColor(for summary: ParsedPosterStyleSummary) -> RGBAColor {
        if let lum = summary.contentsLuminance, lum > 0.66 {
            return RGBAColor(r: 0.14, g: 0.16, b: 0.20, a: 0.90)
        }
        return RGBAColor(r: 0.97, g: 0.98, b: 1.0, a: 0.92)
    }

    private func makeClockLayer(fontStyle: ClockFontStyle, color: RGBAColor, flipped: Bool) -> CALayer {
        let renderW = max(docSize.width, 120)
        let renderH = max(docSize.height, 120)
        let isLandscape = renderW > renderH
        let refDim = min(renderW, renderH)
        let scaleFactor: CGFloat = renderW < 600 ? 3.0 : 1.0

        let format = UIGraphicsImageRendererFormat()
        format.scale = scaleFactor
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: renderW, height: renderH), format: format)
        let uiColor = color.uiColor
        let dateFont = UIFont.systemFont(ofSize: refDim * 0.048, weight: .semibold)
        let timeFont = fontStyle.uiFont(size: refDim * (isLandscape ? 0.195 : 0.255))

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        let luminance: CGFloat
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        } else {
            luminance = 0.2126 * CGFloat(color.r) + 0.7152 * CGFloat(color.g) + 0.0722 * CGFloat(color.b)
        }

        let shadow = NSShadow()
        shadow.shadowColor = luminance < 0.35
            ? UIColor.white.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = refDim * 0.025
        shadow.shadowOffset = CGSize(width: 0, height: refDim * 0.008)

        let img = renderer.image { _ in
            let datePara = NSMutableParagraphStyle()
            datePara.alignment = .center
            let dateText = CamloDevice.formattedLockScreenDate()
            let dateAttr = NSAttributedString(
                string: dateText,
                attributes: [
                    .font: dateFont,
                    .foregroundColor: uiColor.withAlphaComponent(0.90),
                    .paragraphStyle: datePara,
                    .shadow: shadow
                ]
            )
            dateAttr.draw(in: CGRect(x: 0, y: renderH * (isLandscape ? 0.08 : 0.095), width: renderW, height: renderH * 0.06))

            let timePara = NSMutableParagraphStyle()
            timePara.alignment = .center
            let timeAttr = NSAttributedString(
                string: "09:41",
                attributes: [
                    .font: timeFont,
                    .foregroundColor: uiColor,
                    .paragraphStyle: timePara,
                    .kern: fontStyle.letterSpacing * (refDim / 390.0) * 1.6,
                    .shadow: shadow
                ]
            )
            timeAttr.draw(in: CGRect(x: 0, y: renderH * (isLandscape ? 0.13 : 0.125), width: renderW, height: refDim * 0.32))
        }

        let layer = CALayer()
        layer.contents = img.cgImage
        layer.contentsGravity = .resizeAspect
        layer.bounds = CGRect(origin: .zero, size: docSize)
        if flipped {
            layer.transform = CATransform3DMakeScale(1, -1, 1)
        }
        return layer
    }

    private func configureDuoDisplayVariantIfNeeded(
        in stage: CamloCAStageController,
        surface: DuoScreenSurface,
        fallbackSize: CGSize
    ) -> [String: Any]? {
        let rootSublayers = stage.rootLayer.sublayers ?? []
        let bgOuter = rootSublayers.first(where: { $0.name?.caseInsensitiveCompare("BACKGROUND") == .orderedSame })
        let flOuter = rootSublayers.first(where: { $0.name?.caseInsensitiveCompare("FLOATING") == .orderedSame })
        let bgInner = rootSublayers.first(where: { $0.name?.caseInsensitiveCompare("BACKGROUND_INNER") == .orderedSame })
        let flInner = rootSublayers.first(where: { $0.name?.caseInsensitiveCompare("FLOATING_INNER") == .orderedSame })

        let variants = stage.rootLayer.style?["wallpapers"] as? [[String: Any]]
        let targetScreenName = (surface == .innerUnfolded) ? "Inner" : "Outer"
        let selected = variants?.first(where: {
            ($0["screenName"] as? String)?.caseInsensitiveCompare(targetScreenName) == .orderedSame
        })

        let showInner = (surface == .innerUnfolded) && (bgInner != nil || selected != nil)
        if showInner {
            bgOuter?.isHidden = true
            flOuter?.isHidden = true
            bgInner?.isHidden = false
            flInner?.isHidden = false
            bgInner?.zPosition = 0
            flInner?.zPosition = 10
            if let iw = numericValue(selected?["idealWidth"]),
               let ih = numericValue(selected?["idealHeight"]), iw > 1, ih > 1 {
                docSize = CGSize(width: iw, height: ih)
            } else {
                docSize = DuoScreenSurface.innerUnfolded.logicalSize
            }
        } else {
            bgOuter?.isHidden = false
            flOuter?.isHidden = false
            bgInner?.isHidden = true
            flInner?.isHidden = true
            if let ow = numericValue(selected?["idealWidth"]),
               let oh = numericValue(selected?["idealHeight"]), ow > 1, oh > 1 {
                docSize = CGSize(width: ow, height: oh)
            } else {
                docSize = sanitizedSize(fallbackSize)
            }
        }

        let targetCenter = CGPoint(x: docSize.width * 0.5, y: docSize.height * 0.5)
        for plane in [bgOuter, flOuter, bgInner, flInner].compactMap({ $0 }) {
            plane.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            plane.position = targetCenter
        }
        return selected
    }

    private func insertClockBetweenParameterizedPlanes(
        in root: CALayer,
        summary: ParsedPosterStyleSummary,
        surface: DuoScreenSurface
    ) {
        let sublayers = root.sublayers ?? []
        let preferInner = (surface == .innerUnfolded) && sublayers.contains(where: { $0.name?.caseInsensitiveCompare("BACKGROUND_INNER") == .orderedSame })
        let bgLayer = preferInner
            ? sublayers.first(where: { $0.name?.caseInsensitiveCompare("BACKGROUND_INNER") == .orderedSame })
            : sublayers.first(where: { $0.name?.caseInsensitiveCompare("BACKGROUND") == .orderedSame })
        let flLayer = preferInner
            ? sublayers.first(where: { $0.name?.caseInsensitiveCompare("FLOATING_INNER") == .orderedSame })
            : sublayers.first(where: { $0.name?.caseInsensitiveCompare("FLOATING") == .orderedSame })

        let cLayer = makeClockLayer(
            fontStyle: summary.clockFontStyle,
            color: summary.clockColor ?? defaultClockColor(for: summary),
            flipped: root.isGeometryFlipped
        )
        clockLayer = cLayer

        if let flLayer {
            let bgZ = bgLayer?.zPosition ?? 0
            if flLayer.zPosition <= bgZ + 1 {
                flLayer.zPosition = bgZ + 10
            }
            cLayer.zPosition = bgZ + (flLayer.zPosition - bgZ) * 0.5
            root.insertSublayer(cLayer, below: flLayer)
        } else {
            cLayer.zPosition = 5
            root.addSublayer(cLayer)
        }
    }

    private func collectParallaxTargets(from stage: CamloCAStageController, variantDict: [String: Any]?) {
        let groups: [[String: Any]]
        if let variantDict {
            let bg = (variantDict["backgroundParallaxGroups"] as? [[String: Any]]) ?? []
            let fg = (variantDict["floatingParallaxGroups"] as? [[String: Any]]) ?? []
            groups = bg + fg
        } else if let top = stage.rootLayer.style?["wallpaperParallaxGroups"] as? [[String: Any]] {
            groups = top
        } else {
            return
        }

        var targets: [ParallaxTarget] = []
        for group in groups {
            guard let layerName = group["layerName"] as? String,
                  let keyPath = group["keyPath"] as? String else { continue }
            let axis = (group["axis"] as? String) ?? (keyPath.lowercased().hasSuffix(".y") ? "y" : "x")
            let rawMin = numericValue(group["mapMinTo"]) ?? -20.0
            let rawMax = numericValue(group["mapMaxTo"]) ?? 20.0
            let axisDim = (axis.lowercased() == "y") ? Double(docSize.height) : Double(docSize.width)
            let maxAllowedSpan = max(12.0, axisDim * 0.115)

            let halfSpan = (rawMax - rawMin) * 0.5
            let clampedSpan: Double
            if abs(halfSpan) > maxAllowedSpan {
                clampedSpan = (halfSpan >= 0 ? 1.0 : -1.0) * maxAllowedSpan
            } else {
                clampedSpan = halfSpan
            }

            let matchedLayers = findLayers(named: layerName, under: stage.rootLayer)
            for layer in matchedLayers {
                let currentVal = (layer.value(forKeyPath: keyPath) as? NSNumber)?.doubleValue ?? 0.0
                targets.append(
                    ParallaxTarget(
                        layer: layer,
                        keyPath: keyPath,
                        baseValue: currentVal,
                        minOffset: -clampedSpan,
                        maxOffset: clampedSpan,
                        axis: axis
                    )
                )
            }
        }
        parallaxTargets = targets
    }

    private func collectPropertyTargets(
        from stage: CamloCAStageController,
        variantDict: [String: Any]?,
        surface: DuoScreenSurface
    ) {
        let groups: [[String: Any]]
        if let variantDict {
            let bg = (variantDict["backgroundPropertyGroups"] as? [[String: Any]]) ?? []
            let fg = (variantDict["floatingPropertyGroups"] as? [[String: Any]]) ?? []
            groups = bg + fg
        } else if let top = stage.rootLayer.style?["wallpaperPropertyGroups"] as? [[String: Any]], !top.isEmpty {
            groups = top
        } else {
            return
        }
        let rootSublayers = stage.rootLayer.sublayers ?? []
        let useInner = (surface == .innerUnfolded) && rootSublayers.contains(where: { $0.name?.caseInsensitiveCompare("BACKGROUND_INNER") == .orderedSame })
        let bgPlane = rootSublayers.first(where: { $0.name?.caseInsensitiveCompare(useInner ? "BACKGROUND_INNER" : "BACKGROUND") == .orderedSame })
        let flPlane = rootSublayers.first(where: { $0.name?.caseInsensitiveCompare(useInner ? "FLOATING_INNER" : "FLOATING") == .orderedSame })

        var targets: [PropertyTarget] = []
        for group in groups {
            guard let layerName = group["layerName"] as? String,
                  let keyPath = group["keyPath"] as? String,
                  let lockVal = numericValue(group["v_lock"]) else { continue }
            let homeVal = numericValue(group["v_home"]) ?? lockVal
            let sleepVal = numericValue(group["v_sleep"]) ?? lockVal
            let viewName = (group["view"] as? String) ?? ""

            let searchRoot: CALayer
            if viewName.caseInsensitiveCompare("Floating") == .orderedSame, let flPlane {
                searchRoot = flPlane
            } else if viewName.caseInsensitiveCompare("Background") == .orderedSame, let bgPlane {
                searchRoot = bgPlane
            } else {
                searchRoot = stage.rootLayer
            }

            let matches = findLayers(named: layerName, under: searchRoot).filter { layer in
                layer !== bgPlane && layer !== flPlane && layer !== stage.rootLayer
            }
            for layer in matches {
                targets.append(
                    PropertyTarget(
                        layer: layer,
                        keyPath: keyPath,
                        sleepValue: sleepVal,
                        lockValue: lockVal,
                        homeValue: homeVal
                    )
                )
            }
        }
        propertyTargets = targets
    }

    private func findLayers(named targetName: String, under root: CALayer) -> [CALayer] {
        var found: [CALayer] = []
        if root.name?.caseInsensitiveCompare(targetName) == .orderedSame {
            found.append(root)
        }
        for sub in root.sublayers ?? [] {
            found.append(contentsOf: findLayers(named: targetName, under: sub))
        }
        return found
    }

    private func numericValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}
