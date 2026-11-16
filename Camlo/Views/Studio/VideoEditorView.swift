//
//  VideoEditorView.swift
//  Camlo · 开幕
//
//  Zero-threshold Video & Live Photo Dynamic Lock Screen Studio.
//  Extracts Jetsam-safe 9:16 JPEG frame sequences from MP4/MOV or PHLivePhoto and compiles
//  native CAKeyframeAnimation CAML loops (Ping-Pong or Standard Loop) with optional particles.
//

import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import UIKit

struct VideoEditorView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var vault = TendiesVaultStore.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared

    @State private var titleText: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var sourceVideoURL: URL?

    @State private var targetFPS: Int = 18
    @State private var maxDuration: Double = 5.0
    @State private var highQuality: Bool = true
    @State private var loopStyle: VideoLoopStyle = .pingPong
    @State private var unlockZoomScale: Double = 1.04
    @State private var dimInSleepMode: Bool = true
    @State private var renderAboveClock: Bool = false
    @State private var particlePreset: ParticlePreset = .none
    @State private var enableGyroParallax: Bool = false
    @State private var gyroIntensity: Double = 0.55
    @State private var posterStyle: PosterStyleSpec = PosterStyleSpec()
    @State private var canvasProfile: CanvasDisplayProfile = CamloDevice.isDuoFoldable ? .duoDualScreen : .standardPhone
    @State private var previewDuoSurface: DuoScreenSurface = .outerCover
    @State private var showHomeScreenPreview: Bool = false
    @State private var paletteMetrics: WallpaperPaletteMetrics? = nil

    @State private var extractedSequence: ExtractedVideoSequence?
    @State private var innerExtractedSequence: ExtractedVideoSequence?
    @State private var extractionProgress: Double = 0
    @State private var isExtracting: Bool = false
    @State private var isBuilding: Bool = false
    @State private var simulatorStage: LockScreenStage = .locked
    @State private var extractionTask: Task<Void, Never>? = nil
    @State private var sourcePosterImage: UIImage?
    @State private var cropFraming: CropFraming = .identity
    @State private var innerCropFraming: CropFraming = .identity
    @State private var showCropSheet: Bool = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showResultAlert = false
    @State private var showOpenPosterBoardAction = false

    private var activeCanvasSize: CGSize {
        switch canvasProfile {
        case .standardPhone:
            return CGSize(width: 390, height: 844)
        case .duoDualScreen:
            return previewDuoSurface.logicalSize
        }
    }

    private var activeSimulatorSequence: ExtractedVideoSequence? {
        if canvasProfile == .duoDualScreen && previewDuoSurface == .innerUnfolded {
            return innerExtractedSequence ?? extractedSequence
        }
        return extractedSequence
    }

    var body: some View {
        let isLandscapeSim = (canvasProfile == .duoDualScreen && previewDuoSurface == .innerUnfolded)
        ScrollView {
            VStack(spacing: 20) {
                Picker("", selection: $canvasProfile) {
                    ForEach(CanvasDisplayProfile.allCases) { profile in
                        Text(profile.shortBadgeTitle).tag(profile)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)

                if canvasProfile == .duoDualScreen {
                    Picker("", selection: $previewDuoSurface) {
                        ForEach(DuoScreenSurface.allCases) { surface in
                            Text(surface.localizedTitle).tag(surface)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 1. Live Animated Simulator
                LockScreenSimulatorView(
                    content: .video(
                        frames: activeSimulatorSequence?.previewImages ?? [],
                        fps: activeSimulatorSequence?.fps ?? targetFPS,
                        loopStyle: loopStyle,
                        unlockZoomScale: unlockZoomScale,
                        dimInSleep: dimInSleepMode,
                        renderAboveClock: renderAboveClock
                    ),
                    particlePreset: particlePreset,
                    stage: $simulatorStage,
                    phoneWidth: isLandscapeSim ? 316 : 236,
                    canvasSize: activeCanvasSize,
                    gyroEnabled: enableGyroParallax,
                    gyroIntensity: gyroIntensity,
                    posterStyle: posterStyle,
                    paletteMetrics: paletteMetrics,
                    showHomeScreenPreview: $showHomeScreenPreview
                )
                .padding(.top, 2)

                if sourcePosterImage != nil {
                    let activeFraming = isLandscapeSim ? innerCropFraming : cropFraming
                    Button {
                        showCropSheet = true
                        CamloHaptics.selection()
                    } label: {
                        Label(
                            activeFraming.isIdentity
                                ? (isLandscapeSim
                                    ? Bi("裁剪内屏 4:3 横屏画面", "Crop Duo Inner Landscape")
                                    : Bi("裁剪与挪动人物位置", "Crop & Reposition Subject"))
                                : Bi("已调整裁剪位置 · 点击微调", "Framing Adjusted · Tap to Edit"),
                            systemImage: "crop"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }

                // 2. Source Selection Card (Photos / Live Photo / Files / Demo)
                sourcePickerSection

                // 3. Frame Extraction & Playback Controls
                playbackAndQualitySection

                // 4. Layer & Particle Settings
                layerAndParticleSection

                // 5. 3D Gyroscope Parallax & Smart Poster Style
                PosterStyleSectionView(
                    enableGyroParallax: $enableGyroParallax,
                    gyroIntensity: $gyroIntensity,
                    posterStyle: $posterStyle,
                    showHomeScreenPreview: $showHomeScreenPreview,
                    paletteMetrics: paletteMetrics,
                    gyroSectionTitle: Bi("4. 陀螺仪 3D 裸眼视差 (ParameterizedCA)", "4. 3D Gyroscope Parallax (ParameterizedCA)"),
                    styleSectionTitle: Bi("5. 智能时钟配色字体 & 主屏柔焦配套", "5. Smart Clock Style & Home Screen Pairing")
                )

                // Title Input
                HStack(spacing: 10) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(.secondary)
                    TextField(Bi("给动态壁纸起个名字", "Motion Wallpaper Title"), text: $titleText)
                        .textInputAutocapitalization(.words)
                }
                .padding(13)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                // 6. Action Buttons
                outputActionButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Bi("动态视频 / 实况锁屏", "Video & Live Lock"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie, .audiovisualContent],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let first = urls.first else { return }
                let hasScope = first.startAccessingSecurityScopedResource()
                let ext = first.pathExtension.isEmpty ? "mp4" : first.pathExtension
                let localCopy = URL.temporaryDirectory.appendingPathComponent("camlo_file_\(UUID().uuidString).\(ext)")
                try? FileManager.default.removeItem(at: localCopy)
                do {
                    try FileManager.default.copyItem(at: first, to: localCopy)
                    if hasScope { first.stopAccessingSecurityScopedResource() }
                    let suggested = first.deletingPathExtension().lastPathComponent
                    Task {
                        await activateImportedVideo(url: localCopy, suggestedTitle: suggested)
                    }
                } catch {
                    if hasScope { first.stopAccessingSecurityScopedResource() }
                    presentError(error.localizedDescription)
                }
            case .failure(let error):
                presentError(error.localizedDescription)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            pickerItem = nil
            handlePhotosPickerSelection(newItem)
        }
        .onChange(of: targetFPS) { _, _ in
            if !isBuilding, let url = sourceVideoURL { runExtraction(from: url) }
        }
        .onChange(of: maxDuration) { _, _ in
            if !isBuilding, let url = sourceVideoURL { runExtraction(from: url) }
        }
        .onChange(of: highQuality) { _, _ in
            if !isBuilding, let url = sourceVideoURL { runExtraction(from: url) }
        }
        .onChange(of: canvasProfile) { _, _ in
            if !isBuilding, let url = sourceVideoURL { runExtraction(from: url) }
        }
        .alert(alertTitle, isPresented: $showResultAlert) {
            if showOpenPosterBoardAction {
                Button(Bi("立即注销桌面生效 (推荐)", "Respring Now to Reload (Recommended)")) {
                    bridge.triggerRespring()
                }
                Button(Bi("打开 PosterBoard (在后台上滑划掉)", "Open PosterBoard (Swipe Up to Close)")) {
                    CamloShare.openPosterBoardApp()
                }
            }
            Button(Bi("稍后手动刷新", "Later"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .fullScreenCover(isPresented: $showCropSheet) {
            if let poster = sourcePosterImage {
                let isInnerTarget = (canvasProfile == .duoDualScreen && previewDuoSurface == .innerUnfolded)
                LockScreenCropSheet(
                    title: isInnerTarget
                        ? Bi("调整 iPhone Duo 内展开画面", "Crop Duo Inner Canvas")
                        : Bi("调整实况 / 视频画面位置", "Crop Video & Live Photo"),
                    image: poster,
                    initialFraming: isInnerTarget ? innerCropFraming : cropFraming,
                    canvasSize: activeCanvasSize
                ) { newFraming, _ in
                    if isInnerTarget {
                        if newFraming != innerCropFraming {
                            innerCropFraming = newFraming
                            if let url = sourceVideoURL {
                                runExtraction(from: url)
                            }
                        }
                    } else if newFraming != cropFraming {
                        cropFraming = newFraming
                        if let url = sourceVideoURL {
                            runExtraction(from: url, framing: newFraming)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var sourcePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Bi("1. 导入视频或实况照片", "1. Select Video or Live Photo"))
                .font(.headline)

            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .any(of: [.videos, .livePhotos])
                ) {
                    VStack(spacing: 6) {
                        Image(systemName: "livephoto.play")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                        Text(Bi("相册视频 / 实况", "Photos / Live Photo"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())

                Button {
                    showFileImporter = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "folder.fill.badge.plus")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                        Text(Bi("从「文件」选视频", "Import MP4 / MOV"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())
            }

            // Instant Procedural Motion Demo Button
            Button {
                generateBuiltInAuroraMotionDemo()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .foregroundStyle(Color.accentColor)
                    Text(Bi("没有现成素材？点此一键生成「流光极光」动态样片", "No clip handy? Generate 'Aurora Flow' motion demo"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(CamloTapButtonStyle())

            if isExtracting {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(Bi("正在智能裁切与提取高清序列帧…", "Extracting 9:16 Retina sequence…"))
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text("\(Int((extractionProgress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: extractionProgress)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let seq = extractedSequence {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(Bi(
                        "已就绪：共 \(seq.frameJPEGs.count) 帧 · \(String(format: "%.1f", seq.durationSeconds)) 秒 · \(seq.fps) FPS (\(seq.pixelWidth)×\(seq.pixelHeight))",
                        "Ready: \(seq.frameJPEGs.count) frames · \(String(format: "%.1f", seq.durationSeconds))s @ \(seq.fps) FPS (\(seq.pixelWidth)×\(seq.pixelHeight))"
                    ))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    Spacer()
                    if sourcePosterImage != nil {
                        Button(Bi("裁剪挪位", "Crop")) {
                            showCropSheet = true
                            CamloHaptics.selection()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(CamloTapButtonStyle())
                    }
                }
                .padding(11)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var playbackAndQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Bi("2. 循环方式与帧率策略", "2. Loop Mode & Frame Budget"))
                .font(.headline)

            VStack(spacing: 14) {
                Picker(Bi("循环模式", "Loop Style"), selection: $loopStyle) {
                    ForEach(VideoLoopStyle.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(Bi("目标帧率", "Target FPS"))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("FPS", selection: $targetFPS) {
                        Text("12 FPS").tag(12)
                        Text("18 FPS").tag(18)
                        Text("24 FPS").tag(24)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }

                HStack {
                    Text(Bi("最长截取", "Max Length"))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("Duration", selection: $maxDuration) {
                        Text("3s").tag(3.0)
                        Text("5s").tag(5.0)
                        Text("8s").tag(8.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                Toggle(isOn: $highQuality) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Bi("高清画质（自适应 ≤540×1170）", "HD Resolution (Adaptive ≤540×1170)"))
                            .font(.subheadline.weight(.medium))
                        Text(Bi("自动控制在 40 帧内防止系统杀后台；关闭则用 360×780 省内存模式", "Caps at 40 frames to prevent Jetsam; turn off for 360×780 fast mode"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let src = sourceVideoURL {
                    Button {
                        runExtraction(from: src)
                    } label: {
                        Label(Bi("按当前帧率与时长重新提取画面", "Re-extract with Updated Settings"), systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(CamloTapButtonStyle())
                    .disabled(isExtracting)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var layerAndParticleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Bi("3. 解锁景深与粒子叠加", "3. Depth & Particle FX"))
                .font(.headline)

            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    HStack {
                        Text(Bi("解锁瞬间微推镜头缩放", "Unlock Push-In Zoom"))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.0f%%", unlockZoomScale * 100))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $unlockZoomScale, in: 1.00...1.12, step: 0.01)
                }

                Toggle(Bi("熄屏常显 (AOD) 自动柔和压暗", "Auto-Dim in Always-On Display"), isOn: $dimInSleepMode)
                    .font(.subheadline.weight(.medium))

                Toggle(isOn: $renderAboveClock) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Bi("画面置于时钟前景层 (Floating.ca)", "Render in Floating Layer (Above Clock)"))
                            .font(.subheadline.weight(.medium))
                        Text(Bi("默认关闭以保持时间清晰可读", "Keep off unless full-bleed clock cover is desired"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ParticlePreset.allCases) { p in
                        let active = (particlePreset == p)
                        Button {
                            particlePreset = p
                            CamloHaptics.selection()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: p.symbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(active ? .white : p.accentColor)
                                Text(p.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(active ? .white : .primary)
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(active ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(CamloTapButtonStyle())
                    }
                }
            }

            Text(particlePreset.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var outputActionButtons: some View {
        let ready = (extractedSequence != nil && !isExtracting && !isBuilding)
        return VStack(spacing: 10) {
            Button {
                buildAndApplyVideo()
            } label: {
                HStack(spacing: 8) {
                    if isBuilding {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 17, weight: .bold))
                    }
                    Text(Bi("一键应用到锁屏 (免电脑直写)", "1-Tap Apply to Lock Screen"))
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color(red: 0.16, green: 0.56, blue: 0.98)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(CamloTapButtonStyle())
            .disabled(!ready)

            HStack(spacing: 10) {
                Button {
                    buildAndExportVideo()
                } label: {
                    Label(Bi("导出 .tendies 分享", "Export .tendies"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(!ready)

                Button {
                    buildVideoToVaultOnly()
                } label: {
                    Label(Bi("存入金库", "Save to Vault"), systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(!ready)
            }
        }
    }

    // MARK: - Logic

    private func handlePhotosPickerSelection(_ item: PhotosPickerItem) {
        isExtracting = true
        extractionProgress = 0.05
        Task {
            do {
                if let movie = try? await item.loadTransferable(type: CamloPickedMovieFile.self) {
                    await activateImportedVideo(url: movie.url, suggestedTitle: Bi("动态锁屏", "Motion Lock"))
                    return
                }
                if let live = try? await item.loadTransferable(type: PHLivePhoto.self) {
                    let pairedURL = try await VideoFrameExtractor.extractPairedVideoURL(from: live)
                    await activateImportedVideo(url: pairedURL, suggestedTitle: Bi("实况动态锁屏", "Live Motion Lock"))
                    return
                }
                if let rawData = try? await item.loadTransferable(type: Data.self), !rawData.isEmpty {
                    let header = String(decoding: rawData.prefix(24), as: UTF8.self)
                    let ext = header.contains("ftypqt") ? "mov" : "mp4"
                    let dst = URL.temporaryDirectory.appendingPathComponent("camlo_raw_\(UUID().uuidString).\(ext)")
                    try? FileManager.default.removeItem(at: dst)
                    try rawData.write(to: dst, options: .atomic)
                    await activateImportedVideo(url: dst, suggestedTitle: Bi("动态锁屏", "Motion Lock"))
                    return
                }
                await MainActor.run {
                    isExtracting = false
                    presentError(VideoExtractorError.unreadableVideoTrack.localizedDescription)
                }
            } catch {
                await MainActor.run {
                    isExtracting = false
                    presentError(error.localizedDescription)
                }
            }
        }
    }

    private func activateImportedVideo(url: URL, suggestedTitle: String) async {
        let poster = try? await VideoFrameExtractor.extractPosterFrame(from: url)
        await MainActor.run {
            sourceVideoURL = url
            sourcePosterImage = poster
            cropFraming = .identity
            innerCropFraming = .identity
            innerExtractedSequence = nil
            if titleText.isEmpty { titleText = suggestedTitle }
            runExtraction(from: url, framing: .identity)
            if let poster, poster.needsInteractiveCropSuggestion(targetAspect: activeCanvasSize.width / max(activeCanvasSize.height, 1)) {
                showCropSheet = true
            }
        }
    }

    private func runExtraction(from url: URL, framing: CropFraming? = nil) {
        extractionTask?.cancel()
        isExtracting = true
        extractionProgress = 0
        let fps = targetFPS
        let maxDur = maxDuration
        let hq = highQuality
        let profile = canvasProfile
        let outerFraming = framing ?? cropFraming
        let innerFramingCopy = innerCropFraming

        extractionTask = Task {
            do {
                if profile == .duoDualScreen {
                    let seqOuter = try await VideoFrameExtractor.extractSequence(
                        from: url,
                        targetFPS: fps,
                        maxDurationSeconds: maxDur,
                        highQuality: hq,
                        framing: outerFraming,
                        targetCanvasSize: DuoScreenSurface.outerCover.videoPixelSize,
                        overrideMaxFrames: 18
                    ) { prog in
                        Task { @MainActor in
                            self.extractionProgress = prog * 0.5
                        }
                    }
                    guard !Task.isCancelled else { return }
                    let seqInner = try await VideoFrameExtractor.extractSequence(
                        from: url,
                        targetFPS: fps,
                        maxDurationSeconds: maxDur,
                        highQuality: hq,
                        framing: innerFramingCopy,
                        targetCanvasSize: DuoScreenSurface.innerUnfolded.videoPixelSize,
                        overrideMaxFrames: 18
                    ) { prog in
                        Task { @MainActor in
                            self.extractionProgress = 0.5 + prog * 0.5
                        }
                    }
                    guard !Task.isCancelled else { return }
                    let analyzedPalette = await Task.detached(priority: .userInitiated) {
                        seqOuter.previewImages.first.map { PosterStyleGenerator.analyzePalette(of: $0) }
                    }.value
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        self.extractedSequence = seqOuter
                        self.innerExtractedSequence = seqInner
                        self.paletteMetrics = analyzedPalette
                        self.isExtracting = false
                        CamloHaptics.notify(.success)
                    }
                    return
                }

                let seq = try await VideoFrameExtractor.extractSequence(
                    from: url,
                    targetFPS: fps,
                    maxDurationSeconds: maxDur,
                    highQuality: hq,
                    framing: outerFraming
                ) { prog in
                    Task { @MainActor in
                        self.extractionProgress = prog
                    }
                }
                guard !Task.isCancelled else { return }
                let analyzedPalette = await Task.detached(priority: .userInitiated) {
                    seq.previewImages.first.map { PosterStyleGenerator.analyzePalette(of: $0) }
                }.value
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.extractedSequence = seq
                    self.innerExtractedSequence = nil
                    self.paletteMetrics = analyzedPalette
                    self.isExtracting = false
                    CamloHaptics.notify(.success)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.isExtracting = false
                    presentError(error.localizedDescription)
                }
            }
        }
    }

    private func generateBuiltInAuroraMotionDemo() {
        isExtracting = true
        extractionProgress = 0
        Task.detached(priority: .userInitiated) {
            let frameCount = 24
            let size = CGSize(width: 540, height: 1170)
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 1.0
            let cs = CGColorSpaceCreateDeviceRGB()

            var jpegs: [Data] = []
            var previews: [UIImage] = []

            for i in 0..<frameCount {
                let phase = Double(i) / Double(frameCount - 1)
                let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
                    let cg = ctx.cgContext
                    let bg = CGGradient(colorsSpace: cs, colors: [
                        CGColor(red: 0.03, green: 0.05, blue: 0.14, alpha: 1),
                        CGColor(red: 0.08, green: 0.14, blue: 0.30, alpha: 1),
                        CGColor(red: 0.04, green: 0.06, blue: 0.16, alpha: 1)
                    ] as CFArray, locations: [0, 0.55, 1])!
                    cg.drawLinearGradient(bg, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

                    let orb1 = CGPoint(
                        x: size.width * (0.30 + 0.40 * phase),
                        y: size.height * (0.36 + 0.12 * sin(phase * .pi * 2))
                    )
                    let g1 = CGGradient(colorsSpace: cs, colors: [
                        CGColor(red: 0.20, green: 0.95, blue: 0.78, alpha: 0.78),
                        CGColor(red: 0.38, green: 0.36, blue: 0.98, alpha: 0.38),
                        CGColor(red: 0, green: 0, blue: 0, alpha: 0)
                    ] as CFArray, locations: [0, 0.48, 1])!
                    cg.drawRadialGradient(g1, startCenter: orb1, startRadius: 0, endCenter: orb1, endRadius: 420, options: [])

                    let orb2 = CGPoint(
                        x: size.width * (0.72 - 0.38 * phase),
                        y: size.height * (0.64 - 0.14 * cos(phase * .pi * 2))
                    )
                    let g2 = CGGradient(colorsSpace: cs, colors: [
                        CGColor(red: 0.94, green: 0.36, blue: 0.72, alpha: 0.68),
                        CGColor(red: 0.42, green: 0.20, blue: 0.88, alpha: 0.26),
                        CGColor(red: 0, green: 0, blue: 0, alpha: 0)
                    ] as CFArray, locations: [0, 0.5, 1])!
                    cg.drawRadialGradient(g2, startCenter: orb2, startRadius: 0, endCenter: orb2, endRadius: 390, options: [])
                }
                if let d = img.jpegData(compressionQuality: 0.80) {
                    jpegs.append(d)
                    previews.append(img)
                }
            }

            let seq = ExtractedVideoSequence(
                frameJPEGs: jpegs,
                previewImages: previews,
                fps: 16,
                durationSeconds: 1.5,
                pixelWidth: 540,
                pixelHeight: 1170
            )
            let analyzedPalette = previews.first.map { PosterStyleGenerator.analyzePalette(of: $0) }
            await MainActor.run {
                self.sourceVideoURL = nil
                self.sourcePosterImage = nil
                self.cropFraming = .identity
                self.titleText = Bi("流光极光", "Aurora Flow")
                self.loopStyle = .pingPong
                self.particlePreset = .starlight
                self.extractedSequence = seq
                self.paletteMetrics = analyzedPalette
                self.isExtracting = false
                CamloHaptics.notify(.success)
            }
        }
    }

    private func makeVideoSpec() -> VideoCompileSpec? {
        guard let seq = extractedSequence else { return nil }
        return VideoCompileSpec(
            title: titleText,
            sequence: seq,
            loopStyle: loopStyle,
            unlockZoomScale: unlockZoomScale,
            dimInSleepMode: dimInSleepMode,
            renderAboveClock: renderAboveClock,
            particlePreset: particlePreset,
            enableGyroParallax: enableGyroParallax,
            gyroIntensity: gyroIntensity,
            posterStyle: posterStyle,
            canvasProfile: canvasProfile,
            innerSequence: (canvasProfile == .duoDualScreen) ? innerExtractedSequence : nil
        )
    }

    private func buildAndApplyVideo() {
        guard let spec = makeVideoSpec() else { return }
        isBuilding = true
        Task { @MainActor in
            defer { isBuilding = false }
            do {
                let item = try vault.createVideoPackage(spec: spec)
                let res = bridge.applyTendiesItems([item])
                if res.0 {
                    CamloHaptics.notify(.success)
                    showOpenPosterBoardAction = true
                    alertTitle = Bi("已写入系统锁屏画廊", "Motion Wallpaper Applied")
                    alertMessage = Bi(
                        "作品「\(item.title)」已写入系统壁纸库（不在「照片」里！）。\n\n1. 点击「立即注销桌面生效」（或打开 PosterBoard 后在后台上滑划掉）刷新系统缓存；\n2. 长按锁屏点击「+」号，在「专为 iPhone 设计的墙纸」（系统默认粉色壁纸右侧第 2 张起）或底部的「收藏」横向栏里即可找到你的新壁纸！",
                        "\"\(item.title)\" is injected into PosterBoard (not under Photos). Tap 'Respring Now' (or swipe away PosterBoard in App Switcher), then long-press Lock Screen -> '+' and check the device wallpaper row (card #2 next to default) or the bottom 'Collections' section!"
                    )
                    showResultAlert = true
                } else {
                    CamloHaptics.notify(.warning)
                    showOpenPosterBoardAction = false
                    alertTitle = Bi("已存入金库（直写暂未就绪）", "Saved to Vault")
                    alertMessage = "\(res.1)\n\n" + Bi("动态壁纸已完整编译保存在金库中，可直接导出 .tendies 分享。", "Saved in Vault and ready for .tendies export.")
                    showResultAlert = true
                }
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    private func buildAndExportVideo() {
        guard let spec = makeVideoSpec() else { return }
        isBuilding = true
        Task { @MainActor in
            defer { isBuilding = false }
            do {
                let item = try vault.createVideoPackage(spec: spec)
                let url = try vault.exportTendiesFile(for: item)
                CamloHaptics.notify(.success)
                CamloShare.presentShareSheet(for: url)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    private func buildVideoToVaultOnly() {
        guard let spec = makeVideoSpec() else { return }
        isBuilding = true
        Task { @MainActor in
            defer { isBuilding = false }
            do {
                let item = try vault.createVideoPackage(spec: spec)
                CamloHaptics.notify(.success)
                showOpenPosterBoardAction = false
                alertTitle = Bi("已存入壁纸金库", "Saved to Vault")
                alertMessage = Bi("「\(item.title)」已保存至壁纸金库。", "\"\(item.title)\" saved to Vault.")
                showResultAlert = true
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    private func presentError(_ msg: String) {
        CamloHaptics.notify(.error)
        showOpenPosterBoardAction = false
        alertTitle = Bi("提示", "Notice")
        alertMessage = msg
        showResultAlert = true
    }
}
