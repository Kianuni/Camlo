//
//  VaultView.swift
//  Camlo · 开幕
//
//  Visual .tendies Wallpaper Vault with multi-select batch apply (safe descriptor cap),
//  external .tendies import, X-Ray inspection, and 1-tap share export.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct VaultView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var vault = TendiesVaultStore.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared

    @State private var showFileImporter = false
    @State private var inspectingItem: TendiesVaultItem?
    @State private var showHighCountConfirm = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showOpenPB = false

    private var selectedItems: [TendiesVaultItem] {
        vault.items.filter(\.isSelected)
    }

    private var selectedDescriptorCount: Int {
        selectedItems.reduce(0) { $0 + max(1, $1.resolvedDescriptorEntries.count) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if vault.items.isEmpty {
                    emptyVaultState
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 158, maximum: 220), spacing: 14)
                            ],
                            spacing: 14
                        ) {
                            ForEach(vault.items) { item in
                                vaultCard(for: item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 104)
                    }
                }

                if !vault.items.isEmpty {
                    batchApplyBar
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Bi("壁纸金库", "Tendies Vault"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !vault.items.isEmpty {
                        Button {
                            let allSelected = vault.items.allSatisfy(\.isSelected)
                            for idx in vault.items.indices {
                                vault.items[idx].isSelected = !allSelected
                            }
                            vault.saveCatalog()
                            CamloHaptics.selection()
                        } label: {
                            Text(vault.items.allSatisfy(\.isSelected)
                                 ? Bi("取消全选", "Deselect All")
                                 : Bi("全选", "Select All"))
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        InstalledWallpapersView()
                    } label: {
                        Image(systemName: "iphone.badge.checkmark")
                    }
                    .accessibilityLabel(Bi("系统已装锁屏管理", "Installed Lock Screens"))

                    NavigationLink {
                        CloudGalleryView()
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    .accessibilityLabel(Bi("云端壁纸库", "Cloud Gallery"))

                    Button {
                        showFileImporter = true
                    } label: {
                        Label(Bi("导入 .tendies", "Import"), systemImage: "plus.circle.fill")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "tendies") ?? .zip, .zip, .archive],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .sheet(item: $inspectingItem) { item in
                TendiesDetailSheet(item: item)
            }
            .alert(Bi("已选壁纸数量较多", "Many Wallpapers Selected"), isPresented: $showHighCountConfirm) {
                Button(Bi("取消", "Cancel"), role: .cancel) {}
                Button(Bi("仍然写入 (\(selectedDescriptorCount) 组)", "Apply Anyway (\(selectedDescriptorCount))")) {
                    executeBatchApply()
                }
            } message: {
                Text(Bi("单次向 PosterBoard 注入超过 5 组动态壁纸可能会延长锁屏画廊首次打开加载时间，确定继续吗？", "Injecting more than 5 animated descriptors at once may slow down PosterBoard gallery loading. Proceed?"))
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

    // MARK: - Subviews

    private var emptyVaultState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 4)

            Text(Bi("壁纸金库还是空的", "Your Tendies Vault Is Empty"))
                .font(.title3.weight(.bold))

            Text(Bi("在「开幕工坊」制作的滑动变身与动态视频壁纸，以及从外部导入的 .tendies 包都会收纳在这里。", "Wallpapers created in Studio or imported from .tendies files will appear here for inspection, sharing, and batch apply."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            HStack(spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    Label(Bi("导入 .tendies", "Import .tendies"), systemImage: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(CamloTapButtonStyle())

                Button {
                    seedSampleIntoVault()
                } label: {
                    Label(Bi("一键载入 6 套获奖风光", "Load 6 Landscape Presets"), systemImage: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(CamloTapButtonStyle())
            }
            .padding(.top, 6)

            NavigationLink {
                CloudGalleryView()
            } label: {
                Label(Bi("浏览云端 .tendies 壁纸库（330+ 精选 & 零体积）", "Browse Cloud .tendies Gallery (330+ Packs, Zero Bloat)"), systemImage: "icloud.and.arrow.down.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(CamloTapButtonStyle())
            Spacer()
        }
    }

    private func vaultCard(for item: TendiesVaultItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumb = vault.thumbnailImage(for: item) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 238)
                            .overlay {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.20, blue: 0.44), Color(red: 0.42, green: 0.22, blue: 0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(
                            Image(systemName: item.kind.symbol)
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.8))
                        )
                    }
                }
                .frame(height: 238)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: item.kind.symbol)
                            .font(.system(size: 10, weight: .bold))
                        Text(item.kind.badgeText)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
                }

                // Selection Checkbox Pill
                Button {
                    vault.toggleSelection(for: item.id)
                    CamloHaptics.selection()
                } label: {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(item.isSelected ? Color.accentColor : .white)
                        .background(Circle().fill(item.isSelected ? Color.white : Color.black.opacity(0.32)))
                        .padding(8)
                }
                .buttonStyle(CamloTapButtonStyle())
            }
            .frame(height: 238)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                inspectingItem = item
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(item.subtitleSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(item.isSelected ? Color.accentColor.opacity(0.75) : .clear, lineWidth: 1.8)
                )
        )
        .contextMenu {
            Button {
                inspectingItem = item
            } label: {
                Label(Bi("CAML 透视检查", "X-Ray Inspect"), systemImage: "cpu")
            }

            Button {
                let res = bridge.applyTendiesItems([item])
                presentApplyOutcome(
                    res,
                    count: max(1, item.resolvedDescriptorEntries.count),
                    destinationHint: PosterBoardBridge.galleryDestinationHint(for: [item])
                )
            } label: {
                Label(Bi("单独写入锁屏", "Apply to Lock Screen"), systemImage: "iphone.and.arrow.forward")
            }

            Button {
                if let url = try? vault.exportTendiesFile(for: item) {
                    CamloShare.presentShareSheet(for: url)
                }
            } label: {
                Label(Bi("分享 .tendies 文件", "Export & Share .tendies"), systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                vault.delete(item)
                CamloHaptics.impact(.medium)
            } label: {
                Label(Bi("删除", "Delete"), systemImage: "trash")
            }
        }
    }

    private var batchApplyBar: some View {
        let tooMany = selectedDescriptorCount > 15
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Bi("已选 \(selectedItems.count) 款 (\(selectedDescriptorCount) 组描述符)", "\(selectedItems.count) selected (\(selectedDescriptorCount) descriptors)"))
                    .font(.system(size: 13, weight: .bold))
                Text(tooMany
                     ? Bi("超过单次 15 组安全上限，请取消部分勾选", "Exceeds 15-descriptor safety limit")
                     : Bi("点击右侧按钮一键批量注入锁屏画廊", "Ready for 1-tap PosterBoard injection"))
                    .font(.system(size: 11))
                    .foregroundStyle(tooMany ? .red : .secondary)
            }
            Spacer()
            Button {
                if selectedDescriptorCount > 5 {
                    showHighCountConfirm = true
                } else {
                    executeBatchApply()
                }
            } label: {
                Text(Bi("批量写入锁屏", "Apply Selected"))
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        Capsule(style: .continuous)
                            .fill((selectedItems.isEmpty || tooMany) ? Color.secondary.opacity(0.3) : Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(CamloTapButtonStyle())
            .disabled(selectedItems.isEmpty || tooMany)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Actions

    private func executeBatchApply() {
        let res = bridge.applyTendiesItems(selectedItems)
        presentApplyOutcome(
            res,
            count: selectedDescriptorCount,
            destinationHint: PosterBoardBridge.galleryDestinationHint(for: selectedItems)
        )
    }

    private func presentApplyOutcome(_ res: (Bool, String), count: Int, destinationHint: String) {
        if res.0 {
            CamloHaptics.notify(.success)
            showOpenPB = true
            alertTitle = Bi("已写入 \(count) 组壁纸到系统画廊", "Applied \(count) Wallpaper(s)")
            alertMessage = Bi(
                "壁纸已写入系统壁纸库（不在「照片」相册里！）。\n\n目标位置：\(destinationHint)。\n\n1. 点击「立即注销桌面生效」（或打开 PosterBoard 后在后台上滑关闭它）刷新缓存；\n2. 长按锁屏点击「+」号，在对应系统画廊专区即可选用！",
                "Injected into PosterBoard (\(destinationHint)). Tap 'Respring Now' (or swipe away PosterBoard), then long-press Lock Screen -> '+' to pick it."
            )
            showAlert = true
        } else {
            CamloHaptics.notify(.error)
            showOpenPB = false
            alertTitle = Bi("写入失败", "Apply Failed")
            alertMessage = res.1
            showAlert = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var ok = 0
            var errText: String?
            for u in urls {
                let scoped = u.startAccessingSecurityScopedResource()
                defer { if scoped { u.stopAccessingSecurityScopedResource() } }
                do {
                    _ = try vault.importExternalTendies(from: u)
                    ok += 1
                } catch {
                    errText = error.localizedDescription
                }
            }
            if ok > 0 {
                CamloHaptics.notify(.success)
            } else if let errText {
                CamloHaptics.notify(.error)
                showOpenPB = false
                alertTitle = Bi("导入失败", "Import Failed")
                alertMessage = errText
                showAlert = true
            }
        case .failure(let error):
            CamloHaptics.notify(.error)
            showOpenPB = false
            alertTitle = Bi("导入失败", "Import Failed")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func seedSampleIntoVault() {
        for demo in SampleArtGenerator.allDemos.reversed() {
            if vault.items.contains(where: { $0.title == demo.title }) { continue }
            let imgs = demo.buildImages()
            let spec = MorphCompileSpec(
                title: demo.title,
                lockImage: imgs.lock,
                unlockImage: imgs.unlock,
                customSleepImage: nil,
                lockSubjectCutout: imgs.lockCutout,
                unlockSubjectCutout: imgs.unlockCutout,
                preset: demo.recommendedPreset,
                durationSeconds: 0.75,
                springBounce: 0.30,
                particlePreset: demo.recommendedParticles
            )
            _ = try? vault.createMorphPackage(spec: spec)
        }
        CamloHaptics.notify(.success)
    }
}
