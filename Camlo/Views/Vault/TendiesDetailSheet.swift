//
//  TendiesDetailSheet.swift
//  Camlo · 开幕
//
//  X-Ray Inspector & quick actions sheet for any Vault wallpaper package (.tendies).
//

import SwiftUI
import UIKit

struct TendiesDetailSheet: View {
    let item: TendiesVaultItem
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var vault = TendiesVaultStore.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared

    @State private var report: TendiesInspectionReport?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showOpenPB = false

    private var extensionSummaryText: String {
        let entries = item.resolvedDescriptorEntries
        var uniqueExts: [String] = []
        for extID in entries.map(\.extensionBundleID) where !uniqueExts.contains(extID) {
            uniqueExts.append(extID)
        }
        if uniqueExts.count > 1 {
            let hint = PosterBoardBridge.galleryDestinationHint(for: [item])
            return Bi(
                "跨 \(uniqueExts.count) 个系统扩展 · \(hint)",
                "\(uniqueExts.count) Extensions · \(hint)"
            )
        } else if let onlyExt = uniqueExts.first, !onlyExt.isEmpty {
            if let matched = PBExtensionTarget.allCases.first(where: { $0.extensionIdentifier == onlyExt }) {
                return matched.displayName
            }
            return PBProviderCatalog.sectionTitle(for: onlyExt)
        }
        return item.targetExtension.displayName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Card
                    HStack(spacing: 14) {
                        if let thumb = vault.thumbnailImage(for: item) {
                            Color.clear
                                .frame(width: 68, height: 142)
                                .overlay {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 68, height: 142)
                                .overlay(Image(systemName: item.kind.symbol).font(.title2).foregroundStyle(Color.accentColor))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: item.kind.symbol)
                                    .font(.caption.weight(.bold))
                                Text(item.kind.badgeText)
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                            .foregroundStyle(Color.accentColor)

                            Text(item.title)
                                .font(.title3.weight(.bold))
                                .lineLimit(2)

                            Text(item.subtitleSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(extensionSummaryText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // Primary Actions
                    VStack(spacing: 10) {
                        Button {
                            let res = bridge.applyTendiesItems([item])
                            if res.0 {
                                CamloHaptics.notify(.success)
                                showOpenPB = true
                                let destinationHint = PosterBoardBridge.galleryDestinationHint(for: [item])
                                let entries = item.resolvedDescriptorEntries
                                let descrCount = max(1, entries.count)
                                let uniqueExtCount = Set(entries.map(\.extensionBundleID)).count
                                alertTitle = Bi("已写入系统锁屏画廊", "Applied to Lock Screen")
                                if uniqueExtCount > 1 {
                                    alertMessage = Bi(
                                        "「\(item.title)」共 \(descrCount) 组壁纸已跨 \(uniqueExtCount) 个系统扩展注入壁纸库（不在「照片」相册里！）。\n\n目标位置：\(destinationHint)。\n\n请点击「立即注销桌面生效」（或打开 PosterBoard 后在后台上滑划掉），随后长按锁屏点「+」号，在对应系统画廊专区即可选用！",
                                        "\"\(item.title)\" (\(descrCount) poster(s) across \(uniqueExtCount) extensions) injected into PosterBoard (not under Photos).\n\nDestination: \(destinationHint).\n\nTap 'Respring Now' (or swipe away PosterBoard), then long-press Lock Screen -> '+' to pick it."
                                    )
                                } else {
                                    alertMessage = Bi(
                                        "「\(item.title)」已注入系统壁纸库（不在「照片」里！）。\n\n目标位置：\(destinationHint)。\n\n请点击「立即注销桌面生效」（或打开 PosterBoard 后在后台上滑划掉），随后长按锁屏点「+」号，在对应系统画廊专区即可选用！",
                                        "\"\(item.title)\" is injected into PosterBoard (not under Photos).\n\nDestination: \(destinationHint).\n\nTap 'Respring Now' (or swipe away PosterBoard), then long-press Lock Screen -> '+' to pick it."
                                    )
                                }
                                showAlert = true
                            } else {
                                CamloHaptics.notify(.error)
                                showOpenPB = false
                                alertTitle = Bi("写入未完成", "Apply Incomplete")
                                alertMessage = res.1
                                showAlert = true
                            }
                        } label: {
                            Label(Bi("立即应用此壁纸到锁屏", "Apply This Wallpaper Now"), systemImage: "iphone.and.arrow.forward")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(CamloTapButtonStyle())

                        HStack(spacing: 10) {
                            Button {
                                do {
                                    let exported = try vault.exportTendiesFile(for: item)
                                    CamloShare.presentShareSheet(for: exported)
                                } catch {
                                    showOpenPB = false
                                    alertTitle = Bi("导出失败", "Export Failed")
                                    alertMessage = error.localizedDescription
                                    showAlert = true
                                }
                            } label: {
                                Label(Bi("分享 .tendies", "Share .tendies"), systemImage: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(CamloTapButtonStyle())

                            Button {
                                if let exported = try? vault.exportTendiesFile(for: item) {
                                    CamloShare.openInFilesApp(exported)
                                }
                            } label: {
                                Label(Bi("在文件中查看", "Show in Files"), systemImage: "folder")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(CamloTapButtonStyle())
                        }
                    }

                    // 120Hz Native Core Animation Interactive Preview
                    LiveCAPreviewView(item: item)

                    // CAML X-Ray Inspection Section
                    if let report {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(Bi("CAML 结构透视检查 (X-Ray)", "CAML Architecture X-Ray"), systemImage: "cpu.fill")
                                .font(.headline)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                metricTile(
                                    label: Bi("逻辑画布", "Logical Canvas"),
                                    value: "\(report.canvasWidth)×\(report.canvasHeight)",
                                    icon: "aspectratio.fill"
                                )
                                metricTile(
                                    label: Bi("壁纸包体积", "Package Size"),
                                    value: ByteCountFormatter.string(fromByteCount: report.packageSizeBytes, countStyle: .file),
                                    icon: "internaldrive.fill"
                                )
                                metricTile(
                                    label: Bi("CA 图层总数", "CALayer Count"),
                                    value: "\(report.totalLayers)",
                                    icon: "square.3.layers.3d"
                                )
                                metricTile(
                                    label: Bi("状态转场 / 关键帧", "Transitions / Anim"),
                                    value: "\(report.transitionCount) / \(report.animationCount)",
                                    icon: "waveform.path.ecg"
                                )
                                metricTile(
                                    label: Bi("壁纸引擎架构", "Wallpaper Type"),
                                    value: report.wallpaperType,
                                    icon: "cube.transparent.fill"
                                )
                                metricTile(
                                    label: Bi("锁屏时钟字体", "Clock Typography"),
                                    value: ClockFontStyle.from(posterKitIdentifier: report.clockFontIdentifier).title,
                                    icon: "textformat"
                                )
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                featureBadge(
                                    title: Bi("时钟破框前景层", "Clock Depth Layer"),
                                    active: report.hasFloatingDepth
                                )
                                featureBadge(
                                    title: Bi("硬件粒子发射器", "CAEmitter Particles"),
                                    active: report.hasEmitterParticles
                                )
                                featureBadge(
                                    title: Bi("陀螺仪 3D 视差", "3D Gyro Parallax"),
                                    active: report.hasGyroParallax
                                )
                                featureBadge(
                                    title: Bi("昼夜双生外观", "Day/Night Dual"),
                                    active: report.isAppearanceAware
                                )
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                featureBadge(
                                    title: Bi("iPhone Duo 内外双屏", "iPhone Duo Dual-Screen"),
                                    active: report.hasDuoDualCanvas
                                )
                                featureBadge(
                                    title: Bi("原生主屏柔焦虚化", "Home Legibility Blur"),
                                    active: report.hasHomeLegibilityBlur
                                )
                            }

                            if !report.stateNames.isEmpty {
                                HStack(spacing: 6) {
                                    Text(Bi("已声明状态机：", "LKState Machine:"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(report.stateNames, id: \.self) { st in
                                        Text(st)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.green.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if !report.assetImages.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(Bi("包内纹理素材预览", "Embedded Texture Assets"))
                                    .font(.headline)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(report.assetImages.enumerated()), id: \.offset) { _, pair in
                                            VStack(spacing: 4) {
                                                Image(uiImage: pair.image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 88, height: 156)
                                                    .background(pair.name.hasPrefix("particle_") ? Color(white: 0.12) : Color.black.opacity(0.08))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                Text(pair.name)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .frame(width: 88)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    } else {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 24)
                    }

                    // Destructive Delete
                    Button(role: .destructive) {
                        vault.delete(item)
                        CamloHaptics.impact(.medium)
                        dismiss()
                    } label: {
                        Label(Bi("从金库永久删除此壁纸包", "Delete from Vault"), systemImage: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(CamloTapButtonStyle())
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Bi("壁纸包透视", "Package X-Ray"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Bi("完成", "Done")) {
                        dismiss()
                    }
                }
            }
            .task(id: item.id) {
                report = nil
                let target = item
                let parsed = await Task.detached(priority: .userInitiated) {
                    TendiesVaultStore.inspectPackageFile(target)
                }.value
                guard !Task.isCancelled else { return }
                report = parsed
            }
            .alert(alertTitle, isPresented: $showAlert) {
                if showOpenPB {
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
        }
    }

    private func metricTile(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func featureBadge(title: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: active ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background((active ? Color.green : Color.secondary).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .foregroundStyle(active ? .green : .secondary)
    }
}
