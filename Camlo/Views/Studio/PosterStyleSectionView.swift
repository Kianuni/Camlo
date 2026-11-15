//
//  PosterStyleSectionView.swift
//  Camlo · 开幕
//
//  Shared Studio authoring controls for ParameterizedCA 3D Gyroscope Parallax,
//  Smart Clock Typography & Contrast Color, and PosterKit Home Screen Pairing.
//

import SwiftUI

struct PosterStyleSectionView: View {
    @Binding var enableGyroParallax: Bool
    @Binding var gyroIntensity: Double
    @Binding var posterStyle: PosterStyleSpec
    @Binding var showHomeScreenPreview: Bool
    let paletteMetrics: WallpaperPaletteMetrics?
    var gyroSectionTitle: String = Bi("陀螺仪 3D 裸眼视差 (ParameterizedCA)", "3D Gyroscope Parallax (ParameterizedCA)")
    var styleSectionTitle: String = Bi("智能时钟字体配色 & 主屏柔焦配套", "Smart Clock Style & Home Screen Pairing")

    @ObservedObject private var motion = MotionTiltManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            gyroCard
            smartStyleCard
        }
    }

    // MARK: - Gyro 3D Parallax Card

    private var gyroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(gyroSectionTitle, systemImage: "gyroscope")
                    .font(.headline)
                Spacer()
                Text("120Hz")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.16), in: Capsule())
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableGyroParallax.animation(.spring(response: 0.35, dampingFraction: 0.85))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Bi("启用陀螺仪 3D 裸眼空间视差", "Enable 3D Gyroscope Spatial Parallax"))
                            .font(.subheadline.weight(.semibold))
                        Text(Bi("自动生成防露边超采样背景层与反相前景/粒子平面，晃动手机呈现裸眼景深", "Compiles ParameterizedCA wallpaperParallaxGroups with overscanned background & inverse depth planes"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.purple)

                if enableGyroParallax {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(Bi("立体视差深度", "Parallax Depth"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int((gyroIntensity * 100).rounded()))%")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.purple)
                        }
                        Slider(value: $gyroIntensity, in: 0.25...1.0, step: 0.05)
                            .tint(.purple)
                    }

                    HStack(spacing: 8) {
                        Button {
                            CamloHaptics.selection()
                            motion.isAutoOrbitDemo.toggle()
                        } label: {
                            Label(
                                motion.isAutoOrbitDemo ? Bi("停止自动摆动", "Stop Auto Orbit") : Bi("一键 3D 摆动演示", "Auto 3D Orbit Demo"),
                                systemImage: motion.isAutoOrbitDemo ? "pause.circle.fill" : "move.3d"
                            )
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                motion.isAutoOrbitDemo ? Color.purple : Color.purple.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .foregroundStyle(motion.isAutoOrbitDemo ? .white : .purple)
                        }
                        .buttonStyle(.plain)

                        Button {
                            CamloHaptics.selection()
                            motion.isAutoOrbitDemo = false
                            motion.recenter()
                        } label: {
                            Label(Bi("视角归零", "Recenter"), systemImage: "scope")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Smart Clock & Home Screen Card

    private var smartStyleCard: some View {
        let metrics = paletteMetrics ?? .neutralFallback
        let lumPct = Int((metrics.clockLuminance * 100.0).rounded())
        let isBrightSky = metrics.clockLuminance > 0.60

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(styleSectionTitle, systemImage: "textformat.alt")
                    .font(.headline)
                Spacer()
                Button {
                    CamloHaptics.selection()
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                        showHomeScreenPreview.toggle()
                    }
                } label: {
                    Label(
                        showHomeScreenPreview ? Bi("返回锁屏", "Lock View") : Bi("预览主屏", "Preview Home"),
                        systemImage: showHomeScreenPreview ? "lock.fill" : "apps.iphone"
                    )
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        showHomeScreenPreview ? Color.accentColor : Color.accentColor.opacity(0.14),
                        in: Capsule()
                    )
                    .foregroundStyle(showHomeScreenPreview ? .white : Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                // Live Palette Inspection Pill
                HStack(spacing: 8) {
                    Image(systemName: isBrightSky ? "sun.max.fill" : "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isBrightSky ? .orange : .accentColor)

                    Text(
                        paletteMetrics != nil
                        ? (isBrightSky
                           ? Bi("时间区亮度 \(lumPct)% · 亮天高光，建议高反差深墨", "Clock sky \(lumPct)% bright · Smart Ink recommended")
                           : Bi("时间区亮度 \(lumPct)% · 通透深底，推荐高亮/同色白", "Clock sky \(lumPct)% · Crisp light contrast recommended"))
                        : Bi("导入壁纸后自动分析顶部亮度与主题色板", "Select wallpaper to analyze clock sky luminance & palette")
                    )
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(metrics.accentColor.swiftUIColor)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8))
                        Circle()
                            .fill(metrics.matchedGradientColor.swiftUIColor)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8))
                        Circle()
                            .fill(metrics.matchedSolidColor.swiftUIColor)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Clock Typography
                VStack(alignment: .leading, spacing: 6) {
                    Text(Bi("锁屏时钟字体 (PosterKit)", "Lock Screen Clock Typography"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ClockFontStyle.allCases) { font in
                                let selected = posterStyle.clockFont == font
                                Button {
                                    CamloHaptics.selection()
                                    posterStyle.clockFont = font
                                } label: {
                                    VStack(spacing: 3) {
                                        Text("09:41")
                                            .font(font.swiftUIFont(size: 19))
                                            .fontWidth(font.fontWidth)
                                            .tracking(font.letterSpacing * 0.5)
                                        Text(font.title)
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .frame(width: 72, height: 52)
                                    .background(
                                        selected ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .foregroundStyle(selected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Clock Color Mode
                VStack(alignment: .leading, spacing: 6) {
                    Text(Bi("锁屏时钟配色策略", "Clock Color Strategy"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ClockColorMode.allCases) { mode in
                                let selected = posterStyle.clockColorMode == mode
                                let swatch = PosterStyleGenerator.previewClockColor(mode: mode, metrics: metrics).swiftUIColor
                                Button {
                                    CamloHaptics.selection()
                                    posterStyle.clockColorMode = mode
                                } label: {
                                    HStack(spacing: 6) {
                                        if mode == .systemAuto {
                                            Circle()
                                                .fill(
                                                    AngularGradient(
                                                        colors: [.white, .cyan, .indigo, .orange, .white],
                                                        center: .center
                                                    )
                                                )
                                                .frame(width: 13, height: 13)
                                                .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.8))
                                        } else {
                                            Circle()
                                                .fill(swatch)
                                                .frame(width: 13, height: 13)
                                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.8))
                                        }
                                        Text(mode.title)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        selected ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(selected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Home Screen Pairing
                VStack(alignment: .leading, spacing: 6) {
                    Text(Bi("主屏幕配套外观 (PosterKit)", "Home Screen Companion Style"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(HomeScreenPairingMode.allCases) { mode in
                            let selected = posterStyle.homePairing == mode
                            Button {
                                CamloHaptics.selection()
                                posterStyle.homePairing = mode
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 5) {
                                        Image(systemName: icon(for: mode))
                                            .font(.caption.weight(.bold))
                                        Text(mode.title)
                                            .font(.caption.weight(.bold))
                                            .lineLimit(1)
                                    }
                                    Text(mode.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundStyle(selected ? .white.opacity(0.86) : .secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    selected ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .foregroundStyle(selected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func icon(for mode: HomeScreenPairingMode) -> String {
        switch mode {
        case .legibilityBlur:  return "drop.halffull"
        case .clearMatch:      return "rectangle.on.rectangle"
        case .matchedGradient: return "circle.lefthalf.filled.inverse"
        case .matchedSolid:    return "square.fill"
        }
    }
}
