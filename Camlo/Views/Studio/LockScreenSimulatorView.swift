//
//  LockScreenSimulatorView.swift
//  Camlo · 开幕
//
//  Interactive 60/120Hz iPhone Lock Screen simulator with authentic LayerKit Z-ordering
//  (Background -> iOS Clock -> Floating Subject Cutout -> Foreground Particles & Flash)
//  and real-time finger swipe-up scrubbing.
//

import SwiftUI
import UIKit

enum SimulatorContent {
    case morph(
        lockImage: UIImage?,
        unlockImage: UIImage?,
        sleepImage: UIImage?,
        lockCutout: UIImage?,
        unlockCutout: UIImage?,
        lockLiveFrames: [UIImage] = [],
        lockLiveFPS: Int = 14,
        unlockLiveFrames: [UIImage] = [],
        unlockLiveFPS: Int = 14,
        liveLoopStyle: VideoLoopStyle = .pingPong,
        preset: MorphTransitionPreset,
        duration: Double,
        bounce: Double
    )
    case video(
        frames: [UIImage],
        fps: Int,
        loopStyle: VideoLoopStyle,
        unlockZoomScale: Double,
        dimInSleep: Bool,
        renderAboveClock: Bool
    )

    var morphTiming: (preset: MorphTransitionPreset, duration: Double, bounce: Double)? {
        if case let .morph(_, _, _, _, _, _, _, _, _, _, preset, duration, bounce) = self {
            return (preset, duration, bounce)
        }
        return nil
    }
}

struct LockScreenSimulatorView: View {
    let content: SimulatorContent
    let particlePreset: ParticlePreset
    @Binding var stage: LockScreenStage
    var phoneWidth: CGFloat = 246
    var canvasSize: CGSize = CGSize(width: 390, height: 844)
    var gyroEnabled: Bool = false
    var gyroIntensity: Double = 0.65
    var posterStyle: PosterStyleSpec = PosterStyleSpec()
    var paletteMetrics: WallpaperPaletteMetrics? = nil
    var isDayNightEnabled: Bool = false
    var previewNightMode: Binding<Bool>? = nil
    var showHomeScreenPreview: Binding<Bool>? = nil

    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var motion = MotionTiltManager.shared
    @State private var dragProgress: CGFloat? = nil
    @State private var crossedThresholdHaptic = false
    @State private var flashPulseOpacity: Double = 0
    @State private var sessionToken = UUID()

    private var canvasAspect: CGFloat {
        canvasSize.width / max(canvasSize.height, 1)
    }

    private var isLandscapeCanvas: Bool {
        canvasAspect > 1.05
    }

    private var phoneHeight: CGFloat {
        (phoneWidth / max(canvasAspect, 0.25)).rounded()
    }

    private var uiScaleRef: CGFloat {
        min(phoneWidth, phoneHeight)
    }

    private var bezelCornerRadius: CGFloat {
        uiScaleRef * (isLandscapeCanvas ? 0.088 : 0.165)
    }

    private var screenCornerRadius: CGFloat {
        uiScaleRef * (isLandscapeCanvas ? 0.068 : 0.145)
    }

    private var isHomePreviewActive: Bool {
        showHomeScreenPreview?.wrappedValue ?? false
    }

    /// 0.0 = Locked, 1.0 = Unlock (continuous during finger swipe or animated via state button)
    private var morphProgress: Double {
        if let drag = dragProgress {
            return Double(min(max(drag, 0), 1))
        }
        return (stage == .unlock || isHomePreviewActive) ? 1.0 : 0.0
    }

    private var isSleepStage: Bool {
        dragProgress == nil && stage == .sleep && !isHomePreviewActive
    }

    private var effectiveMetrics: WallpaperPaletteMetrics {
        paletteMetrics ?? .neutralFallback
    }

    private var parallaxMetrics: (bgScale: CGFloat, fgScale: CGFloat, gx: CGFloat, gy: CGFloat) {
        guard gyroEnabled && !isSleepStage else {
            return (1.0, 1.0, 0, 0)
        }
        let intensity = max(0.20, min(gyroIntensity, 1.0))
        let bgScale = CGFloat(1.0 + 0.14 * intensity)
        let fgScale = CGFloat(1.0 + 0.06 * intensity)
        let gx = motion.tiltX * CGFloat(17.0 * intensity) * (phoneWidth / max(canvasSize.width, 1))
        let gy = motion.tiltY * CGFloat(22.0 * intensity) * (phoneHeight / max(canvasSize.height, 1))
        return (bgScale, fgScale, gx, gy)
    }

    var body: some View {
        let px = parallaxMetrics
        VStack(spacing: 10) {
            ZStack {
                // Outer Titanium Bezel
                RoundedRectangle(cornerRadius: bezelCornerRadius, style: .continuous)
                    .fill(Color(white: 0.08))
                    .frame(width: phoneWidth + 12, height: phoneHeight + 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: bezelCornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.08), Color.white.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.32), radius: 18, x: 0, y: 10)

                // Screen Viewport
                ZStack {
                    Color.black

                    // 1. Background.ca Layer (Behind Clock — overscanned + +tilt)
                    backgroundLayer
                        .scaleEffect(px.bgScale)
                        .offset(x: px.gx, y: px.gy)

                    // 2. Native iOS Lock Screen Clock (Occluded by Floating.ca!)
                    if !isHomePreviewActive {
                        clockLayer
                    }

                    // 3. Floating.ca Layer (In Front of Clock — inverse 3D tilt)
                    floatingDepthLayer
                        .scaleEffect(px.fgScale)
                        .offset(x: -px.gx * 1.35, y: -px.gy * 1.35)

                    // 4. Foreground.ca Layer (Particles & Flash Veil — deepest near-plane tilt)
                    if particlePreset != .none && !isSleepStage {
                        SimulatorParticleCanvas(preset: particlePreset)
                            .offset(x: -px.gx * 1.75, y: -px.gy * 1.75)
                            .allowsHitTesting(false)
                    }

                    if effectiveFlashOverlayOpacity > 0.005 {
                        Color.white
                            .opacity(effectiveFlashOverlayOpacity)
                            .allowsHitTesting(false)
                    }

                    // 5. Home Screen Pairing Preview Overlay
                    if isHomePreviewActive {
                        homeScreenCompanionOverlay
                            .transition(.opacity.animation(.easeInOut(duration: 0.24)))
                            .allowsHitTesting(false)
                    }

                    // 6. Sleep AOD Dimming Overlay
                    if isSleepStage {
                        sleepOverlay
                            .allowsHitTesting(false)
                    }

                    // 7. Lock Screen Chrome (Dynamic Island, Bottom Controls, Swipe Hint)
                    chromeOverlay
                        .allowsHitTesting(false)

                    // Subtle book-hinge reflection when previewing iPhone Duo unfolded inner screen
                    if isLandscapeCanvas {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.22), .white.opacity(0.10), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 5)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: phoneWidth, height: phoneHeight)
                .clipShape(RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous))
                .clipped()
                .contentShape(RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous))
                .gesture(swipeGesture)
            }
            .onAppear {
                if gyroEnabled { motion.startSession(token: sessionToken) }
            }
            .onDisappear {
                motion.stopSession(token: sessionToken)
            }
            .onChange(of: gyroEnabled) { _, enabled in
                if enabled {
                    motion.startSession(token: sessionToken)
                } else {
                    motion.stopSession(token: sessionToken)
                }
            }

            // Interactive 3-State Switcher Pills
            HStack(spacing: 8) {
                ForEach(LockScreenStage.allCases) { item in
                    let active = (!isHomePreviewActive && stage == item && dragProgress == nil)
                    Button {
                        showHomeScreenPreview?.wrappedValue = false
                        triggerStageTransition(to: item)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 12, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(active ? Color.accentColor : Color.secondary.opacity(0.14))
                        )
                        .foregroundStyle(active ? Color.white : Color.primary)
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }
            }

            // Secondary Appearance, Home Pairing & 120Hz Gyro Pill Bar
            if isDayNightEnabled || showHomeScreenPreview != nil || gyroEnabled {
                HStack(spacing: 8) {
                    if isDayNightEnabled, let nightBinding = previewNightMode {
                        Button {
                            CamloHaptics.selection()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                nightBinding.wrappedValue.toggle()
                            }
                        } label: {
                            Label(
                                nightBinding.wrappedValue ? Bi("夜间双生", "Night") : Bi("日间标准", "Day"),
                                systemImage: nightBinding.wrappedValue ? "moon.stars.fill" : "sun.max.fill"
                            )
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                nightBinding.wrappedValue ? Color.indigo.opacity(0.22) : Color.orange.opacity(0.18),
                                in: Capsule()
                            )
                            .foregroundStyle(nightBinding.wrappedValue ? .indigo : .orange)
                        }
                        .buttonStyle(CamloTapButtonStyle())
                    }

                    if let homeBinding = showHomeScreenPreview {
                        Button {
                            CamloHaptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                homeBinding.wrappedValue.toggle()
                            }
                        } label: {
                            Label(
                                homeBinding.wrappedValue ? Bi("主屏效果中", "Home View") : Bi("主屏预览", "Home"),
                                systemImage: homeBinding.wrappedValue ? "apps.iphone" : "iphone"
                            )
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                homeBinding.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.14),
                                in: Capsule()
                            )
                            .foregroundStyle(homeBinding.wrappedValue ? .white : .primary)
                        }
                        .buttonStyle(CamloTapButtonStyle())
                    }

                    if gyroEnabled {
                        HStack(spacing: 3) {
                            Image(systemName: "gyroscope")
                            Text("\(motion.activeRefreshHz)Hz 3D")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.16), in: Capsule())
                        .foregroundStyle(.purple)
                    }
                }
            }
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private var backgroundLayer: some View {
        switch content {
        case let .morph(
            lockImage,
            unlockImage,
            sleepImage,
            _,
            _,
            lockLiveFrames,
            lockLiveFPS,
            unlockLiveFrames,
            unlockLiveFPS,
            liveLoopStyle,
            preset,
            _,
            _
        ):
            ZStack {
                transformedMorphMediaLayer(
                    staticImage: unlockImage,
                    liveFrames: unlockLiveFrames,
                    liveFPS: unlockLiveFPS,
                    loopStyle: liveLoopStyle,
                    isLockLayer: false,
                    preset: preset
                )

                transformedMorphMediaLayer(
                    staticImage: lockImage,
                    liveFrames: lockLiveFrames,
                    liveFPS: lockLiveFPS,
                    loopStyle: liveLoopStyle,
                    isLockLayer: true,
                    preset: preset
                )

                if isSleepStage, let sleepImage {
                    boundedScreenImage(sleepImage)
                        .transition(.opacity)
                }
            }

        case let .video(frames, fps, loopStyle, unlockZoomScale, _, renderAboveClock):
            if !renderAboveClock {
                videoSequenceLayer(frames: frames, fps: fps, loopStyle: loopStyle, unlockZoomScale: unlockZoomScale)
            }
        }
    }

    @ViewBuilder
    private var floatingDepthLayer: some View {
        switch content {
        case let .morph(_, _, _, lockCutout, unlockCutout, _, _, _, _, _, preset, _, _):
            ZStack {
                if let unlockCutout {
                    transformedMorphImage(unlockCutout, isLockLayer: false, preset: preset)
                }
                if let lockCutout {
                    transformedMorphImage(lockCutout, isLockLayer: true, preset: preset)
                }
            }
            .allowsHitTesting(false)

        case let .video(frames, fps, loopStyle, unlockZoomScale, _, renderAboveClock):
            if renderAboveClock {
                videoSequenceLayer(frames: frames, fps: fps, loopStyle: loopStyle, unlockZoomScale: unlockZoomScale)
                    .allowsHitTesting(false)
            }
        }
    }

    private func boundedScreenImage(_ image: UIImage) -> some View {
        Color.clear
            .frame(width: phoneWidth, height: phoneHeight)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }

    @ViewBuilder
    private func morphTransformed<Inner: View>(
        isLockLayer: Bool,
        preset: MorphTransitionPreset,
        @ViewBuilder inner: () -> Inner
    ) -> some View {
        let metrics = computeLayerMetrics(
            isLockLayer: isLockLayer,
            preset: preset,
            p: morphProgress,
            sleepFactor: isSleepStage ? 1.0 : 0.0
        )

        inner()
            .scaleEffect(metrics.scale)
            .offset(x: metrics.offsetX * (phoneWidth / max(canvasSize.width, 1)), y: metrics.offsetY * (phoneHeight / max(canvasSize.height, 1)))
            .rotation3DEffect(
                .degrees(metrics.rotYDeg),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .opacity(metrics.opacity)
            .clipped()
    }

    @ViewBuilder
    private func transformedMorphMediaLayer(
        staticImage: UIImage?,
        liveFrames: [UIImage],
        liveFPS: Int,
        loopStyle: VideoLoopStyle,
        isLockLayer: Bool,
        preset: MorphTransitionPreset
    ) -> some View {
        morphTransformed(isLockLayer: isLockLayer, preset: preset) {
            if !liveFrames.isEmpty && !isSleepStage {
                TimelineView(.periodic(from: .now, by: 1.0 / Double(max(liveFPS, 12)))) { timeline in
                    let idx = currentFrameIndex(
                        at: timeline.date,
                        count: liveFrames.count,
                        fps: max(liveFPS, 1),
                        loopStyle: loopStyle
                    )
                    boundedScreenImage(liveFrames[idx])
                }
            } else if let displayImage = (isSleepStage ? (liveFrames.first ?? staticImage) : staticImage) {
                boundedScreenImage(displayImage)
            } else {
                placeholderBackdrop(isUnlock: !isLockLayer)
            }
        }
    }

    @ViewBuilder
    private func transformedMorphImage(_ image: UIImage, isLockLayer: Bool, preset: MorphTransitionPreset) -> some View {
        morphTransformed(isLockLayer: isLockLayer, preset: preset) {
            boundedScreenImage(image)
        }
    }

    private func computeLayerMetrics(
        isLockLayer: Bool,
        preset: MorphTransitionPreset,
        p: Double,
        sleepFactor: Double
    ) -> (opacity: Double, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat, rotYDeg: Double) {
        if sleepFactor > 0.5 {
            if isLockLayer {
                let op = preset == .aodGaze ? 0.34 : 0.48
                let sc = preset == .aodGaze ? 0.96 : 0.985
                return (op, sc, 0, 0, 0)
            } else {
                return (0, 1.0, 0, 0, 0)
            }
        }

        switch preset {
        case .curtainRise:
            if isLockLayer {
                return (1.0 - p, CGFloat(1.0 + 0.04 * p), 0, CGFloat(-220.0 * p), 0)
            } else {
                return (1.0, CGFloat(1.06 - 0.06 * p), 0, 0, 0)
            }

        case .burstZoom:
            if isLockLayer {
                return (1.0 - p, CGFloat(1.0 + 0.22 * p), 0, 0, 0)
            } else {
                return (min(1.0, 0.25 + 0.75 * p), CGFloat(0.84 + 0.16 * p), 0, 0, 0)
            }

        case .crossfade, .aodGaze:
            if isLockLayer {
                let sc = preset == .aodGaze ? (1.0 + 0.04 * p) : 1.0
                return (1.0 - p, CGFloat(sc), 0, 0, 0)
            } else {
                return (1.0, CGFloat(1.03 - 0.03 * p), 0, 0, 0)
            }

        case .flashAwaken:
            if isLockLayer {
                return (p < 0.45 ? 1.0 : 0.0, 1.0, 0, 0, 0)
            } else {
                return (1.0, CGFloat(1.04 - 0.04 * p), 0, 0, 0)
            }

        case .holoCard:
            if isLockLayer {
                return (1.0 - p, 1.0, CGFloat(-32.0 * p), 0, 14.0 * p)
            } else {
                return (1.0, 1.0, CGFloat(24.0 * (1.0 - p)), 0, -14.0 * (1.0 - p))
            }
        }
    }

    private var effectiveFlashOverlayOpacity: Double {
        if let timing = content.morphTiming, timing.preset == .flashAwaken {
            if let drag = dragProgress {
                return Double(sin(min(max(drag, 0), 1) * .pi)) * 0.88
            }
            return flashPulseOpacity
        }
        return 0
    }

    @ViewBuilder
    private func videoSequenceLayer(frames: [UIImage], fps: Int, loopStyle: VideoLoopStyle, unlockZoomScale: Double) -> some View {
        if frames.isEmpty {
            placeholderBackdrop(isUnlock: false)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / Double(max(fps, 12)))) { timeline in
                let idx = currentFrameIndex(at: timeline.date, count: frames.count, fps: max(fps, 1), loopStyle: loopStyle)
                let scale = 1.0 + (unlockZoomScale - 1.0) * morphProgress
                boundedScreenImage(frames[idx])
                    .scaleEffect(scale)
                    .clipped()
            }
        }
    }

    private func currentFrameIndex(at date: Date, count: Int, fps: Int, loopStyle: VideoLoopStyle) -> Int {
        guard count > 1 else { return 0 }
        let rawTick = Int((date.timeIntervalSinceReferenceDate * Double(fps)).rounded(.down))
        switch loopStyle {
        case .loop:
            return ((rawTick % count) + count) % count
        case .pingPong:
            let cycle = max(1, count * 2 - 2)
            let pos = ((rawTick % cycle) + cycle) % cycle
            return pos < count ? pos : (cycle - pos)
        }
    }

    private var clockLayer: some View {
        let topPad = phoneHeight * (isLandscapeCanvas ? 0.088 : 0.115)
        let clockOpacity: Double = isSleepStage ? 0.52 : (1.0 - 0.35 * morphProgress)
        let clockOffsetY: CGFloat = CGFloat(-14.0 * morphProgress)
        let clockRGB = PosterStyleGenerator.previewClockColor(mode: posterStyle.clockColorMode, metrics: effectiveMetrics)
        let isDarkInk = (clockRGB.r * 0.299 + clockRGB.g * 0.587 + clockRGB.b * 0.114) < 0.45
        let shadowColor = (isDarkInk ? Color.white : Color.black)

        return VStack(spacing: 2) {
            Text(CamloDevice.formattedLockScreenDate())
                .font(.system(size: uiScaleRef * (isLandscapeCanvas ? 0.044 : 0.052), weight: .semibold, design: .rounded))
                .foregroundStyle(clockRGB.swiftUIColor.opacity(0.92))
                .shadow(color: shadowColor.opacity(0.24), radius: 4, x: 0, y: 1)

            Text("09:41")
                .font(posterStyle.clockFont.swiftUIFont(size: uiScaleRef * (isLandscapeCanvas ? 0.195 : 0.255)))
                .fontWidth(posterStyle.clockFont.fontWidth)
                .tracking(posterStyle.clockFont.letterSpacing)
                .foregroundStyle(
                    LinearGradient(
                        colors: [clockRGB.swiftUIColor, clockRGB.swiftUIColor.opacity(0.84)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: shadowColor.opacity(0.26), radius: 8, x: 0, y: 3)

            Spacer()
        }
        .padding(.top, topPad)
        .offset(y: clockOffsetY)
        .opacity(clockOpacity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var homeScreenCompanionOverlay: some View {
        let gridIcons: [(symbol: String, tint: Color)] = [
            ("message.fill", .green),
            ("phone.fill", .green),
            ("safari.fill", .blue),
            ("music.note", .pink),
            ("camera.fill", .gray),
            ("photo.fill", .orange),
            ("map.fill", .teal),
            ("clock.fill", .indigo),
            ("cloud.sun.fill", .cyan),
            ("note.text", .yellow),
            ("calendar", .red),
            ("gearshape.fill", .secondary)
        ]
        let dockIcons: [(symbol: String, tint: Color)] = [
            ("phone.fill", .green),
            ("safari.fill", .blue),
            ("message.fill", .green),
            ("music.note", .pink)
        ]
        let iconSize = uiScaleRef * 0.145
        let iconRadius = iconSize * 0.24
        let gridCols = isLandscapeCanvas ? 6 : 4
        let gridTopSpace = phoneHeight * (isLandscapeCanvas ? 0.08 : 0.105)
        let gridSpacing = uiScaleRef * (isLandscapeCanvas ? 0.04 : 0.05)

        ZStack {
            switch posterStyle.homePairing {
            case .legibilityBlur:
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.14))
            case .clearMatch:
                Color.clear
            case .matchedGradient:
                LinearGradient(
                    colors: [
                        effectiveMetrics.matchedGradientColor.swiftUIColor,
                        effectiveMetrics.matchedSolidColor.swiftUIColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .matchedSolid:
                effectiveMetrics.matchedSolidColor.swiftUIColor
            }

            VStack(spacing: 0) {
                Spacer().frame(height: gridTopSpace)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: uiScaleRef * 0.045), count: gridCols),
                    spacing: gridSpacing
                ) {
                    ForEach(Array(gridIcons.enumerated()), id: \.offset) { _, entry in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                                        .fill(entry.tint.opacity(0.32))
                                )
                                .overlay(
                                    Image(systemName: entry.symbol)
                                        .font(.system(size: iconSize * 0.44, weight: .semibold))
                                        .foregroundStyle(.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                                )
                                .frame(width: iconSize, height: iconSize)

                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.45))
                                .frame(width: iconSize * 0.62, height: max(2.5, phoneWidth * 0.012))
                        }
                    }
                }
                .padding(.horizontal, phoneWidth * 0.085)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: max(8, phoneWidth * 0.036), weight: .semibold))
                    Text(Bi("搜索", "Search"))
                        .font(.system(size: max(8, phoneWidth * 0.036), weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                .padding(.bottom, phoneHeight * 0.022)

                HStack(spacing: uiScaleRef * 0.045) {
                    ForEach(Array(dockIcons.enumerated()), id: \.offset) { _, entry in
                        RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                                    .fill(entry.tint.opacity(0.38))
                            )
                            .overlay(
                                Image(systemName: entry.symbol)
                                    .font(.system(size: iconSize * 0.44, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.6)
                            )
                            .frame(width: iconSize, height: iconSize)
                    }
                }
                .padding(.horizontal, uiScaleRef * 0.05)
                .padding(.vertical, uiScaleRef * 0.03)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: uiScaleRef * 0.095, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: uiScaleRef * 0.095, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.7)
                )
                .padding(.bottom, phoneHeight * 0.040)
            }
        }
    }

    @ViewBuilder
    private var sleepOverlay: some View {
        switch content {
        case .morph(_, _, let sleepImage, _, _, _, _, _, _, _, _, _, _):
            Color.black.opacity(sleepImage != nil ? 0.28 : 0.46)
        case .video(_, _, _, _, let dimInSleep, _):
            Color.black.opacity(dimInSleep ? 0.56 : 0.18)
        }
    }

    private var chromeOverlay: some View {
        VStack {
            // Dynamic Island
            Capsule(style: .continuous)
                .fill(Color.black)
                .frame(width: uiScaleRef * (isLandscapeCanvas ? 0.22 : 0.30), height: uiScaleRef * (isLandscapeCanvas ? 0.065 : 0.085))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
                )
                .padding(.top, phoneHeight * 0.022)

            Spacer()

            // Bottom Flashlight / Camera & Swipe Hint
            VStack(spacing: 10) {
                if !isSleepStage && !isHomePreviewActive {
                    HStack {
                        chromeCircleIcon("flashlight.off.fill")
                        Spacer()
                        Text(morphProgress > 0.65
                             ? Bi("下滑返回锁屏", "Swipe down to lock")
                             : Bi("手指上滑体验变身", "Swipe up to morph"))
                            .font(.system(size: max(10, uiScaleRef * 0.043), weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial.opacity(0.65), in: Capsule())
                        Spacer()
                        chromeCircleIcon("camera.fill")
                    }
                    .padding(.horizontal, phoneWidth * (isLandscapeCanvas ? 0.06 : 0.09))
                }

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isSleepStage ? 0.25 : 0.85))
                    .frame(width: uiScaleRef * 0.36, height: 4)
                    .padding(.bottom, 7)
            }
        }
    }

    private func chromeCircleIcon(_ name: String) -> some View {
        Circle()
            .fill(.ultraThinMaterial.opacity(0.75))
            .frame(width: uiScaleRef * 0.125, height: uiScaleRef * 0.125)
            .overlay(
                Image(systemName: name)
                    .font(.system(size: uiScaleRef * 0.052, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    private func placeholderBackdrop(isUnlock: Bool) -> some View {
        LinearGradient(
            colors: isUnlock
                ? [Color(red: 0.38, green: 0.20, blue: 0.68), Color(red: 0.94, green: 0.48, blue: 0.42)]
                : [Color(red: 0.07, green: 0.09, blue: 0.18), Color(red: 0.16, green: 0.14, blue: 0.32)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: phoneWidth, height: phoneHeight)
    }

    // MARK: - Gestures & Animations

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if gyroEnabled {
                    let tx = value.translation.width / max(phoneWidth * 0.35, 70)
                    let ty = value.translation.height / max(phoneHeight * 0.35, 110)
                    motion.setManualDragTilt(x: tx, y: ty)
                }

                guard !isHomePreviewActive else { return }

                let span = max(phoneHeight * 0.38, 120)
                let delta = -value.translation.height / span
                let base: CGFloat = (stage == .unlock) ? 1.0 : 0.0
                let next = min(max(base + delta, 0), 1)
                dragProgress = next

                if (base < 0.5 && next >= 0.45 && !crossedThresholdHaptic) ||
                   (base > 0.5 && next <= 0.55 && !crossedThresholdHaptic) {
                    crossedThresholdHaptic = true
                    CamloHaptics.impact(.rigid)
                }
            }
            .onEnded { value in
                if gyroEnabled {
                    motion.endManualDragTilt()
                }
                crossedThresholdHaptic = false

                guard !isHomePreviewActive else {
                    dragProgress = nil
                    return
                }

                let current = dragProgress ?? (stage == .unlock ? 1.0 : 0.0)
                let velocity = -value.predictedEndTranslation.height
                let shouldUnlock: Bool
                if stage == .unlock {
                    shouldUnlock = !(current < 0.65 || velocity < -90)
                } else {
                    shouldUnlock = (current > 0.36 || velocity > 90)
                }

                let anim = activeAnimation
                withAnimation(anim) {
                    dragProgress = nil
                    stage = shouldUnlock ? .unlock : .locked
                }
                CamloHaptics.selection()
            }
    }

    private var activeAnimation: Animation {
        if let timing = content.morphTiming {
            let clampedDur = min(max(timing.duration, 0.25), 1.5)
            let clampedBounce = min(max(timing.bounce, 0.0), 0.85)
            return .spring(duration: clampedDur, bounce: clampedBounce * 0.55)
        }
        return .spring(duration: 0.6, bounce: 0.18)
    }

    private func triggerStageTransition(to target: LockScreenStage) {
        CamloHaptics.selection()
        let wasLocked = (stage != .unlock)
        withAnimation(activeAnimation) {
            dragProgress = nil
            stage = target
        }
        if let timing = content.morphTiming,
           timing.preset == .flashAwaken,
           wasLocked && target == .unlock {
            flashPulseOpacity = 0.92
            withAnimation(.easeOut(duration: max(0.32, timing.duration * 0.75))) {
                flashPulseOpacity = 0
            }
        }
    }
}

// MARK: - Live Canvas Multi-Sprite & Volumetric FX Renderer for Simulator

private struct SimulatorParticleCanvas: View {
    let preset: ParticlePreset

    var body: some View {
        let assets = ParticleSpriteRenderer.assets(for: preset)
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard !assets.isEmpty else { return }
                let resolved = assets.map { context.resolve(Image(uiImage: $0.image)) }
                let t = timeline.date.timeIntervalSinceReferenceDate
                let uiScale = min(size.width, size.height) / 390.0

                switch preset {
                case .none:
                    break

                case .sunbeamRays:
                    let veil = resolved[0]
                    drawSprite(
                        veil,
                        in: &context,
                        at: CGPoint(x: size.width * (0.43 + 0.05 * sin(t * 0.55)), y: size.height * 0.46),
                        size: CGSize(width: 520 * uiScale, height: 960 * uiScale),
                        alpha: 0.56 + 0.24 * sin(t * 0.90),
                        additive: true
                    )
                    drawSprite(
                        veil,
                        in: &context,
                        at: CGPoint(x: size.width * (0.58 - 0.04 * cos(t * 0.48)), y: size.height * 0.48),
                        size: CGSize(width: 480 * uiScale, height: 920 * uiScale),
                        rotation: .radians(0.045 * sin(t * 0.45)),
                        alpha: 0.34 + 0.18 * sin(t * 0.72 + 1.4),
                        additive: true
                    )
                    if resolved.count > 1 {
                        let mote = resolved[1]
                        for i in 0..<10 {
                            let s = Double(i) * 17.31
                            let p = fract(t * (0.025 + 0.02 * hash(s)) + hash(s * 0.41))
                            let x = size.width * (0.12 + 0.72 * hash(s * 1.9) + 0.08 * p)
                            let y = size.height * (0.12 + 0.72 * fract(hash(s * 2.7) + 0.12 * p))
                            let dim = (18.0 + 14.0 * hash(s * 3.3)) * uiScale
                            let alpha = sin(p * .pi) * (0.45 + 0.45 * abs(sin(t * 1.8 + s)))
                            drawSprite(mote, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), rotation: .radians(t * 0.3 + s), alpha: alpha, additive: true)
                        }
                    }

                case .auroraRibbon:
                    let silk = resolved[0]
                    drawSprite(
                        silk,
                        in: &context,
                        at: CGPoint(x: size.width * (0.50 + 0.08 * sin(t * 0.65)), y: size.height * 0.32),
                        size: CGSize(width: 540 * uiScale, height: 600 * uiScale),
                        scaleX: 1.0 + 0.08 * sin(t * 0.80),
                        alpha: 0.60 + 0.24 * sin(t * 0.90),
                        additive: true
                    )
                    drawSprite(
                        silk,
                        in: &context,
                        at: CGPoint(x: size.width * (0.50 - 0.09 * sin(t * 0.52 + 1.1)), y: size.height * 0.48),
                        size: CGSize(width: 520 * uiScale, height: 540 * uiScale),
                        rotation: .radians(0.06 * cos(t * 0.48)),
                        scaleX: -1.0 * (0.98 + 0.06 * cos(t * 0.70)),
                        alpha: 0.42 + 0.20 * cos(t * 0.75),
                        additive: true
                    )
                    if resolved.count > 1 {
                        let flare = resolved[1]
                        for i in 0..<10 {
                            let s = Double(i) * 23.17
                            let p = fract(t * (0.04 + 0.03 * hash(s)) + hash(s * 0.53))
                            let x = size.width * (0.10 + 0.80 * hash(s * 1.3))
                            let y = size.height * (0.14 + 0.56 * hash(s * 3.1))
                            let dim = (22.0 + 14.0 * hash(s * 4.7)) * uiScale
                            let alpha = sin(p * .pi) * (0.35 + 0.55 * abs(sin(t * 2.1 + s)))
                            drawSprite(flare, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), alpha: alpha, additive: true)
                        }
                    }

                case .meteorShower:
                    if resolved.count > 1 {
                        let star = resolved[1]
                        for i in 0..<14 {
                            let s = Double(i) * 13.89
                            let x = size.width * (0.08 + 0.84 * hash(s * 1.7))
                            let y = size.height * (0.08 + 0.58 * hash(s * 2.9))
                            let pulse = 0.65 + 0.35 * sin(t * 2.2 + s)
                            let dim = (18.0 + 16.0 * hash(s * 4.1)) * pulse * uiScale
                            let alpha = 0.28 + 0.68 * pow(abs(sin(t * 1.6 + s)), 1.6)
                            drawSprite(star, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), alpha: alpha, additive: true)
                        }
                    }
                    let streak = resolved[0]
                    for i in 0..<4 {
                        let s = Double(i) * 41.7
                        let speed = 0.38 + 0.16 * hash(s * 1.2)
                        let cycle = fract(t * speed + Double(i) * 0.27)
                        let activeWindow = cycle < 0.72 ? (cycle / 0.72) : -1.0
                        guard activeWindow >= 0 else { continue }
                        let epoch = floor(t * speed + Double(i) * 0.27)
                        let startX = size.width * (0.36 + 0.72 * hash(epoch * 7.3 + s))
                        let startY = size.height * (-0.04 + 0.34 * hash(epoch * 3.9 + s))
                        let travel = size.width * 0.65 * activeWindow
                        let x = startX - travel
                        let y = startY + travel
                        let dim = (95.0 + 48.0 * hash(epoch * 5.1 + s)) * uiScale
                        let alpha = sin(activeWindow * .pi) * 0.96
                        drawSprite(streak, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), alpha: alpha, additive: true)
                    }

                case .sakura:
                    for i in 0..<18 {
                        let s = Double(i) * 19.37
                        let speed = 0.065 + 0.045 * hash(s)
                        let u = fract(t * speed + hash(s * 0.43))
                        let sway = sin(t * 1.5 + s) * 0.055
                        let x = size.width * fract(hash(s * 1.9) - u * 0.16 + sway + 1.0)
                        let y = size.height * (-0.06 + 1.12 * u)
                        let sprite = resolved[i % min(2, resolved.count)]
                        let dim = (18.0 + 12.0 * hash(s * 3.1)) * uiScale
                        let rot = t * (0.9 + 1.1 * hash(s * 2.2)) + s
                        let flip3D = 0.32 + 0.68 * abs(cos(t * 1.4 + s))
                        drawSprite(sprite, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), rotation: .radians(rot), scaleX: flip3D, alpha: 0.90)
                    }
                    if resolved.count > 2 {
                        let bokeh = resolved[2]
                        for i in 0..<3 {
                            let s = Double(i) * 53.1
                            let u = fract(t * 0.10 + Double(i) * 0.33)
                            let x = size.width * fract(0.85 - u * 0.35 + Double(i) * 0.31)
                            let y = size.height * (-0.08 + 1.18 * u)
                            let dim = (48.0 + 18.0 * hash(s)) * uiScale
                            drawSprite(bokeh, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), rotation: .radians(t * 0.5 + s), alpha: 0.72)
                        }
                    }

                case .snowfall:
                    for i in 0..<20 {
                        let s = Double(i) * 29.11
                        let isBig = (i % 2 == 0)
                        let speed = isBig ? (0.055 + 0.025 * hash(s)) : (0.036 + 0.02 * hash(s))
                        let u = fract(t * speed + hash(s * 0.37))
                        let sway = sin(t * 1.1 + s) * 0.04
                        let x = size.width * fract(hash(s * 2.3) + u * 0.09 + sway + 1.0)
                        let y = size.height * (-0.05 + 1.10 * u)
                        let sprite = resolved[isBig ? 0 : min(1, resolved.count - 1)]
                        let dim = (isBig ? (24.0 + 12.0 * hash(s * 4.1)) : (15.0 + 9.0 * hash(s * 4.1))) * uiScale
                        let rot = t * (isBig ? 0.55 : -0.38) + s
                        drawSprite(sprite, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), rotation: .radians(rot), alpha: isBig ? 0.90 : 0.72)
                    }

                case .starlight:
                    for i in 0..<18 {
                        let s = Double(i) * 17.73
                        let sprite = resolved[i % resolved.count]
                        let x = size.width * (0.08 + 0.84 * hash(s * 1.9))
                        let y = size.height * (0.08 + 0.82 * hash(s * 3.7))
                        let cycle = pow(abs(sin(t * (1.2 + 0.8 * hash(s)) + s)), 1.5)
                        let pulse = 0.62 + 0.45 * cycle
                        let dim = (24.0 + 22.0 * hash(s * 5.3)) * pulse * uiScale
                        drawSprite(sprite, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), alpha: 0.25 + 0.72 * cycle, additive: true)
                    }

                case .embers:
                    let streak = resolved[0]
                    for i in 0..<12 {
                        let s = Double(i) * 21.41
                        let speed = 0.14 + 0.09 * hash(s)
                        let u = fract(t * speed + hash(s * 0.31))
                        let wobble = sin(t * 2.6 + s) * 0.025
                        let x = size.width * fract(hash(s * 2.7) + u * 0.10 + wobble + 1.0)
                        let y = size.height * (1.06 - 1.14 * u)
                        let w = (26.0 + 16.0 * hash(s * 4.1)) * uiScale
                        let h = w * 1.25
                        let alpha = sin(u * .pi) * 0.95
                        drawSprite(streak, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: w, height: h), alpha: alpha, additive: true)
                    }
                    if resolved.count > 1 {
                        let shard = resolved[1]
                        for i in 0..<10 {
                            let s = Double(i) * 33.91
                            let speed = 0.09 + 0.06 * hash(s)
                            let u = fract(t * speed + hash(s * 0.67))
                            let x = size.width * fract(hash(s * 3.3) + u * 0.14 + sin(t * 1.8 + s) * 0.04 + 1.0)
                            let y = size.height * (1.04 - 1.10 * u)
                            let dim = (16.0 + 12.0 * hash(s * 5.7)) * uiScale
                            drawSprite(shard, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), rotation: .radians(t * 2.4 + s), alpha: (1.0 - u) * 0.90, additive: true)
                        }
                    }

                case .fireflies:
                    let wisp = resolved[0]
                    for i in 0..<12 {
                        let s = Double(i) * 27.13
                        let speed = 0.045 + 0.03 * hash(s)
                        let u = fract(t * speed + hash(s * 0.29))
                        let dx = sin(t * 1.2 + s) * 0.07
                        let x = size.width * fract(hash(s * 1.7) + u * 0.08 + dx + 1.0)
                        let y = size.height * (0.94 - 0.88 * u)
                        let dim = (26.0 + 14.0 * hash(s * 4.3)) * uiScale
                        let alpha = sin(u * .pi) * (0.55 + 0.45 * sin(t * 2.5 + s))
                        drawSprite(wisp, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), rotation: .radians(0.35 * cos(t + s)), alpha: alpha, additive: true)
                    }
                    if resolved.count > 1 {
                        let hex = resolved[1]
                        for i in 0..<5 {
                            let s = Double(i) * 47.9
                            let u = fract(t * 0.028 + Double(i) * 0.21)
                            let x = size.width * fract(hash(s * 2.1) + sin(t * 0.5 + s) * 0.06 + 1.0)
                            let y = size.height * (0.90 - 0.82 * u)
                            let dim = (44.0 + 24.0 * hash(s * 3.9)) * uiScale
                            drawSprite(hex, in: &context, at: CGPoint(x: x, y: y), size: CGSize(width: dim, height: dim), rotation: .radians(t * 0.15 + s), alpha: sin(u * .pi) * 0.65, additive: true)
                        }
                    }
                }
            }
        }
    }

    private func drawSprite(
        _ sprite: GraphicsContext.ResolvedImage,
        in context: inout GraphicsContext,
        at center: CGPoint,
        size: CGSize,
        rotation: Angle = .zero,
        scaleX: CGFloat = 1.0,
        alpha: Double = 1.0,
        additive: Bool = false
    ) {
        let clampedAlpha = min(max(alpha, 0), 1)
        guard clampedAlpha > 0.01 else { return }
        context.drawLayer { layer in
            layer.opacity = clampedAlpha
            if additive {
                layer.blendMode = .plusLighter
            }
            layer.translateBy(x: center.x, y: center.y)
            if rotation != .zero {
                layer.rotate(by: rotation)
            }
            if abs(scaleX - 1.0) > 0.001 {
                layer.scaleBy(x: scaleX, y: 1.0)
            }
            let rect = CGRect(x: -size.width * 0.5, y: -size.height * 0.5, width: size.width, height: size.height)
            layer.draw(sprite, in: rect)
        }
    }

    private func hash(_ x: Double) -> Double {
        fract(sin(x) * 43758.5453123)
    }

    private func fract(_ v: Double) -> Double {
        v - floor(v)
    }
}
