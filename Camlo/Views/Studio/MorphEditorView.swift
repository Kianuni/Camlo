//
//  MorphEditorView.swift
//  Camlo · 开幕
//
//  Zero-threshold Slide-to-Unlock Transformation Studio.
//  Supports 2–3 state images, 1-tap Vision AI foreground cutout for Clock Depth occlusion,
//  6 CAML state-machine presets, particle overlays, 1-tap Apply to PosterBoard, and .tendies export.
//

import SwiftUI
import PhotosUI
import Photos
import UIKit

private enum PickedMorphSlotMedia {
    case live(videoURL: URL, posterImage: UIImage, stillFallback: UIImage)
    case staticPhoto(UIImage)
}

struct MorphEditorView: View {
    private enum CropSlot: String, Identifiable {
        case lock, unlock, sleep, innerLock, innerUnlock
        var id: String { rawValue }
    }

    var initialDemo: BuiltInDemoPack? = nil

    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var vault = TendiesVaultStore.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared

    @State private var titleText: String = ""
    @State private var lockImage: UIImage?
    @State private var unlockImage: UIImage?
    @State private var sleepImage: UIImage?
    @State private var lockCutout: UIImage?
    @State private var unlockCutout: UIImage?

    @State private var lockPickerItem: PhotosPickerItem?
    @State private var unlockPickerItem: PhotosPickerItem?
    @State private var sleepPickerItem: PhotosPickerItem?

    @State private var rawLockImage: UIImage?
    @State private var rawUnlockImage: UIImage?
    @State private var rawSleepImage: UIImage?
    @State private var lockFraming: CropFraming = .identity
    @State private var unlockFraming: CropFraming = .identity
    @State private var sleepFraming: CropFraming = .identity
    @State private var activeCropSlot: CropSlot? = nil

    // Hybrid Live Photo / Short Video state per slot
    @State private var lockSourceVideoURL: URL?
    @State private var unlockSourceVideoURL: URL?
    @State private var lockStillFallbackImage: UIImage?
    @State private var unlockStillFallbackImage: UIImage?
    @State private var lockVideoPosterImage: UIImage?
    @State private var unlockVideoPosterImage: UIImage?
    @State private var lockLiveEnabled: Bool = false
    @State private var unlockLiveEnabled: Bool = false
    @State private var lockLiveSequence: ExtractedVideoSequence?
    @State private var unlockLiveSequence: ExtractedVideoSequence?
    @State private var lockLiveIsCompact: Bool = false
    @State private var unlockLiveIsCompact: Bool = false
    @State private var isExtractingLockLive: Bool = false
    @State private var isExtractingUnlockLive: Bool = false
    @State private var liveLoopStyle: VideoLoopStyle = .pingPong
    @State private var lockExtractionTask: Task<Void, Never>? = nil
    @State private var unlockExtractionTask: Task<Void, Never>? = nil

    @State private var selectedDemoID: String? = nil
    @State private var selectedPreset: MorphTransitionPreset = .curtainRise
    @State private var durationSeconds: Double = 0.72
    @State private var springBounce: Double = 0.28
    @State private var particlePreset: ParticlePreset = .none

    // Day/Night Dual Wallpaper (appearanceAware)
    @State private var enableDayNightMode: Bool = false
    @State private var previewNightMode: Bool = false
    @State private var nightLockImage: UIImage? = nil
    @State private var nightUnlockImage: UIImage? = nil
    @State private var nightLockCutout: UIImage? = nil
    @State private var nightUnlockCutout: UIImage? = nil
    @State private var nightLockPickerItem: PhotosPickerItem? = nil
    @State private var nightUnlockPickerItem: PhotosPickerItem? = nil
    @State private var nightParticlePreset: ParticlePreset = .starlight
    @State private var isSynthesizingNight: Bool = false
    @State private var isCuttingNightSubject: Bool = false

    // 3D Gyroscope Parallax (ParameterizedCA) & Smart Poster Style & iPhone Duo Dual Canvas
    @State private var enableGyroParallax: Bool = false
    @State private var gyroIntensity: Double = 0.65
    @State private var posterStyle: PosterStyleSpec = PosterStyleSpec()
    @State private var canvasProfile: CanvasDisplayProfile = CamloDevice.isDuoFoldable ? .duoDualScreen : .standardPhone
    @State private var previewDuoSurface: DuoScreenSurface = .outerCover
    @State private var innerLockImage: UIImage?
    @State private var innerUnlockImage: UIImage?
    @State private var rawInnerLockImage: UIImage?
    @State private var rawInnerUnlockImage: UIImage?
    @State private var innerLockCutout: UIImage?
    @State private var innerUnlockCutout: UIImage?
    @State private var innerLockPickerItem: PhotosPickerItem?
    @State private var innerUnlockPickerItem: PhotosPickerItem?
    @State private var innerLockFraming: CropFraming = .identity
    @State private var innerUnlockFraming: CropFraming = .identity
    @State private var showHomeScreenPreview: Bool = false
    @State private var dayPaletteMetrics: WallpaperPaletteMetrics? = nil
    @State private var nightPaletteMetrics: WallpaperPaletteMetrics? = nil

    @State private var simulatorStage: LockScreenStage = .locked
    @State private var isExtractingCutout = false
    @State private var isBuilding = false
    @State private var didSeedInitial = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showResultAlert = false
    @State private var showOpenPosterBoardAction = false

    private var isLockActivelyLive: Bool {
        lockLiveEnabled && lockSourceVideoURL != nil
    }

    private var isUnlockActivelyLive: Bool {
        unlockLiveEnabled && unlockSourceVideoURL != nil
    }

    private var needsCompactLiveBudget: Bool {
        (isLockActivelyLive && isUnlockActivelyLive)
            || sleepImage != nil
            || lockCutout != nil
            || unlockCutout != nil
            || enableDayNightMode
    }

    private var activeOuterPixelSize: CGSize {
        canvasProfile == .duoDualScreen
            ? DuoScreenSurface.outerCover.morphPixelSize
            : CAMLCompiler.retinaSize
    }

    private var activeCanvasLogicalSize: CGSize {
        canvasProfile == .duoDualScreen
            ? previewDuoSurface.logicalSize
            : CGSize(width: 390, height: 844)
    }

    private var isShowingInnerDuoSurface: Bool {
        canvasProfile == .duoDualScreen && previewDuoSurface == .innerUnfolded
    }

    private var isShowingNightInSimulator: Bool {
        enableDayNightMode && previewNightMode
    }

    private var simulatorLockImage: UIImage? {
        if isShowingInnerDuoSurface {
            let base = innerLockImage ?? lockImage
            if isShowingNightInSimulator, let base {
                return PosterStyleGenerator.synthesizeNightImage(from: base)
            }
            return base
        }
        return isShowingNightInSimulator ? (nightLockImage ?? lockImage) : lockImage
    }

    private var simulatorUnlockImage: UIImage? {
        if isShowingInnerDuoSurface {
            let base = innerUnlockImage ?? unlockImage
            if isShowingNightInSimulator, let base {
                return PosterStyleGenerator.synthesizeNightImage(from: base)
            }
            return base
        }
        return isShowingNightInSimulator ? (nightUnlockImage ?? unlockImage) : unlockImage
    }

    private var simulatorLockCutout: UIImage? {
        if isShowingInnerDuoSurface {
            return innerLockCutout
        }
        return isShowingNightInSimulator ? nightLockCutout : lockCutout
    }

    private var simulatorUnlockCutout: UIImage? {
        if isShowingInnerDuoSurface {
            return innerUnlockCutout
        }
        return isShowingNightInSimulator ? nightUnlockCutout : unlockCutout
    }

    private var simulatorParticlePreset: ParticlePreset {
        isShowingNightInSimulator ? nightParticlePreset : particlePreset
    }

    private var simulatorLockLiveFrames: [UIImage] {
        guard !isShowingInnerDuoSurface else { return [] }
        guard isLockActivelyLive, !(isShowingNightInSimulator && nightLockImage != nil) else {
            return []
        }
        return lockLiveSequence?.previewImages ?? []
    }

    private var simulatorUnlockLiveFrames: [UIImage] {
        guard !isShowingInnerDuoSurface else { return [] }
        guard isUnlockActivelyLive, !(isShowingNightInSimulator && nightUnlockImage != nil) else {
            return []
        }
        return unlockLiveSequence?.previewImages ?? []
    }

    private var activePaletteMetrics: WallpaperPaletteMetrics? {
        isShowingNightInSimulator ? (nightPaletteMetrics ?? dayPaletteMetrics) : dayPaletteMetrics
    }

    var body: some View {
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

                // 1. Live Interactive Lock Screen Simulator
                LockScreenSimulatorView(
                    content: .morph(
                        lockImage: simulatorLockImage,
                        unlockImage: simulatorUnlockImage,
                        sleepImage: sleepImage,
                        lockCutout: simulatorLockCutout,
                        unlockCutout: simulatorUnlockCutout,
                        lockLiveFrames: simulatorLockLiveFrames,
                        lockLiveFPS: lockLiveSequence?.fps ?? 14,
                        unlockLiveFrames: simulatorUnlockLiveFrames,
                        unlockLiveFPS: unlockLiveSequence?.fps ?? 14,
                        liveLoopStyle: liveLoopStyle,
                        preset: selectedPreset,
                        duration: durationSeconds,
                        bounce: springBounce
                    ),
                    particlePreset: simulatorParticlePreset,
                    stage: $simulatorStage,
                    phoneWidth: isShowingInnerDuoSurface ? 316 : 236,
                    canvasSize: activeCanvasLogicalSize,
                    gyroEnabled: enableGyroParallax,
                    gyroIntensity: gyroIntensity,
                    posterStyle: posterStyle,
                    paletteMetrics: activePaletteMetrics,
                    isDayNightEnabled: enableDayNightMode,
                    previewNightMode: $previewNightMode,
                    showHomeScreenPreview: $showHomeScreenPreview
                )
                .padding(.top, 2)

                // 2. Quick Sample Switcher Strip
                demoSamplerStrip

                // 3. Image Slots (Locked <-> Unlock + Optional Sleep)
                imageSelectionSection

                // 4. AI Foreground Depth Cutout (Clock Occlusion)
                depthCutoutSection

                // 5. Day/Night Dual Wallpaper (appearanceAware)
                dayNightDualSection

                // 6. Transition Preset & Physics Controls
                transitionPresetSection

                // 7. 3D Gyroscope Parallax & Smart Poster Style
                PosterStyleSectionView(
                    enableGyroParallax: $enableGyroParallax,
                    gyroIntensity: $gyroIntensity,
                    posterStyle: $posterStyle,
                    showHomeScreenPreview: $showHomeScreenPreview,
                    paletteMetrics: activePaletteMetrics,
                    gyroSectionTitle: Bi("3. 陀螺仪 3D 裸眼视差 (ParameterizedCA)", "3. 3D Gyroscope Parallax (ParameterizedCA)"),
                    styleSectionTitle: Bi("4. 智能时钟配色字体 & 主屏柔焦配套", "4. Smart Clock Style & Home Screen Pairing")
                )

                // 8. Particle FX & Naming
                particlesAndTitleSection

                // 9. Action Buttons
                outputActionButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Bi("滑动解锁变身", "Slide-to-Morph"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didSeedInitial else { return }
            didSeedInitial = true
            let pack = initialDemo ?? SampleArtGenerator.allDemos.first
            if let pack {
                applyDemoPack(pack, playPreview: false)
            }
        }
        .onChange(of: lockPickerItem) { _, newItem in
            guard let newItem else { return }
            lockPickerItem = nil
            handleSlotSelection(item: newItem, isLock: true)
        }
        .onChange(of: unlockPickerItem) { _, newItem in
            guard let newItem else { return }
            unlockPickerItem = nil
            handleSlotSelection(item: newItem, isLock: false)
        }
        .onChange(of: sleepPickerItem) { _, newItem in
            guard let newItem else { return }
            sleepPickerItem = nil
            Task {
                if let img = await loadPhoto(from: newItem) {
                    let fitted = autoreleasepool { img.aspectFilled(to: activeOuterPixelSize, framing: .identity) }
                    await MainActor.run {
                        rawSleepImage = img
                        sleepFraming = .identity
                        sleepImage = fitted
                        simulatorStage = .sleep
                        ensureLiveSequencesFitMemoryBudget()
                        CamloHaptics.impact(.light)
                        let outerAspect = canvasProfile == .duoDualScreen ? DuoScreenSurface.outerCover.aspectRatio : (390.0 / 844.0)
                        if img.needsInteractiveCropSuggestion(targetAspect: outerAspect) {
                            activeCropSlot = .sleep
                        }
                    }
                }
            }
        }
        .onChange(of: nightLockPickerItem) { _, newItem in
            guard let newItem else { return }
            nightLockPickerItem = nil
            handleNightPickerSelection(item: newItem, isLock: true)
        }
        .onChange(of: nightUnlockPickerItem) { _, newItem in
            guard let newItem else { return }
            nightUnlockPickerItem = nil
            handleNightPickerSelection(item: newItem, isLock: false)
        }
        .onChange(of: innerLockPickerItem) { _, newItem in
            guard let newItem else { return }
            innerLockPickerItem = nil
            handleInnerPhotoSelection(item: newItem, isLock: true)
        }
        .onChange(of: innerUnlockPickerItem) { _, newItem in
            guard let newItem else { return }
            innerUnlockPickerItem = nil
            handleInnerPhotoSelection(item: newItem, isLock: false)
        }
        .onChange(of: canvasProfile) { _, newProfile in
            if newProfile == .standardPhone {
                previewDuoSurface = .outerCover
            }
            let targetSize = activeOuterPixelSize
            if let rawL = rawLockImage {
                lockImage = autoreleasepool { rawL.aspectFilled(to: targetSize, framing: lockFraming) }
            }
            if let rawU = rawUnlockImage {
                unlockImage = autoreleasepool { rawU.aspectFilled(to: targetSize, framing: unlockFraming) }
            }
            if let rawS = rawSleepImage {
                sleepImage = autoreleasepool { rawS.aspectFilled(to: targetSize, framing: sleepFraming) }
            }
            lockCutout = nil
            unlockCutout = nil
        }
        .onChange(of: lockImage) { _, newImg in
            refreshDayPalette(for: newImg)
        }
        .onChange(of: nightLockImage) { _, newImg in
            refreshNightPalette(for: newImg)
        }
        .onChange(of: enableDayNightMode) { _, enabled in
            if enabled {
                ensureLiveSequencesFitMemoryBudget()
                if nightLockImage == nil && nightUnlockImage == nil && (lockImage != nil || unlockImage != nil) {
                    synthesizeNightPair(switchToNightPreview: true)
                } else {
                    refreshNightPalette(for: nightLockImage)
                }
            } else {
                previewNightMode = false
            }
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
        .fullScreenCover(item: $activeCropSlot) { slot in
            cropSheet(for: slot)
        }
    }

    // MARK: - Subviews

    private func presetThumbTile(_ image: UIImage) -> some View {
        Color.clear
            .frame(width: 22, height: 42)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }

    private var demoSamplerStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(Bi("内置获奖风光预设 (点选即刻切换)", "Built-in Landscape Presets (Tap to Load)"), systemImage: "mountain.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SampleArtGenerator.allDemos) { demo in
                        let isCurrent = (selectedDemoID == demo.id)
                        Button {
                            applyDemoPack(demo, playPreview: true)
                        } label: {
                            HStack(spacing: 9) {
                                HStack(spacing: 2) {
                                    if let lThumb = demo.lockThumbnail {
                                        presetThumbTile(lThumb)
                                    }
                                    if let uThumb = demo.unlockThumbnail {
                                        presetThumbTile(uThumb)
                                    }
                                }
                                .frame(width: (demo.lockThumbnail != nil && demo.unlockThumbnail != nil) ? 46 : 22, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(demo.categoryBadge)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(isCurrent ? .white.opacity(0.88) : Color.accentColor)
                                    Text(demo.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(isCurrent ? .white : .primary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isCurrent ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(CamloTapButtonStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var imageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Bi("1. 选择变身画面", "1. Choose Transformation Frames"),
                subtitle: Bi("支持照片、实况照片 (Live Photo) 与短视频，自动适配 9:16 比例并支持智能裁切", "Supports photos, Live Photos & clips with 9:16 Retina crop")
            )

            HStack(spacing: 10) {
                // Locked Image Card (Static / Live Photo / Video)
                PhotosPicker(selection: $lockPickerItem, matching: .any(of: [.images, .livePhotos, .videos])) {
                    photoSlotCard(
                        badge: Bi("锁屏常态", "Locked"),
                        symbol: "lock.fill",
                        image: lockImage,
                        hint: Bi("点此选照片 / 实况", "Pick Lock Media"),
                        isLiveActive: isLockActivelyLive,
                        isExtracting: isExtractingLockLive
                    )
                }
                .buttonStyle(CamloTapButtonStyle())

                // Swap Button
                Button {
                    guard lockImage != nil || unlockImage != nil || lockSourceVideoURL != nil || unlockSourceVideoURL != nil else { return }
                    let wasExtractingLock = isExtractingLockLive
                    let wasExtractingUnlock = isExtractingUnlockLive
                    lockExtractionTask?.cancel()
                    unlockExtractionTask?.cancel()
                    isExtractingLockLive = false
                    isExtractingUnlockLive = false
                    swap(&rawLockImage, &rawUnlockImage)
                    swap(&lockFraming, &unlockFraming)
                    swap(&lockImage, &unlockImage)
                    swap(&lockCutout, &unlockCutout)
                    swap(&lockSourceVideoURL, &unlockSourceVideoURL)
                    swap(&lockStillFallbackImage, &unlockStillFallbackImage)
                    swap(&lockVideoPosterImage, &unlockVideoPosterImage)
                    swap(&lockLiveEnabled, &unlockLiveEnabled)
                    swap(&lockLiveSequence, &unlockLiveSequence)
                    swap(&lockLiveIsCompact, &unlockLiveIsCompact)
                    if wasExtractingUnlock && isLockActivelyLive {
                        reextractLiveSequence(forLock: true)
                    }
                    if wasExtractingLock && isUnlockActivelyLive {
                        reextractLiveSequence(forLock: false)
                    }
                    CamloHaptics.selection()
                    replayUnlockPreview()
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(CamloTapButtonStyle())
                .accessibilityLabel(Bi("对调锁屏与解锁图片", "Swap Lock and Unlock media"))

                // Unlock Image Card (Static / Live Photo / Video)
                PhotosPicker(selection: $unlockPickerItem, matching: .any(of: [.images, .livePhotos, .videos])) {
                    photoSlotCard(
                        badge: Bi("解锁变身", "Unlock"),
                        symbol: "sparkles",
                        image: unlockImage,
                        hint: Bi("点此选照片 / 实况", "Pick Unlock Media"),
                        isLiveActive: isUnlockActivelyLive,
                        isExtracting: isExtractingUnlockLive
                    )
                }
                .buttonStyle(CamloTapButtonStyle())
            }

            HStack(spacing: 10) {
                Button {
                    activeCropSlot = .lock
                    CamloHaptics.selection()
                } label: {
                    Label(
                        lockFraming.isIdentity ? Bi("裁剪锁屏画面", "Crop Lock") : Bi("已裁剪锁屏画面", "Lock Cropped"),
                        systemImage: "crop"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        (lockFraming.isIdentity ? Color(.secondarySystemGroupedBackground) : Color.accentColor.opacity(0.14)),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .foregroundStyle(lockFraming.isIdentity ? Color.primary : Color.accentColor)
                    .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(rawLockImage == nil)

                Spacer()
                    .frame(width: 28)

                Button {
                    activeCropSlot = .unlock
                    CamloHaptics.selection()
                } label: {
                    Label(
                        unlockFraming.isIdentity ? Bi("裁剪解锁画面", "Crop Unlock") : Bi("已裁剪解锁画面", "Unlock Cropped"),
                        systemImage: "crop"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        (unlockFraming.isIdentity ? Color(.secondarySystemGroupedBackground) : Color.accentColor.opacity(0.14)),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .foregroundStyle(unlockFraming.isIdentity ? Color.primary : Color.accentColor)
                    .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(rawUnlockImage == nil)
            }

            if lockSourceVideoURL != nil || unlockSourceVideoURL != nil {
                liveMotionControlCard
            }

            // Optional Sleep / AOD Slot
            HStack(spacing: 12) {
                PhotosPicker(selection: $sleepPickerItem, matching: .images) {
                    HStack(spacing: 10) {
                        if let sleepImage {
                            Color.clear
                                .frame(width: 36, height: 48)
                                .overlay {
                                    Image(uiImage: sleepImage)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.secondary.opacity(0.14))
                                .frame(width: 36, height: 48)
                                .overlay(Image(systemName: "moon.zzz.fill").font(.caption).foregroundStyle(.secondary))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(Bi("熄屏常显专属图 (可选)", "Custom Sleep / AOD Image (Optional)"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(sleepImage == nil
                                 ? Bi("未设置时自动将锁屏图柔和压暗", "Auto-dims Lock image when unset")
                                 : Bi("已启用独立熄屏剪影画面", "Custom Sleep frame active"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "photo.badge.plus")
                            .foregroundStyle(Color.accentColor)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(CamloTapButtonStyle())

                if sleepImage != nil {
                    Button {
                        activeCropSlot = .sleep
                        CamloHaptics.selection()
                    } label: {
                        Image(systemName: "crop")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(sleepFraming.isIdentity ? Color.secondary : Color.accentColor)
                            .padding(6)
                            .background(Color.accentColor.opacity(sleepFraming.isIdentity ? 0.08 : 0.16), in: Circle())
                    }
                    .buttonStyle(CamloTapButtonStyle())
                    .accessibilityLabel(Bi("裁剪熄屏图", "Crop Sleep Image"))

                    Button {
                        rawSleepImage = nil
                        sleepFraming = .identity
                        sleepImage = nil
                        CamloHaptics.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if canvasProfile == .duoDualScreen {
                duoInnerMediaSection
            }
        }
    }

    private var duoInnerMediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(Bi("iPhone Duo 内展开屏画面（4:3 横屏 · 可选）", "Duo Inner Unfolded Media (4:3 · Optional)"), systemImage: "book.pages.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                if innerLockImage != nil || innerUnlockImage != nil {
                    Button(Bi("重置跟随外屏", "Clear")) {
                        rawInnerLockImage = nil
                        rawInnerUnlockImage = nil
                        innerLockImage = nil
                        innerUnlockImage = nil
                        innerLockCutout = nil
                        innerUnlockCutout = nil
                        innerLockFraming = .identity
                        innerUnlockFraming = .identity
                        CamloHaptics.selection()
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $innerLockPickerItem, matching: .images) {
                    duoInnerSlotTile(
                        title: Bi("内屏 · 锁屏画面", "Inner Lock"),
                        image: innerLockImage
                    )
                }
                .buttonStyle(CamloTapButtonStyle())

                PhotosPicker(selection: $innerUnlockPickerItem, matching: .images) {
                    duoInnerSlotTile(
                        title: Bi("内屏 · 解锁画面", "Inner Unlock"),
                        image: innerUnlockImage
                    )
                }
                .buttonStyle(CamloTapButtonStyle())
            }

            if rawInnerLockImage != nil || rawInnerUnlockImage != nil {
                HStack(spacing: 10) {
                    Button {
                        activeCropSlot = .innerLock
                        CamloHaptics.selection()
                    } label: {
                        Label(Bi("裁剪内屏锁屏", "Crop Inner Lock"), systemImage: "crop")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(CamloTapButtonStyle())
                    .disabled(rawInnerLockImage == nil)

                    Button {
                        activeCropSlot = .innerUnlock
                        CamloHaptics.selection()
                    } label: {
                        Label(Bi("裁剪内屏解锁", "Crop Inner Unlock"), systemImage: "crop")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(CamloTapButtonStyle())
                    .disabled(rawInnerUnlockImage == nil)
                }
            }

            Text(Bi("未单独选图时，系统会自动从外屏画面智能横屏延展适配", "When left empty, inner unfolded frames automatically adapt from outer screen media."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func duoInnerSlotTile(title: String, image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .aspectRatio(951.0 / 669.0, contentMode: .fit)
                if let image {
                    Color.clear
                        .aspectRatio(951.0 / 669.0, contentMode: .fit)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(Bi("选 4:3 横图", "Pick 4:3 Photo"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var liveMotionControlCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "livephoto.play")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text(Bi("实况动态 × 滑动变身融合控制", "Live Motion × Morph Blend"))
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if isLockActivelyLive && isUnlockActivelyLive {
                    Text(Bi("双路省内存模式", "Dual Compact"))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.16), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            if lockSourceVideoURL != nil {
                liveSlotControlRow(
                    title: Bi("锁屏常态", "Locked Slot"),
                    sequence: lockLiveSequence,
                    isLive: lockLiveEnabled,
                    isExtracting: isExtractingLockLive
                ) { enabled in
                    setSlotLiveEnabled(enabled, forLock: true)
                }
            }

            if unlockSourceVideoURL != nil {
                liveSlotControlRow(
                    title: Bi("解锁变身", "Unlock Slot"),
                    sequence: unlockLiveSequence,
                    isLive: unlockLiveEnabled,
                    isExtracting: isExtractingUnlockLive
                ) { enabled in
                    setSlotLiveEnabled(enabled, forLock: false)
                }
            }

            if isLockActivelyLive || isUnlockActivelyLive {
                HStack(spacing: 8) {
                    Text(Bi("循环节奏", "Loop Mode"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    ForEach(VideoLoopStyle.allCases) { style in
                        let active = (liveLoopStyle == style)
                        Button {
                            liveLoopStyle = style
                            CamloHaptics.selection()
                        } label: {
                            Text(style.title)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    active ? Color.accentColor : Color.secondary.opacity(0.12),
                                    in: Capsule()
                                )
                                .foregroundStyle(active ? .white : .primary)
                        }
                        .buttonStyle(CamloTapButtonStyle())
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func liveSlotControlRow(
        title: String,
        sequence: ExtractedVideoSequence?,
        isLive: Bool,
        isExtracting: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                if isExtracting {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text(Bi("正在按安全内存抽帧…", "Extracting Jetsam-safe frames…"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if isLive, let seq = sequence {
                    Text("\(seq.frameJPEGs.count)f · \(seq.fps) FPS · \(seq.pixelWidth)×\(seq.pixelHeight)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(Bi("当前仅保留静态视网膜底图", "Using static high-res frame"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            HStack(spacing: 6) {
                Button {
                    onToggle(true)
                } label: {
                    Text(Bi("实况动态", "LIVE"))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isLive ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(isLive ? .white : .primary)
                }
                .buttonStyle(CamloTapButtonStyle())

                Button {
                    onToggle(false)
                } label: {
                    Text(Bi("静态高清", "Static HD"))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(!isLive ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(!isLive ? Color(.systemBackground) : .primary)
                }
                .buttonStyle(CamloTapButtonStyle())
            }
        }
    }

    private func photoSlotCard(
        badge: String,
        symbol: String,
        image: UIImage?,
        hint: String,
        isLiveActive: Bool = false,
        isExtracting: Bool = false
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 158)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 158)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "plus.viewfinder")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                            Text(hint)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    )
            }

            if isExtracting || isLiveActive {
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            if isExtracting {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                                Text(Bi("抽帧中", "Loading"))
                            } else {
                                Image(systemName: "livephoto.play")
                                Text(Bi("LIVE 实况", "LIVE"))
                            }
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(.black.opacity(0.62), in: Capsule())
                        .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
            }

            LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                .frame(height: 64)

            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                Text(badge)
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var depthCutoutSection: some View {
        let hasCutout = (lockCutout != nil || unlockCutout != nil)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hasCutout ? Color.green.opacity(0.16) : Color.accentColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: hasCutout ? "person.crop.rectangle.stack.fill" : "person.and.background.dotted")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hasCutout ? .green : Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(Bi("AI 主体抠图破框遮挡时钟", "AI Subject Depth Cutout"))
                            .font(.system(size: 15, weight: .semibold))
                        if hasCutout {
                            Text(Bi("已生效", "Active"))
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(Bi("利用神经网络分离前景主体写入 Floating.ca，真实遮挡锁屏时间下半部", "Places Vision foreground mask in Floating.ca in front of Lock Screen Clock"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    runVisionSubjectCutout()
                } label: {
                    HStack(spacing: 6) {
                        if isExtractingCutout {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles.tv")
                        }
                        Text(isExtractingCutout
                             ? Bi("正在神经网络抠图…", "Extracting Subject…")
                             : Bi("一键智能提取前景主体", "Extract Subject Depth"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(isExtractingCutout || (lockImage == nil && unlockImage == nil))

                if hasCutout {
                    Button {
                        lockCutout = nil
                        unlockCutout = nil
                        CamloHaptics.selection()
                    } label: {
                        Text(Bi("关闭破框", "Clear"))
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dayNightDualSection: some View {
        let hasNightCutout = (nightLockCutout != nil || nightUnlockCutout != nil)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(enableDayNightMode ? Color.indigo.opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(enableDayNightMode ? .indigo : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Bi("昼夜双生壁纸 (自动响应深色模式)", "Day/Night Dual Appearance"))
                        .font(.system(size: 15, weight: .semibold))
                    Text(Bi("同时编译日间与夜间 CAML 包（appearanceAware），随系统深色模式自动切换", "Compiles default & dark variants into Wallpaper.plist for automatic iOS Dark Mode switching"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $enableDayNightMode.animation(.spring(response: 0.35, dampingFraction: 0.85)))
                    .labelsHidden()
                    .tint(.indigo)
            }

            if enableDayNightMode {
                Divider()

                Button {
                    synthesizeNightPair(switchToNightPreview: true)
                } label: {
                    HStack(spacing: 7) {
                        if isSynthesizingNight {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "wand.and.stars.inverse")
                        }
                        Text(isSynthesizingNight
                             ? Bi("正在智能调色夜间版…", "Synthesizing Moonlight Grade…")
                             : Bi("一键智能月色夜景调色", "Auto Moonlight Night Grade"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .foregroundStyle(.indigo)
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(isSynthesizingNight || (lockImage == nil && unlockImage == nil))

                HStack(spacing: 10) {
                    PhotosPicker(selection: $nightLockPickerItem, matching: .images) {
                        photoSlotCard(
                            badge: Bi("夜间 · 锁屏", "Night Lock"),
                            symbol: "moon.stars.fill",
                            image: nightLockImage,
                            hint: Bi("选自定义夜景", "Pick Night Lock")
                        )
                    }
                    .buttonStyle(CamloTapButtonStyle())

                    PhotosPicker(selection: $nightUnlockPickerItem, matching: .images) {
                        photoSlotCard(
                            badge: Bi("夜间 · 解锁", "Night Unlock"),
                            symbol: "sparkles",
                            image: nightUnlockImage,
                            hint: Bi("选夜间解锁图", "Pick Night Unlock")
                        )
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }

                HStack(spacing: 10) {
                    Button {
                        runNightVisionSubjectCutout()
                    } label: {
                        HStack(spacing: 6) {
                            if isCuttingNightSubject {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "person.and.background.dotted")
                            }
                            Text(isCuttingNightSubject
                                 ? Bi("正在提取夜间主体…", "Extracting Night Subject…")
                                 : Bi("一键提取夜间主体破框", "Extract Night Subject Depth"))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(.indigo)
                    }
                    .buttonStyle(CamloTapButtonStyle())
                    .disabled(isCuttingNightSubject || ((nightLockImage ?? lockImage) == nil && (nightUnlockImage ?? unlockImage) == nil))

                    if hasNightCutout {
                        Button {
                            nightLockCutout = nil
                            nightUnlockCutout = nil
                            CamloHaptics.selection()
                        } label: {
                            Text(Bi("关闭夜间破框", "Clear Night"))
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(CamloTapButtonStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(Bi("夜间专属粒子氛围", "Night Particle FX"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ParticlePreset.allCases) { p in
                                let active = (nightParticlePreset == p)
                                Button {
                                    nightParticlePreset = p
                                    previewNightMode = true
                                    CamloHaptics.selection()
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: p.symbol)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(active ? .white : p.accentColor)
                                        Text(p.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(active ? .white : .primary)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(active ? Color.indigo : Color(.tertiarySystemGroupedBackground))
                                    )
                                }
                                .buttonStyle(CamloTapButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var transitionPresetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Bi("2. 变身动画曲线", "2. Transformation Curve"),
                subtitle: Bi("点击任一预设即可在上方仿真锁屏实时演示", "Tap any preset to preview live in the simulator")
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(MorphTransitionPreset.allCases) { preset in
                    let isSelected = (selectedPreset == preset)
                    Button {
                        selectedPreset = preset
                        CamloHaptics.selection()
                        replayUnlockPreview()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: preset.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(preset.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isSelected ? .white : .primary)
                            Text(preset.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(isSelected ? .white.opacity(0.86) : .secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }
            }

            // Duration & Spring Sliders
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    HStack {
                        Text(Bi("过渡时长", "Transition Duration"))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.2fs", durationSeconds))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $durationSeconds, in: 0.35...1.40, step: 0.05)
                }

                VStack(spacing: 4) {
                    HStack {
                        Text(Bi("回弹张力", "Spring Bounce"))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int((springBounce * 100).rounded()))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $springBounce, in: 0.0...1.0, step: 0.05)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var particlesAndTitleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Bi("5. 粒子流光与命名", "5. Particle FX & Title"),
                subtitle: Bi("由原生 CAEmitterLayer 硬件加速渲染，熄屏时自动休眠零耗电", "Hardware-accelerated CAEmitterLayer; sleeps automatically in AOD")
            )

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
                            .contentShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(CamloTapButtonStyle())
                    }
                }
            }

            Text(particlePreset.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.secondary)
                TextField(Bi("给作品起个名字（如：破晓觉醒）", "Wallpaper Title (e.g. Dawn Awaken)"), text: $titleText)
                    .textInputAutocapitalization(.words)
            }
            .padding(13)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var outputActionButtons: some View {
        VStack(spacing: 10) {
            Button {
                buildAndApplyDirectly()
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
                        colors: [Color.accentColor, Color(red: 0.44, green: 0.32, blue: 0.96)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(.white)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(CamloTapButtonStyle())
            .disabled(isBuilding || isExtractingLockLive || isExtractingUnlockLive || lockImage == nil || unlockImage == nil)

            HStack(spacing: 10) {
                Button {
                    buildAndExportTendies()
                } label: {
                    Label(Bi("导出 .tendies 分享", "Export .tendies"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(isBuilding || isExtractingLockLive || isExtractingUnlockLive || lockImage == nil || unlockImage == nil)

                Button {
                    buildToVaultOnly()
                } label: {
                    Label(Bi("存入金库", "Save to Vault"), systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(CamloTapButtonStyle())
                .disabled(isBuilding || isExtractingLockLive || isExtractingUnlockLive || lockImage == nil || unlockImage == nil)
            }
        }
        .padding(.top, 4)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic Helpers

    private func applyDemoPack(_ demo: BuiltInDemoPack, playPreview: Bool) {
        let built = demo.buildImages()
        lockExtractionTask?.cancel()
        unlockExtractionTask?.cancel()
        isExtractingLockLive = false
        isExtractingUnlockLive = false
        lockSourceVideoURL = nil
        unlockSourceVideoURL = nil
        lockStillFallbackImage = nil
        unlockStillFallbackImage = nil
        lockVideoPosterImage = nil
        unlockVideoPosterImage = nil
        lockLiveEnabled = false
        unlockLiveEnabled = false
        lockLiveSequence = nil
        unlockLiveSequence = nil
        lockLiveIsCompact = false
        unlockLiveIsCompact = false

        selectedDemoID = demo.id
        titleText = demo.title
        rawLockImage = built.lock
        rawUnlockImage = built.unlock
        rawSleepImage = nil
        rawInnerLockImage = nil
        rawInnerUnlockImage = nil
        lockFraming = .identity
        unlockFraming = .identity
        sleepFraming = .identity
        innerLockFraming = .identity
        innerUnlockFraming = .identity
        lockImage = canvasProfile == .duoDualScreen ? built.lock.aspectFilled(to: activeOuterPixelSize) : built.lock
        unlockImage = canvasProfile == .duoDualScreen ? built.unlock.aspectFilled(to: activeOuterPixelSize) : built.unlock
        sleepImage = nil
        innerLockImage = nil
        innerUnlockImage = nil
        lockCutout = canvasProfile == .duoDualScreen ? nil : built.lockCutout
        unlockCutout = canvasProfile == .duoDualScreen ? nil : built.unlockCutout
        innerLockCutout = nil
        innerUnlockCutout = nil
        nightLockImage = nil
        nightUnlockImage = nil
        nightLockCutout = nil
        nightUnlockCutout = nil
        nightPaletteMetrics = nil
        selectedPreset = demo.recommendedPreset
        particlePreset = demo.recommendedParticles
        refreshDayPalette(for: built.lock)
        if enableDayNightMode {
            synthesizeNightPair(switchToNightPreview: previewNightMode)
        }
        if playPreview {
            CamloHaptics.impact(.medium)
            replayUnlockPreview()
        }
    }

    @ViewBuilder
    private func cropSheet(for slot: CropSlot) -> some View {
        let outerCanvasSize = (canvasProfile == .duoDualScreen)
            ? DuoScreenSurface.outerCover.logicalSize
            : CGSize(width: 390, height: 844)
        let outerPixels = activeOuterPixelSize
        let innerCanvasSize = DuoScreenSurface.innerUnfolded.logicalSize
        let innerPixels = DuoScreenSurface.innerUnfolded.morphPixelSize

        switch slot {
        case .lock:
            if let raw = rawLockImage {
                LockScreenCropSheet(
                    title: Bi("裁剪锁屏常态画面", "Crop Lock Image"),
                    image: raw,
                    initialFraming: lockFraming,
                    canvasSize: outerCanvasSize,
                    pairedSlotSyncLabel: rawUnlockImage != nil
                        ? Bi("同步相同裁剪到「解锁变身」画面", "Apply same crop to Unlock media")
                        : nil
                ) { newFraming, syncPaired in
                    lockFraming = newFraming
                    lockImage = autoreleasepool { raw.aspectFilled(to: outerPixels, framing: newFraming) }
                    lockCutout = nil
                    if isLockActivelyLive {
                        reextractLiveSequence(forLock: true)
                    }
                    if syncPaired, let rawU = rawUnlockImage {
                        unlockFraming = newFraming
                        unlockImage = autoreleasepool { rawU.aspectFilled(to: outerPixels, framing: newFraming) }
                        unlockCutout = nil
                        if isUnlockActivelyLive {
                            reextractLiveSequence(forLock: false)
                        }
                    }
                    simulatorStage = .locked
                }
            }
        case .unlock:
            if let raw = rawUnlockImage {
                LockScreenCropSheet(
                    title: Bi("裁剪解锁变身画面", "Crop Unlock Image"),
                    image: raw,
                    initialFraming: unlockFraming,
                    canvasSize: outerCanvasSize,
                    pairedSlotSyncLabel: rawLockImage != nil
                        ? Bi("同步相同裁剪到「锁屏常态」画面", "Apply same crop to Lock media")
                        : nil
                ) { newFraming, syncPaired in
                    unlockFraming = newFraming
                    unlockImage = autoreleasepool { raw.aspectFilled(to: outerPixels, framing: newFraming) }
                    unlockCutout = nil
                    if isUnlockActivelyLive {
                        reextractLiveSequence(forLock: false)
                    }
                    if syncPaired, let rawL = rawLockImage {
                        lockFraming = newFraming
                        lockImage = autoreleasepool { rawL.aspectFilled(to: outerPixels, framing: newFraming) }
                        lockCutout = nil
                        if isLockActivelyLive {
                            reextractLiveSequence(forLock: true)
                        }
                    }
                    replayUnlockPreview()
                }
            }
        case .sleep:
            if let raw = rawSleepImage {
                LockScreenCropSheet(
                    title: Bi("裁剪熄屏常显图片", "Crop Sleep Image"),
                    image: raw,
                    initialFraming: sleepFraming,
                    canvasSize: outerCanvasSize
                ) { newFraming, _ in
                    sleepFraming = newFraming
                    sleepImage = autoreleasepool { raw.aspectFilled(to: outerPixels, framing: newFraming) }
                    simulatorStage = .sleep
                }
            }
        case .innerLock:
            if let raw = rawInnerLockImage {
                LockScreenCropSheet(
                    title: Bi("裁剪 Duo 内屏锁屏画面", "Crop Duo Inner Lock"),
                    image: raw,
                    initialFraming: innerLockFraming,
                    canvasSize: innerCanvasSize,
                    pairedSlotSyncLabel: rawInnerUnlockImage != nil
                        ? Bi("同步裁剪到内屏解锁画面", "Apply same crop to Inner Unlock")
                        : nil
                ) { newFraming, syncPaired in
                    innerLockFraming = newFraming
                    innerLockImage = autoreleasepool { raw.aspectFilled(to: innerPixels, framing: newFraming) }
                    innerLockCutout = nil
                    if syncPaired, let rawU = rawInnerUnlockImage {
                        innerUnlockFraming = newFraming
                        innerUnlockImage = autoreleasepool { rawU.aspectFilled(to: innerPixels, framing: newFraming) }
                        innerUnlockCutout = nil
                    }
                    previewDuoSurface = .innerUnfolded
                    simulatorStage = .locked
                }
            }
        case .innerUnlock:
            if let raw = rawInnerUnlockImage {
                LockScreenCropSheet(
                    title: Bi("裁剪 Duo 内屏解锁画面", "Crop Duo Inner Unlock"),
                    image: raw,
                    initialFraming: innerUnlockFraming,
                    canvasSize: innerCanvasSize,
                    pairedSlotSyncLabel: rawInnerLockImage != nil
                        ? Bi("同步裁剪到内屏锁屏画面", "Apply same crop to Inner Lock")
                        : nil
                ) { newFraming, syncPaired in
                    innerUnlockFraming = newFraming
                    innerUnlockImage = autoreleasepool { raw.aspectFilled(to: innerPixels, framing: newFraming) }
                    innerUnlockCutout = nil
                    if syncPaired, let rawL = rawInnerLockImage {
                        innerLockFraming = newFraming
                        innerLockImage = autoreleasepool { rawL.aspectFilled(to: innerPixels, framing: newFraming) }
                        innerLockCutout = nil
                    }
                    previewDuoSurface = .innerUnfolded
                    replayUnlockPreview()
                }
            }
        }
    }

    private func handleSlotSelection(item: PhotosPickerItem, isLock: Bool) {
        Task {
            guard let picked = await loadMorphSlotMedia(from: item) else { return }
            await MainActor.run {
                selectedDemoID = nil
                if SampleArtGenerator.allDemos.contains(where: { $0.title == titleText }) {
                    titleText = ""
                }

                if isLock {
                    lockExtractionTask?.cancel()
                    isExtractingLockLive = false
                    lockCutout = nil
                } else {
                    unlockExtractionTask?.cancel()
                    isExtractingUnlockLive = false
                    unlockCutout = nil
                }

                let targetPixels = activeOuterPixelSize
                let targetAspect = canvasProfile == .duoDualScreen ? DuoScreenSurface.outerCover.aspectRatio : (390.0 / 844.0)

                switch picked {
                case let .live(videoURL, poster, still):
                    let fitted = autoreleasepool { poster.aspectFilled(to: targetPixels, framing: .identity) }
                    if isLock {
                        lockSourceVideoURL = videoURL
                        lockVideoPosterImage = poster
                        lockStillFallbackImage = still
                        rawLockImage = poster
                        lockFraming = .identity
                        lockImage = fitted
                        lockLiveEnabled = true
                        lockLiveSequence = nil
                        simulatorStage = .locked
                        reextractLiveSequence(forLock: true)
                    } else {
                        unlockSourceVideoURL = videoURL
                        unlockVideoPosterImage = poster
                        unlockStillFallbackImage = still
                        rawUnlockImage = poster
                        unlockFraming = .identity
                        unlockImage = fitted
                        unlockLiveEnabled = true
                        unlockLiveSequence = nil
                        replayUnlockPreview()
                        reextractLiveSequence(forLock: false)
                    }
                    ensureLiveSequencesFitMemoryBudget()
                    CamloHaptics.impact(.light)
                    if poster.needsInteractiveCropSuggestion(targetAspect: targetAspect) {
                        activeCropSlot = isLock ? .lock : .unlock
                    }

                case let .staticPhoto(img):
                    let fitted = autoreleasepool { img.aspectFilled(to: targetPixels, framing: .identity) }
                    if isLock {
                        lockSourceVideoURL = nil
                        lockVideoPosterImage = nil
                        lockStillFallbackImage = nil
                        lockLiveEnabled = false
                        lockLiveSequence = nil
                        lockLiveIsCompact = false
                        rawLockImage = img
                        lockFraming = .identity
                        lockImage = fitted
                        simulatorStage = .locked
                    } else {
                        unlockSourceVideoURL = nil
                        unlockVideoPosterImage = nil
                        unlockStillFallbackImage = nil
                        unlockLiveEnabled = false
                        unlockLiveSequence = nil
                        unlockLiveIsCompact = false
                        rawUnlockImage = img
                        unlockFraming = .identity
                        unlockImage = fitted
                        replayUnlockPreview()
                    }
                    CamloHaptics.impact(.light)
                    if img.needsInteractiveCropSuggestion(targetAspect: targetAspect) {
                        activeCropSlot = isLock ? .lock : .unlock
                    }
                }
            }
        }
    }

    private func handleInnerPhotoSelection(item: PhotosPickerItem, isLock: Bool) {
        Task {
            guard let img = await loadPhoto(from: item) else { return }
            let innerPixels = DuoScreenSurface.innerUnfolded.morphPixelSize
            let innerAspect = DuoScreenSurface.innerUnfolded.aspectRatio
            let fitted = await Task.detached(priority: .userInitiated) {
                autoreleasepool { img.aspectFilled(to: innerPixels, framing: .identity) }
            }.value
            await MainActor.run {
                if isLock {
                    rawInnerLockImage = img
                    innerLockFraming = .identity
                    innerLockImage = fitted
                    innerLockCutout = nil
                    previewDuoSurface = .innerUnfolded
                    simulatorStage = .locked
                } else {
                    rawInnerUnlockImage = img
                    innerUnlockFraming = .identity
                    innerUnlockImage = fitted
                    innerUnlockCutout = nil
                    previewDuoSurface = .innerUnfolded
                    replayUnlockPreview()
                }
                CamloHaptics.impact(.light)
                if img.needsInteractiveCropSuggestion(targetAspect: innerAspect) {
                    activeCropSlot = isLock ? .innerLock : .innerUnlock
                }
            }
        }
    }

    private func loadMorphSlotMedia(from item: PhotosPickerItem) async -> PickedMorphSlotMedia? {
        if let live = try? await item.loadTransferable(type: PHLivePhoto.self),
           let pairedURL = try? await VideoFrameExtractor.extractPairedVideoURL(from: live),
           let poster = try? await VideoFrameExtractor.extractPosterFrame(from: pairedURL) {
            let still = await loadPhoto(from: item) ?? poster
            return .live(videoURL: pairedURL, posterImage: poster, stillFallback: still)
        }
        if let movie = try? await item.loadTransferable(type: CamloPickedMovieFile.self),
           let poster = try? await VideoFrameExtractor.extractPosterFrame(from: movie.url) {
            return .live(videoURL: movie.url, posterImage: poster, stillFallback: poster)
        }
        if let staticImg = await loadPhoto(from: item) {
            return .staticPhoto(staticImg)
        }
        return nil
    }

    private func setSlotLiveEnabled(_ enabled: Bool, forLock isLock: Bool) {
        if isLock {
            guard lockLiveEnabled != enabled, lockSourceVideoURL != nil else { return }
            lockLiveEnabled = enabled
            if enabled {
                if let poster = lockVideoPosterImage {
                    rawLockImage = poster
                    lockImage = autoreleasepool { poster.aspectFilled(to: CAMLCompiler.retinaSize, framing: lockFraming) }
                }
                lockCutout = nil
                reextractLiveSequence(forLock: true)
                ensureLiveSequencesFitMemoryBudget()
            } else {
                lockExtractionTask?.cancel()
                isExtractingLockLive = false
                lockLiveSequence = nil
                lockLiveIsCompact = false
                if let still = lockStillFallbackImage {
                    rawLockImage = still
                    lockImage = autoreleasepool { still.aspectFilled(to: CAMLCompiler.retinaSize, framing: lockFraming) }
                }
            }
        } else {
            guard unlockLiveEnabled != enabled, unlockSourceVideoURL != nil else { return }
            unlockLiveEnabled = enabled
            if enabled {
                if let poster = unlockVideoPosterImage {
                    rawUnlockImage = poster
                    unlockImage = autoreleasepool { poster.aspectFilled(to: CAMLCompiler.retinaSize, framing: unlockFraming) }
                }
                unlockCutout = nil
                reextractLiveSequence(forLock: false)
                ensureLiveSequencesFitMemoryBudget()
            } else {
                unlockExtractionTask?.cancel()
                isExtractingUnlockLive = false
                unlockLiveSequence = nil
                unlockLiveIsCompact = false
                if let still = unlockStillFallbackImage {
                    rawUnlockImage = still
                    unlockImage = autoreleasepool { still.aspectFilled(to: CAMLCompiler.retinaSize, framing: unlockFraming) }
                }
            }
        }
        CamloHaptics.selection()
    }

    private func reextractLiveSequence(forLock isLock: Bool) {
        guard let url = isLock ? lockSourceVideoURL : unlockSourceVideoURL,
              (isLock ? isLockActivelyLive : isUnlockActivelyLive) else {
            return
        }
        let framing = isLock ? lockFraming : unlockFraming
        let useCompact = needsCompactLiveBudget
        let targetCanvas: CGSize? = (canvasProfile == .duoDualScreen) ? DuoScreenSurface.outerCover.videoPixelSize : nil

        if isLock {
            lockExtractionTask?.cancel()
            lockLiveIsCompact = useCompact
            isExtractingLockLive = true
        } else {
            unlockExtractionTask?.cancel()
            unlockLiveIsCompact = useCompact
            isExtractingUnlockLive = true
        }

        let task = Task {
            do {
                let seq = try await VideoFrameExtractor.extractMorphLiveSequence(
                    from: url,
                    framing: framing,
                    compactResolution: useCompact,
                    targetCanvasSize: targetCanvas
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if isLock {
                        isExtractingLockLive = false
                        guard lockLiveEnabled, lockSourceVideoURL == url else { return }
                        lockLiveSequence = seq
                    } else {
                        isExtractingUnlockLive = false
                        guard unlockLiveEnabled, unlockSourceVideoURL == url else { return }
                        unlockLiveSequence = seq
                    }
                    CamloHaptics.impact(.light)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if isLock {
                        isExtractingLockLive = false
                        lockLiveEnabled = false
                        lockLiveSequence = nil
                        lockLiveIsCompact = false
                    } else {
                        isExtractingUnlockLive = false
                        unlockLiveEnabled = false
                        unlockLiveSequence = nil
                        unlockLiveIsCompact = false
                    }
                    showOpenPosterBoardAction = false
                    alertTitle = Bi("实况动态解析失败", "Live Extraction Failed")
                    alertMessage = error.localizedDescription
                    showResultAlert = true
                }
            }
        }

        if isLock {
            lockExtractionTask = task
        } else {
            unlockExtractionTask = task
        }
    }

    private func ensureLiveSequencesFitMemoryBudget() {
        guard needsCompactLiveBudget else { return }
        if isLockActivelyLive,
           ((lockLiveSequence?.pixelWidth ?? 0) > 390 || (isExtractingLockLive && !lockLiveIsCompact)) {
            reextractLiveSequence(forLock: true)
        }
        if isUnlockActivelyLive,
           ((unlockLiveSequence?.pixelWidth ?? 0) > 390 || (isExtractingUnlockLive && !unlockLiveIsCompact)) {
            reextractLiveSequence(forLock: false)
        }
    }

    private func replayUnlockPreview() {
        simulatorStage = .locked
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(duration: durationSeconds, bounce: springBounce * 0.55)) {
                simulatorStage = .unlock
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                UIImage.downsampledRetina(from: data, maxPixelDimension: 2560)
            }
        }.value
    }

    private func runVisionSubjectCutout() {
        let targetLock = isLockActivelyLive ? nil : lockImage
        let targetUnlock = isUnlockActivelyLive ? nil : unlockImage

        if targetLock == nil && targetUnlock == nil {
            if (isLockActivelyLive && lockImage != nil) || (isUnlockActivelyLive && unlockImage != nil) {
                showOpenPosterBoardAction = false
                alertTitle = Bi("实况动态暂不支持静态破框", "Static Cutout Unavailable for Live Slots")
                alertMessage = Bi(
                    "AI 前景破框是静态叠加蒙版，会覆盖在动态帧上方造成重影；如需「破框遮挡时钟」效果，请将至少一个槽位切换为「静态高清」。",
                    "Static Vision subject masks would ghost over moving Live Photo frames. Switch at least one slot to Static HD to use Clock Depth occlusion."
                )
                showResultAlert = true
                CamloHaptics.notify(.warning)
            }
            return
        }

        isExtractingCutout = true
        let outerPixels = activeOuterPixelSize
        let includeInner = (canvasProfile == .duoDualScreen)
        let targetInnerL = includeInner ? innerLockImage : nil
        let targetInnerU = includeInner ? innerUnlockImage : nil
        let innerPixels = DuoScreenSurface.innerUnfolded.morphPixelSize

        Task {
            let resolvedL: UIImage?
            if let targetLock {
                resolvedL = try? await SubjectCutoutService.extractForegroundSubject(from: targetLock, targetPixelSize: outerPixels)
            } else {
                resolvedL = nil
            }
            let resolvedU: UIImage?
            if let targetUnlock {
                resolvedU = try? await SubjectCutoutService.extractForegroundSubject(from: targetUnlock, targetPixelSize: outerPixels)
            } else {
                resolvedU = nil
            }
            let resolvedInnerL: UIImage?
            if let targetInnerL {
                resolvedInnerL = try? await SubjectCutoutService.extractForegroundSubject(from: targetInnerL, targetPixelSize: innerPixels)
            } else {
                resolvedInnerL = nil
            }
            let resolvedInnerU: UIImage?
            if let targetInnerU {
                resolvedInnerU = try? await SubjectCutoutService.extractForegroundSubject(from: targetInnerU, targetPixelSize: innerPixels)
            } else {
                resolvedInnerU = nil
            }
            await MainActor.run {
                isExtractingCutout = false
                if resolvedL == nil && resolvedU == nil && resolvedInnerL == nil && resolvedInnerU == nil {
                    showOpenPosterBoardAction = false
                    alertTitle = Bi("未识别到前景主体", "No Foreground Subject")
                    alertMessage = SubjectCutoutError.noSubjectDetected.localizedDescription
                    showResultAlert = true
                    CamloHaptics.notify(.warning)
                } else {
                    if targetLock == nil || self.lockImage === targetLock {
                        lockCutout = resolvedL
                    }
                    if targetUnlock == nil || self.unlockImage === targetUnlock {
                        unlockCutout = resolvedU
                    }
                    if targetInnerL != nil && self.innerLockImage === targetInnerL {
                        innerLockCutout = resolvedInnerL
                    }
                    if targetInnerU != nil && self.innerUnlockImage === targetInnerU {
                        innerUnlockCutout = resolvedInnerU
                    }
                    ensureLiveSequencesFitMemoryBudget()
                    CamloHaptics.notify(.success)
                }
            }
        }
    }

    private func compileSpec() -> MorphCompileSpec? {
        guard let lockImage, let unlockImage else { return nil }
        return MorphCompileSpec(
            title: titleText,
            lockImage: lockImage,
            unlockImage: unlockImage,
            customSleepImage: sleepImage,
            lockSubjectCutout: isLockActivelyLive ? nil : lockCutout,
            unlockSubjectCutout: isUnlockActivelyLive ? nil : unlockCutout,
            lockLiveSequence: isLockActivelyLive ? lockLiveSequence : nil,
            unlockLiveSequence: isUnlockActivelyLive ? unlockLiveSequence : nil,
            liveLoopStyle: liveLoopStyle,
            preset: selectedPreset,
            durationSeconds: durationSeconds,
            springBounce: springBounce,
            particlePreset: particlePreset,
            enableGyroParallax: enableGyroParallax,
            gyroIntensity: gyroIntensity,
            enableDayNightMode: enableDayNightMode,
            nightLockImage: enableDayNightMode ? nightLockImage : nil,
            nightUnlockImage: enableDayNightMode ? nightUnlockImage : nil,
            nightLockCutout: enableDayNightMode ? nightLockCutout : nil,
            nightUnlockCutout: enableDayNightMode ? nightUnlockCutout : nil,
            nightParticlePreset: enableDayNightMode ? nightParticlePreset : nil,
            posterStyle: posterStyle,
            canvasProfile: canvasProfile,
            innerLockImage: canvasProfile == .duoDualScreen ? innerLockImage : nil,
            innerUnlockImage: canvasProfile == .duoDualScreen ? innerUnlockImage : nil,
            innerLockSubjectCutout: canvasProfile == .duoDualScreen ? innerLockCutout : nil,
            innerUnlockSubjectCutout: canvasProfile == .duoDualScreen ? innerUnlockCutout : nil
        )
    }

    private func refreshDayPalette(for image: UIImage?) {
        guard let image else {
            dayPaletteMetrics = nil
            return
        }
        Task {
            let metrics = await Task.detached(priority: .userInitiated) {
                PosterStyleGenerator.analyzePalette(of: image)
            }.value
            if self.lockImage === image {
                self.dayPaletteMetrics = metrics
            }
        }
    }

    private func refreshNightPalette(for image: UIImage?) {
        guard let image else {
            nightPaletteMetrics = nil
            return
        }
        Task {
            let metrics = await Task.detached(priority: .userInitiated) {
                PosterStyleGenerator.analyzePalette(of: image)
            }.value
            if self.nightLockImage === image {
                self.nightPaletteMetrics = metrics
            }
        }
    }

    private func synthesizeNightPair(switchToNightPreview: Bool) {
        let srcLock = lockImage
        let srcUnlock = unlockImage
        let srcLockCutout = lockCutout
        let srcUnlockCutout = unlockCutout
        guard srcLock != nil || srcUnlock != nil else { return }

        isSynthesizingNight = true
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                let nLock = srcLock.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: false) }
                let nUnlock = srcUnlock.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: false) }
                let nLockCut = srcLockCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) }
                let nUnlockCut = srcUnlockCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) }
                let metrics = nLock.map { PosterStyleGenerator.analyzePalette(of: $0) }
                return (nLock, nUnlock, nLockCut, nUnlockCut, metrics)
            }.value

            isSynthesizingNight = false
            if self.lockImage === srcLock {
                nightLockImage = results.0
                nightLockCutout = results.2
                nightPaletteMetrics = results.4
            }
            if self.unlockImage === srcUnlock {
                nightUnlockImage = results.1
                nightUnlockCutout = results.3
            }
            if switchToNightPreview {
                previewNightMode = true
            }
            CamloHaptics.notify(.success)
        }
    }

    private func handleNightPickerSelection(item: PhotosPickerItem, isLock: Bool) {
        let targetPixels = activeOuterPixelSize
        Task {
            guard let img = await loadPhoto(from: item) else { return }
            let fitted = await Task.detached(priority: .userInitiated) {
                autoreleasepool { img.aspectFilled(to: targetPixels, framing: .identity) }
            }.value
            await MainActor.run {
                if isLock {
                    nightLockImage = fitted
                    nightLockCutout = nil
                } else {
                    nightUnlockImage = fitted
                    nightUnlockCutout = nil
                }
                previewNightMode = true
                CamloHaptics.impact(.light)
            }
        }
    }

    private func runNightVisionSubjectCutout() {
        let srcLock = nightLockImage ?? lockImage
        let srcUnlock = nightUnlockImage ?? unlockImage
        guard srcLock != nil || srcUnlock != nil else { return }

        isCuttingNightSubject = true
        Task {
            let resolvedL: UIImage?
            if let srcLock {
                resolvedL = try? await SubjectCutoutService.extractForegroundSubject(from: srcLock)
            } else {
                resolvedL = nil
            }
            let resolvedU: UIImage?
            if let srcUnlock {
                resolvedU = try? await SubjectCutoutService.extractForegroundSubject(from: srcUnlock)
            } else {
                resolvedU = nil
            }
            await MainActor.run {
                isCuttingNightSubject = false
                if resolvedL == nil && resolvedU == nil {
                    showOpenPosterBoardAction = false
                    alertTitle = Bi("未识别到夜间前景主体", "No Night Foreground Subject")
                    alertMessage = SubjectCutoutError.noSubjectDetected.localizedDescription
                    showResultAlert = true
                    CamloHaptics.notify(.warning)
                } else {
                    nightLockCutout = resolvedL
                    nightUnlockCutout = resolvedU
                    previewNightMode = true
                    CamloHaptics.notify(.success)
                }
            }
        }
    }

    private func buildAndApplyDirectly() {
        guard let spec = compileSpec() else { return }
        isBuilding = true
        Task { @MainActor in
            defer { isBuilding = false }
            do {
                let item = try vault.createMorphPackage(spec: spec)
                let applyRes = bridge.applyTendiesItems([item])
                if applyRes.0 {
                    CamloHaptics.notify(.success)
                    showOpenPosterBoardAction = true
                    alertTitle = Bi("已写入系统锁屏画廊", "Injected into Lock Screen Gallery")
                    alertMessage = Bi(
                        "作品「\(item.title)」已写入系统壁纸库（不在「照片」里！）。\n\n⚠️ 查找步骤：\n1. 点击下方「立即注销桌面生效」（或点「打开 PosterBoard」后在后台多任务界面把它上滑关闭）刷新系统缓存；\n2. 长按锁屏点击「+」号，在「专为你的 iPhone 设计的墙纸」（紧挨默认粉色壁纸的第 2 张起）或下滑到底部的「收藏」横向栏即可看到它！",
                        "\"\(item.title)\" has been injected into PosterBoard (not under Photos).\n\n1. Tap 'Respring Now' (or open PosterBoard and swipe it up in App Switcher) so iOS reloads descriptors;\n2. Long-press Lock Screen -> tap '+' and look in the model-exclusive wallpaper row (card #2 next to default) or scroll down to 'Collections'!"
                    )
                    showResultAlert = true
                } else {
                    CamloHaptics.notify(.warning)
                    showOpenPosterBoardAction = false
                    alertTitle = Bi("已存入金库（直写暂未就绪）", "Saved to Vault")
                    alertMessage = "\(applyRes.1)\n\n" + Bi("壁纸已完整编译保存在「壁纸金库」中，你仍可直接点击「导出 .tendies 分享」在其他工具或设备导入。", "Your compiled wallpaper is safely saved in Vault and ready for .tendies export.")
                    showResultAlert = true
                }
            } catch {
                CamloHaptics.notify(.error)
                showOpenPosterBoardAction = false
                alertTitle = Bi("编译失败", "Build Failed")
                alertMessage = error.localizedDescription
                showResultAlert = true
            }
        }
    }

    private func buildAndExportTendies() {
        guard let spec = compileSpec() else { return }
        isBuilding = true
        Task { @MainActor in
            defer { isBuilding = false }
            do {
                let item = try vault.createMorphPackage(spec: spec)
                let url = try vault.exportTendiesFile(for: item)
                CamloHaptics.notify(.success)
                CamloShare.presentShareSheet(for: url)
            } catch {
                CamloHaptics.notify(.error)
                showOpenPosterBoardAction = false
                alertTitle = Bi("导出失败", "Export Failed")
                alertMessage = error.localizedDescription
                showResultAlert = true
            }
        }
    }

    private func buildToVaultOnly() {
        guard let spec = compileSpec() else { return }
        isBuilding = true
        Task { @MainActor in
            defer { isBuilding = false }
            do {
                let item = try vault.createMorphPackage(spec: spec)
                CamloHaptics.notify(.success)
                showOpenPosterBoardAction = false
                alertTitle = Bi("已存入壁纸金库", "Saved to Vault")
                alertMessage = Bi("「\(item.title)」已保存，可随时在「壁纸金库」中批量应用或导出 .tendies。", "\"\(item.title)\" has been saved to your Vault.")
                showResultAlert = true
            } catch {
                CamloHaptics.notify(.error)
                showOpenPosterBoardAction = false
                alertTitle = Bi("保存失败", "Save Failed")
                alertMessage = error.localizedDescription
                showResultAlert = true
            }
        }
    }
}
