//
//  StudioHomeView.swift
//  Camlo · 开幕
//
//  Main landing studio screen with Apple Editorial Bento creation cards,
//  1-tap built-in sample launchers, .tendies quick import, and container status indicator.
//

import SwiftUI
import UniformTypeIdentifiers

struct StudioHomeView: View {
    @Binding var selectedTab: Int

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared
    @ObservedObject private var vault = TendiesVaultStore.shared

    @State private var showQuickImporter = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false
    @State private var selectedDemoFilter: DemoCategoryFilter = .all

    // Cached preview thumbnails for the flagship Morph hero card (loaded once in .task)
    @State private var flagshipLockThumb: UIImage?
    @State private var flagshipUnlockThumb: UIImage?

    private static let indigoAccent = Color(red: 0.48, green: 0.42, blue: 1.0)
    private static let cyanAccent = Color(red: 0.24, green: 0.68, blue: 0.98)
    private static let amethystAccent = Color(red: 0.62, green: 0.46, blue: 0.98)

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var hairlineBorderColor: Color {
        isDark ? Color.white.opacity(0.11) : Color.black.opacity(0.06)
    }

    private var filteredDemos: [BuiltInDemoPack] {
        switch selectedDemoFilter {
        case .all:
            return SampleArtGenerator.allDemos
        case .nature, .creative:
            return SampleArtGenerator.allDemos.filter { $0.filterGroup == selectedDemoFilter }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // 1. Editorial Studio Header
                    heroBanner

                    // 2. Primary Creation Modes (Flagship Hero + 2-Column Bento Duo)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Bi("选择创作模式", "Create Wallpaper"))
                            .font(.system(.headline, design: .rounded).weight(.bold))

                        NavigationLink {
                            MorphEditorView()
                        } label: {
                            flagshipMorphCard
                        }
                        .buttonStyle(CamloTapButtonStyle())

                        secondaryBentoRow
                    }

                    // 3. Official HD Paired Presets Gallery
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Bi("官方精选变身画廊 (11 套内置)", "Official Transformation Gallery (11 Packs)"))
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                Text(Bi("像素级对齐锁屏 ↔ 解锁双态，点开即可体验或一键上锁屏", "Pixel-aligned Lock <-> Unlock pairs with pre-extracted Clock Depth"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DemoCategoryFilter.allCases) { filter in
                                    let isSelected = selectedDemoFilter == filter
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                            selectedDemoFilter = filter
                                        }
                                        CamloHaptics.selection()
                                    } label: {
                                        Text(filter.title)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                                in: Capsule()
                                            )
                                            .overlay {
                                                if !isSelected {
                                                    Capsule()
                                                        .strokeBorder(hairlineBorderColor, lineWidth: 0.8)
                                                }
                                            }
                                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(CamloTapButtonStyle())
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(filteredDemos) { demo in
                                    NavigationLink {
                                        MorphEditorView(initialDemo: demo)
                                    } label: {
                                        presetGalleryCard(demo)
                                    }
                                    .buttonStyle(CamloTapButtonStyle())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // 4. Quick Import External .tendies
                    Button {
                        showQuickImporter = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.orange.opacity(isDark ? 0.18 : 0.12))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.orange.opacity(isDark ? 0.28 : 0.16), lineWidth: 0.8)
                                    }
                                Image(systemName: "shippingbox.and.arrow.backward.fill")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Bi("导入外部 .tendies 壁纸包", "Import External .tendies"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(Bi("完全兼容 CAPlayground / Nugget / 社区分享壁纸，支持透视检查与一键写入", "Compatible with CAPlayground, Nugget & community .tendies archives"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            microChevronBadge
                        }
                        .padding(14)
                        .background {
                            editorialCardSurface(
                                cornerRadius: 18,
                                accentGlow: .orange,
                                glowAnchor: .leading,
                                glowIntensity: isDark ? 0.08 : 0.05
                            )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(CamloTapButtonStyle())

                    // 5. 3-Step Usage Guide
                    quickGuideCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Bi("开幕 Camlo", "Camlo Studio"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedTab = 2
                    } label: {
                        let statusColor: Color = bridge.hasContainerAccess ? .green : (bridge.isScanning ? .orange : .secondary)
                        HStack(spacing: 6) {
                            ZStack {
                                if bridge.hasContainerAccess || bridge.isScanning {
                                    Circle()
                                        .fill(statusColor.opacity(0.24))
                                        .frame(width: 12, height: 12)
                                }
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 7, height: 7)
                            }
                            Text(bridge.hasContainerAccess
                                 ? Bi("直写就绪", "Direct Ready")
                                 : (bridge.isScanning ? Bi("连接中", "Scanning") : Bi("导出模式", "Export Mode")))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(hairlineBorderColor, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }
            }
            .task {
                await loadFlagshipPreviewThumbnailsIfNeeded()
            }
            .fileImporter(
                isPresented: $showQuickImporter,
                allowedContentTypes: [UTType(filenameExtension: "tendies") ?? .zip, .zip, .archive],
                allowsMultipleSelection: true
            ) { result in
                handleImportResult(result)
            }
            .alert(importAlertTitle, isPresented: $showImportAlert) {
                Button(Bi("前往壁纸金库", "View in Vault")) {
                    selectedTab = 1
                }
                Button(Bi("好的", "OK"), role: .cancel) {}
            } message: {
                Text(importAlertMessage)
            }
        }
    }

    // MARK: - Editorial Surfaces & Shared Micro-Components

    private func editorialCardSurface(
        cornerRadius: CGFloat,
        accentGlow: Color,
        glowAnchor: UnitPoint = .topTrailing,
        glowIntensity: Double? = nil
    ) -> some View {
        let opacity = min(glowIntensity ?? (isDark ? 0.13 : 0.08), isDark ? 0.14 : 0.09)
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [accentGlow.opacity(opacity), accentGlow.opacity(0.0)],
                            center: glowAnchor,
                            startRadius: 8,
                            endRadius: 230
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(hairlineBorderColor, lineWidth: 0.8)
            }
            .shadow(color: isDark ? .clear : Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var microChevronBadge: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .background(Color.primary.opacity(isDark ? 0.08 : 0.05), in: Circle())
    }

    private func stageCornerPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.45), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.6)
            }
    }

    // MARK: - 1. Hero Header

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                camloMonogramBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(Bi("开幕 Camlo", "Camlo Studio"))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                    Text(Bi("亮屏即开幕，上滑即变身", "Wake to unveil. Swipe to transform."))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(Bi("零代码原生 Core Animation (.tendies) 锁屏工坊，免电脑直写 iOS 26 / iOS 27 锁屏画廊。", "Zero-code native Core Animation (.tendies) Lock Screen studio with direct on-device PosterBoard apply."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    heroMicroBadge(
                        Bi("原生 CAML", "Native CAML"),
                        icon: "cube.transparent",
                        accent: Self.indigoAccent,
                        tinted: true
                    )
                    heroMicroBadge(
                        Bi("120Hz 预览", "120Hz Preview"),
                        icon: "sparkles",
                        accent: Self.amethystAccent,
                        tinted: false
                    )
                    heroMicroBadge(
                        "iOS 26 / 27",
                        icon: "iphone.gen3",
                        accent: Self.cyanAccent,
                        tinted: false
                    )
                }
            }
        }
        .padding(16)
        .background {
            editorialCardSurface(
                cornerRadius: 22,
                accentGlow: Self.indigoAccent,
                glowAnchor: .topTrailing,
                glowIntensity: isDark ? 0.13 : 0.08
            )
        }
    }

    private var camloMonogramBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Self.indigoAccent,
                            Self.amethystAccent.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.42), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }

            // Sculpted twin-curtain Lock Screen monogram
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 14, height: 22)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -5, y: 1)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 15, height: 24)
                    .overlay(alignment: .center) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Self.indigoAccent)
                    }
                    .rotationEffect(.degrees(6))
                    .offset(x: 4, y: -1)
                    .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
            }
            .accessibilityHidden(true)
        }
        .frame(width: 48, height: 48)
    }

    private func heroMicroBadge(_ title: String, icon: String, accent: Color, tinted: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tinted ? accent : .secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(tinted ? (isDark ? Color(red: 0.84, green: 0.81, blue: 1.0) : accent) : .secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            tinted ? accent.opacity(isDark ? 0.16 : 0.09) : Color.primary.opacity(isDark ? 0.06 : 0.045),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    tinted ? accent.opacity(isDark ? 0.28 : 0.16) : hairlineBorderColor,
                    lineWidth: 0.7
                )
        }
    }

    // MARK: - 2. Flagship Hero Card & 2-Column Bento Duo

    private var flagshipMorphCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    flagshipEditorialColumn
                    flagshipVisualStage
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    flagshipEditorialColumn
                    flagshipVisualStage
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            editorialCardSurface(
                cornerRadius: 22,
                accentGlow: Self.indigoAccent,
                glowAnchor: .trailing,
                glowIntensity: isDark ? 0.14 : 0.085
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var flagshipEditorialColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Frosted indigo badge
            HStack(spacing: 5) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(Bi("核心工坊", "FLAGSHIP"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.3)
            }
            .foregroundStyle(isDark ? Color(red: 0.80, green: 0.77, blue: 1.0) : Self.indigoAccent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Self.indigoAccent.opacity(isDark ? 0.20 : 0.10), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Self.indigoAccent.opacity(isDark ? 0.34 : 0.18), lineWidth: 0.7)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Bi("滑动解锁变身", "Slide-to-Morph"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(Bi("熄屏 → 锁屏 → 上滑变身，支持昼夜双生与前景破框", "Sleep -> Lock -> Unlock transitions with Day/Night & AI Depth"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Text("\(Bi("昼夜双生", "Day/Night")) · \(Bi("3D 视差", "3D Parallax")) · \(Bi("AI 破框", "AI Depth"))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            // Compact frosted CTA pill
            HStack(spacing: 5) {
                Text(Bi("开始创作", "Create Now"))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(isDark ? Color(red: 0.88, green: 0.86, blue: 1.0) : Color(red: 0.34, green: 0.27, blue: 0.86))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Self.indigoAccent.opacity(isDark ? 0.24 : 0.11), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Self.indigoAccent.opacity(isDark ? 0.38 : 0.20), lineWidth: 0.75)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var flagshipVisualStage: some View {
        ZStack {
            // Whisper-soft stage aura behind miniature frames
            Circle()
                .fill(Self.indigoAccent.opacity(isDark ? 0.18 : 0.11))
                .frame(width: 88, height: 88)
                .blur(radius: 18)

            // Back Lock Screen card (-6 deg)
            miniLockScreenFrame(
                image: flagshipLockThumb,
                fallbackColors: [Color(red: 0.09, green: 0.13, blue: 0.28), Color(red: 0.22, green: 0.25, blue: 0.48)],
                cornerRadius: 11,
                borderColor: Color.white.opacity(0.28),
                borderWidth: 0.8
            ) {
                VStack(spacing: 1) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("09:41")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.94))
                }
                .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                .padding(.top, 9)
            }
            .frame(width: 54, height: 96)
            .shadow(color: Color.black.opacity(isDark ? 0.45 : 0.16), radius: 7, x: -2, y: 5)
            .rotationEffect(.degrees(-6))
            .offset(x: -12, y: 4)

            // Front Unlock Screen card (+5 deg)
            miniLockScreenFrame(
                image: flagshipUnlockThumb,
                fallbackColors: [Self.indigoAccent, Color(red: 0.76, green: 0.42, blue: 0.62)],
                cornerRadius: 12,
                borderColor: Color.white.opacity(isDark ? 0.62 : 0.85),
                borderWidth: 1.2
            ) {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Self.indigoAccent.opacity(0.88))
                                    .overlay {
                                        Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 0.7)
                                    }
                            )
                            .shadow(color: Self.indigoAccent.opacity(0.60), radius: 6, x: 0, y: 0)
                            .padding(5)
                    }
                }
            }
            .frame(width: 56, height: 100)
            .shadow(color: Color.black.opacity(isDark ? 0.52 : 0.22), radius: 10, x: 2, y: 6)
            .rotationEffect(.degrees(5))
            .offset(x: 10, y: -2)
        }
        .frame(width: 98, height: 136)
        .accessibilityHidden(true)
    }

    private func miniLockScreenFrame<OverlayContent: View>(
        image: UIImage?,
        fallbackColors: [Color],
        cornerRadius: CGFloat,
        borderColor: Color,
        borderWidth: CGFloat,
        @ViewBuilder overlay: () -> OverlayContent
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: fallbackColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                if let image {
                    Color.clear
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                }
            }
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.22), .clear, Color.black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                overlay()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
    }

    @ViewBuilder
    private var secondaryBentoRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                videoBentoLink
                cloudBentoLink
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                videoBentoLink
                cloudBentoLink
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var videoBentoLink: some View {
        NavigationLink {
            VideoEditorView()
        } label: {
            bentoModeCard(
                title: Bi("视频与实况", "Video & Live"),
                subtitle: Bi("MP4 / 实况转不杀后台循环，支持视差与柔焦", "Clips & Live Photos into seamless CAML loops"),
                tag: Bi("动态序列", "Motion Loop"),
                accent: Self.cyanAccent,
                tagForeground: isDark ? Color(red: 0.52, green: 0.86, blue: 1.0) : Color(red: 0.08, green: 0.48, blue: 0.80),
                glowAnchor: .topLeading
            ) {
                videoStageWindow
            }
        }
        .buttonStyle(CamloTapButtonStyle())
    }

    private var cloudBentoLink: some View {
        NavigationLink {
            CloudGalleryView()
        } label: {
            bentoModeCard(
                title: Bi("云端壁纸广场", "Cloud Gallery"),
                subtitle: Bi("四大社区频道免占体积，120Hz 试穿秒下", "4 curated channels, zero bloat, 120Hz try-on"),
                tag: Bi("免费直连", "Direct OTA"),
                accent: Self.amethystAccent,
                tagForeground: isDark ? Color(red: 0.82, green: 0.74, blue: 1.0) : Color(red: 0.44, green: 0.28, blue: 0.86),
                glowAnchor: .topTrailing
            ) {
                cloudStageWindow
            }
        }
        .buttonStyle(CamloTapButtonStyle())
    }

    private func bentoModeCard<Stage: View>(
        title: String,
        subtitle: String,
        tag: String,
        accent: Color,
        tagForeground: Color,
        glowAnchor: UnitPoint,
        @ViewBuilder stage: () -> Stage
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            stage()

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 2)

            HStack(spacing: 6) {
                Text(tag)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(tagForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(isDark ? 0.17 : 0.11), in: Capsule())

                Spacer(minLength: 4)

                microChevronBadge
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            editorialCardSurface(
                cornerRadius: 20,
                accentGlow: accent,
                glowAnchor: glowAnchor,
                glowIntensity: isDark ? 0.12 : 0.075
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var videoStageWindow: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.14, blue: 0.22),
                    Color(red: 0.10, green: 0.24, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                RadialGradient(
                    colors: [Self.cyanAccent.opacity(0.32), .clear],
                    center: .bottomLeading,
                    startRadius: 4,
                    endRadius: 96
                )
            }

            HStack(spacing: 8) {
                // Concentric Live Photo aperture rings
                ZStack {
                    Circle()
                        .stroke(Self.cyanAccent.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(Self.cyanAccent.opacity(0.50), lineWidth: 1)
                        .frame(width: 32, height: 32)
                    Circle()
                        .fill(Self.cyanAccent.opacity(0.24))
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8)
                        }
                    Image(systemName: "play.fill")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 0.5)
                }
                .offset(x: -4, y: 8)

                // 3 fanned micro motion sequence frames
                ZStack {
                    fannedMotionFrame(
                        colors: [Color(red: 0.16, green: 0.38, blue: 0.58), Color(red: 0.10, green: 0.20, blue: 0.36)],
                        alpha: 0.45
                    )
                    .rotationEffect(.degrees(-8))
                    .offset(x: -9, y: 2)

                    fannedMotionFrame(
                        colors: [Color(red: 0.18, green: 0.50, blue: 0.76), Color(red: 0.16, green: 0.28, blue: 0.52)],
                        alpha: 0.72
                    )
                    .rotationEffect(.degrees(0))

                    fannedMotionFrame(
                        colors: [Self.cyanAccent, Self.indigoAccent],
                        alpha: 0.96
                    )
                    .rotationEffect(.degrees(8))
                    .offset(x: 9, y: 2)
                }
                .offset(x: 4, y: 10)
            }
            .accessibilityHidden(true)

            VStack {
                HStack {
                    Spacer()
                    stageCornerPill(Bi("LIVE · 60帧", "LIVE · 60fps"))
                }
                Spacer()
            }
            .padding(7)
        }
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(isDark ? 0.12 : 0.18), lineWidth: 0.7)
        }
    }

    private func fannedMotionFrame(colors: [Color], alpha: Double) -> some View {
        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(width: 22, height: 38)
            .overlay {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(alpha * 0.60), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 2)
    }

    private var cloudStageWindow: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.22),
                    Color(red: 0.18, green: 0.15, blue: 0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                RadialGradient(
                    colors: [Self.amethystAccent.opacity(0.32), .clear],
                    center: .bottom,
                    startRadius: 4,
                    endRadius: 92
                )
            }

            // 3 fanned miniature 9:16 .tendies poster frames (-11, 0, +11)
            ZStack {
                miniPosterCard(
                    colors: [Color(red: 0.20, green: 0.50, blue: 0.78), Color(red: 0.12, green: 0.22, blue: 0.44)],
                    width: 26,
                    height: 46,
                    borderOpacity: 0.36
                )
                .rotationEffect(.degrees(-11))
                .offset(x: -21, y: 15)

                miniPosterCard(
                    colors: [Color(red: 0.76, green: 0.40, blue: 0.62), Color(red: 0.32, green: 0.20, blue: 0.52)],
                    width: 26,
                    height: 46,
                    borderOpacity: 0.36
                )
                .rotationEffect(.degrees(11))
                .offset(x: 21, y: 15)

                miniPosterCard(
                    colors: [Self.indigoAccent, Self.amethystAccent],
                    width: 30,
                    height: 50,
                    borderOpacity: 0.68
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 10, height: 2.2)
                        .padding(.top, 5)
                }
                .shadow(color: .black.opacity(0.38), radius: 6, x: 0, y: 3)
                .offset(x: 0, y: 12)
            }
            .accessibilityHidden(true)

            VStack {
                HStack {
                    Spacer()
                    stageCornerPill(Bi("330+ 精选", "330+ Curated"))
                }
                Spacer()
            }
            .padding(7)
        }
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(isDark ? 0.12 : 0.18), lineWidth: 0.7)
        }
    }

    private func miniPosterCard(colors: [Color], width: CGFloat, height: CGFloat, borderOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 0.85)
            }
            .shadow(color: .black.opacity(0.24), radius: 4, x: 0, y: 2)
    }

    // MARK: - 3. Quick Guide & Presets

    private var quickGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(Bi("三步生效指南（必看位置说明）", "How It Works in 3 Steps"), systemImage: "lightbulb.max.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            guideRow(num: "1", text: Bi("选好预设或自定义图片后点击「一键应用到锁屏」，在弹窗点「立即注销桌面生效」（或打开 PosterBoard 在后台上滑划掉）刷新缓存", "Tap '1-Tap Apply to Lock Screen', then tap 'Respring Now' (or swipe away PosterBoard in App Switcher) to reload"))
            guideRow(num: "2", text: Bi("在锁屏界面长按空白处，点击右下角蓝色「+」号进入添加新墙纸页面", "Long-press your iOS Lock Screen and tap the blue '+' button"))
            guideRow(num: "3", text: Bi("不要点「照片」！就在「专为你的 iPhone 设计的墙纸」横排里（紧挨系统默认粉色壁纸的第 2 张起），老机型或旧系统则滑到底部「收藏」专区即可看到！", "Don't tap 'Photos'! Find it inside your device-exclusive wallpaper row (right beside the default pink card at #2) — or scroll down to 'Collections' on older models!"))
        }
        .padding(15)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(hairlineBorderColor, lineWidth: 0.8)
        }
    }

    private func guideRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(Color.accentColor.opacity(0.16), in: Circle())
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func galleryThumbTile(_ image: UIImage, label: String, alignment: Alignment, badgeBg: Color) -> some View {
        Color.clear
            .frame(width: 112, height: 186)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: alignment) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeBg, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }
    }

    private func presetGalleryCard(_ demo: BuiltInDemoPack) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottom) {
                HStack(spacing: 2) {
                    if let lThumb = demo.lockThumbnail {
                        galleryThumbTile(
                            lThumb,
                            label: Bi("锁屏", "Lock"),
                            alignment: .topLeading,
                            badgeBg: .black.opacity(0.55)
                        )
                    }
                    if let uThumb = demo.unlockThumbnail {
                        galleryThumbTile(
                            uThumb,
                            label: Bi("解锁", "Unlock"),
                            alignment: .topTrailing,
                            badgeBg: Color.accentColor.opacity(0.88)
                        )
                    }
                }
                .frame(height: 186)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .clipped()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .offset(y: -82)
            }

            HStack(spacing: 5) {
                Text(demo.categoryBadge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.accentColor)

                Text(demo.recommendedPreset.title)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)

                if demo.hasDepthCutout {
                    Text(Bi("破框", "Depth"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                }
            }

            Text(demo.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(demo.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(10)
        .frame(width: 246, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(hairlineBorderColor, lineWidth: 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Helpers

    private func loadFlagshipPreviewThumbnailsIfNeeded() async {
        guard flagshipLockThumb == nil || flagshipUnlockThumb == nil,
              let firstDemoID = SampleArtGenerator.allDemos.first?.id else { return }

        let pair: (UIImage?, UIImage?) = await Task.detached(priority: .userInitiated) {
            let lock = SampleArtGenerator.loadThumbnailImage(named: "\(firstDemoID)_thumb_lock.jpg")
            let unlock = SampleArtGenerator.loadThumbnailImage(named: "\(firstDemoID)_thumb_unlock.jpg")
            return (lock, unlock)
        }.value

        if flagshipLockThumb == nil {
            flagshipLockThumb = pair.0
        }
        if flagshipUnlockThumb == nil {
            flagshipUnlockThumb = pair.1
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var importedCount = 0
            var lastErr: String?
            for u in urls {
                let hasScope = u.startAccessingSecurityScopedResource()
                defer { if hasScope { u.stopAccessingSecurityScopedResource() } }
                do {
                    _ = try vault.importExternalTendies(from: u)
                    importedCount += 1
                } catch {
                    lastErr = error.localizedDescription
                }
            }
            if importedCount > 0 {
                CamloHaptics.notify(.success)
                importAlertTitle = Bi("成功导入 \(importedCount) 个壁纸包", "Imported \(importedCount) Package(s)")
                importAlertMessage = Bi("已自动修复描述符 ID 并存入「壁纸金库」，现在可直接预览检查或一键写入锁屏。", "Saved to Vault with randomized PosterBoard IDs.")
                showImportAlert = true
            } else if let lastErr {
                CamloHaptics.notify(.error)
                importAlertTitle = Bi("导入失败", "Import Failed")
                importAlertMessage = lastErr
                showImportAlert = true
            }
        case .failure(let err):
            CamloHaptics.notify(.error)
            importAlertTitle = Bi("导入失败", "Import Failed")
            importAlertMessage = err.localizedDescription
            showImportAlert = true
        }
    }
}
