//
//  CloudGalleryView.swift
//  Camlo · 开幕
//
//  Multi-channel OTA cloud .tendies gallery:
//  Camlo Official + CAPlayground (180+) + Nugget Custom (110+) + Apple Collections (30+)
//  with static thumbnail grids, animated GIF detail previews, search, sort, and HEAD latency racing.
//

import SwiftUI
import UIKit

struct CloudGalleryView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var manager = CloudGalleryManager.shared
    @ObservedObject private var appSource = AppSourceManager.shared
    @ObservedObject private var vault = TendiesVaultStore.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared

    @State private var selectedCategory: CloudWallpaperCategory = .all
    @State private var searchText = ""
    @State private var sortOrder: CloudSortOrder = .featured

    @State private var previewPack: CloudWallpaperPack?
    @State private var previewCommunityPack: CommunityWallpaperPack?
    @State private var inspectItem: TendiesVaultItem?

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showApplyActions = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var filteredOfficialPacks: [CloudWallpaperPack] {
        let base: [CloudWallpaperPack]
        switch selectedCategory {
        case .all:
            base = manager.packs
        case .motion:
            base = manager.packs.filter { $0.category == "motion" }
        case .morph:
            base = manager.packs.filter { $0.category == "morph" }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = query.isEmpty ? base : base.filter { pack in
            pack.localizedTitle.localizedCaseInsensitiveContains(query)
                || pack.localizedSubtitle.localizedCaseInsensitiveContains(query)
                || pack.id.localizedCaseInsensitiveContains(query)
                || pack.localizedTags.contains { $0.localizedCaseInsensitiveContains(query) }
        }

        switch sortOrder {
        case .featured:
            return searched
        case .newest:
            return searched.reversed()
        case .nameAscending:
            return searched.sorted {
                $0.localizedTitle.localizedCaseInsensitiveCompare($1.localizedTitle) == .orderedAscending
            }
        }
    }

    private var filteredCommunityPacks: [CommunityWallpaperPack] {
        let raw = manager.communityPacksByChannel[manager.selectedChannel] ?? []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = query.isEmpty ? raw : raw.filter { pack in
            pack.name.localizedCaseInsensitiveContains(query)
                || pack.description.localizedCaseInsensitiveContains(query)
                || pack.displayAuthor.localizedCaseInsensitiveContains(query)
                || (pack.originTag?.localizedCaseInsensitiveContains(query) ?? false)
        }

        switch sortOrder {
        case .featured:
            return searched.sorted { a, b in
                if a.isContest != b.isContest { return a.isContest && !b.isContest }
                return a.orderIndex < b.orderIndex
            }
        case .newest:
            return searched.sorted { a, b in
                let dA = a.dateString ?? ""
                let dB = b.dateString ?? ""
                if dA != dB { return dA > dB }
                return a.orderIndex > b.orderIndex
            }
        case .nameAscending:
            return searched.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private var activeIsRefreshing: Bool {
        if manager.selectedChannel == .camloOfficial {
            return manager.isRefreshingCatalog
        }
        return manager.isRefreshingChannel[manager.selectedChannel] == true
    }

    private var activeErrorMessage: String? {
        if manager.selectedChannel == .camloOfficial {
            return manager.syncErrorMessage
        }
        return manager.channelErrorByChannel[manager.selectedChannel]
    }

    private var activeLastSyncedAt: Date? {
        if manager.selectedChannel == .camloOfficial {
            return manager.lastSyncedAt
        }
        return manager.lastSyncedByChannel[manager.selectedChannel]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                channelSelectorBar
                headerBanner
                routeAndFilterBar

                if let err = activeErrorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(Bi("重试", "Retry")) {
                            Task { await manager.refreshChannel(manager.selectedChannel, force: true) }
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if manager.selectedChannel == .camloOfficial {
                    LazyVGrid(columns: gridColumns, spacing: 14) {
                        ForEach(filteredOfficialPacks) { pack in
                            cloudPackCard(pack)
                        }
                    }
                } else {
                    communityGridSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Bi("云端 .tendies 壁纸库", "Cloud .tendies Gallery"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Bi("搜索壁纸名称、作者或来源", "Search name, creator or source")
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    ForEach(CloudSortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                            CamloHaptics.selection()
                        } label: {
                            HStack {
                                Text(order.localizedTitle)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }

                Button {
                    Task { await manager.refreshChannel(manager.selectedChannel, force: true) }
                } label: {
                    if activeIsRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(activeIsRefreshing)
            }
        }
        .refreshable {
            await manager.refreshChannel(manager.selectedChannel, force: true)
        }
        .task {
            await manager.refreshChannelIfNeeded(manager.selectedChannel)
        }
        .sheet(item: $previewPack) { pack in
            cloudPackPreviewSheet(pack)
        }
        .sheet(item: $previewCommunityPack) { pack in
            communityPackPreviewSheet(pack)
        }
        .sheet(item: $inspectItem) { item in
            TendiesDetailSheet(item: item)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            if showApplyActions {
                Button(Bi("立即注销桌面生效 (推荐)", "Respring Now to Reload (Recommended)")) {
                    bridge.triggerRespring()
                }
                Button(Bi("打开 PosterBoard", "Open PosterBoard")) {
                    CamloShare.openPosterBoardApp()
                }
            }
            Button(Bi("好的", "OK"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Channel Selector

    private var channelSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CloudCatalogChannel.allCases) { channel in
                    let isSelected = manager.selectedChannel == channel
                    let countText = channelCountBadge(channel)

                    Button {
                        CamloHaptics.selection()
                        manager.selectedChannel = channel
                        Task { await manager.refreshChannelIfNeeded(channel) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: channel.iconName)
                                .font(.system(size: 12, weight: .semibold))
                            Text(channel.localizedTitle)
                                .font(.system(size: 13, weight: .semibold))
                            Text(countText)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    isSelected ? Color.white.opacity(0.22) : Color(.tertiarySystemFill),
                                    in: Capsule()
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func channelCountBadge(_ channel: CloudCatalogChannel) -> String {
        switch channel {
        case .camloOfficial:
            return "\(manager.packs.count)"
        case .caPlayground:
            let count = manager.communityPacksByChannel[channel]?.count ?? 0
            return count > 0 ? "\(count)" : "183+"
        case .nuggetCustom:
            let count = manager.communityPacksByChannel[channel]?.count ?? 0
            return count > 0 ? "\(count)" : "111+"
        case .nuggetApple:
            let count = manager.communityPacksByChannel[channel]?.count ?? 0
            return count > 0 ? "\(count)" : "32+"
        }
    }

    // MARK: - Header & Route Filter

    private var headerBanner: some View {
        let ch = manager.selectedChannel
        let currentCount: Int = {
            if ch == .camloOfficial {
                return manager.packs.count
            }
            return manager.communityPacksByChannel[ch]?.count ?? 0
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.42, green: 0.30, blue: 0.96), Color(red: 0.16, green: 0.65, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: ch.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ch == .camloOfficial
                         ? Bi("Camlo 官方精选 · 动态预览与云端库", "Camlo Official · Live & Cloud Gallery")
                         : Bi("\(ch.localizedTitle) · 开源社区直连", "\(ch.localizedTitle) · Open-Source Catalog"))
                        .font(.subheadline.weight(.bold))
                    Text(headerSubtitle(for: ch))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                summaryChip(
                    icon: "shippingbox.fill",
                    text: currentCount > 0
                        ? Bi("\(currentCount) 套在线", "\(currentCount) Packs")
                        : Bi("待同步清单", "Pending Sync")
                )
                summaryChip(
                    icon: ch == .camloOfficial ? "checkmark.shield.fill" : "bolt.horizontal.fill",
                    text: ch == .camloOfficial
                        ? Bi("SHA-256 校验", "SHA-256 Verified")
                        : Bi("多节点并发竞速", "Multi-Mirror Race")
                )
                if let synced = activeLastSyncedAt {
                    summaryChip(
                        icon: "clock.arrow.circlepath",
                        text: synced.formatted(date: .omitted, time: .shortened)
                    )
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func headerSubtitle(for channel: CloudCatalogChannel) -> String {
        switch channel {
        case .camloOfficial:
            return Bi(
                "内置高清动态预览与离线秒装种子，同时支持仓库 wallpapers/ 云端热更新与 SHA-256 校验。",
                "Built-in animated previews & offline seed with cloud OTA updates and SHA-256 verification."
            )
        case .caPlayground:
            return Bi(
                "直连 CAPlayground/wallpapers 社区动画壁纸库，含动态 GIF 预览与创作者署名。",
                "Live index from CAPlayground/wallpapers with animated GIF previews."
            )
        case .nuggetCustom:
            return Bi(
                "同步 SerStars/nugget-wallpapers 社区创意/竞赛作品，自动识别多扩展与容器结构。",
                "Syncs SerStars/nugget-wallpapers custom & contest .tendies packages."
            )
        case .nuggetApple:
            return Bi(
                "Apple 各代 iPhone 原厂 Collections / Astro 壁纸；自动适配当前机型并同步画廊标识符。",
                "Stock iPhone Collections & Astronomy packages; auto-normalized for your current iPhone model."
            )
        }
    }

    private func summaryChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .foregroundStyle(.secondary)
    }

    private var routeAndFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(Bi("首选线路：", "Prefer:"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    routePill(
                        title: Bi("大陆镜像竞速", "CN Mirrors"),
                        active: appSource.routeMode == .cnMirror
                    ) {
                        appSource.routeMode = .cnMirror
                        CamloHaptics.selection()
                        Task { await manager.refreshChannel(manager.selectedChannel, force: true) }
                    }
                    routePill(
                        title: Bi("GitHub 直连", "GitHub Direct"),
                        active: appSource.routeMode == .githubDirect
                    ) {
                        appSource.routeMode = .githubDirect
                        CamloHaptics.selection()
                        Task { await manager.refreshChannel(manager.selectedChannel, force: true) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if manager.selectedChannel == .camloOfficial {
                Picker("", selection: $selectedCategory) {
                    ForEach(CloudWallpaperCategory.allCases) { cat in
                        Text(cat.localizedTitle).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func routePill(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
    }

    // MARK: - Official Pack Grid

    private func cloudPackCard(_ pack: CloudWallpaperPack) -> some View {
        let vaultItem = manager.downloadedVaultItem(for: pack, in: vault.items)
        let progress = manager.downloadProgressByID[pack.id]

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                previewPack = pack
            } label: {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .overlay {
                            CamloRemotePreview(
                                cacheKey: "official_card_\(pack.id)",
                                candidateURLs: pack.previewCandidateURLs,
                                mode: .motion(maxPixel: 440, maxKeyframes: 24),
                                contentMode: .scaleAspectFill,
                                placeholderColors: [pack.accentColor.opacity(0.36), Color.black.opacity(0.88)],
                                bundledFileURL: pack.bundledPreviewURL
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .clipped()
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack(spacing: 4) {
                        Label(pack.localizedBadge, systemImage: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)

                        if pack.supportsClockDepth == true {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.system(size: 10, weight: .bold))
                                .padding(5)
                                .background(.ultraThinMaterial, in: Circle())
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        if vaultItem != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white))
                        }
                    }
                    .padding(8)
                }
            }
            .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.97))

            VStack(alignment: .leading, spacing: 3) {
                Text(pack.localizedTitle)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(pack.localizedSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)

                HStack(spacing: 6) {
                    Text(pack.formattedSize)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let fps = pack.fps {
                        Text("· \(fps) FPS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(pack.accentColor)
                    } else if pack.supportsClockDepth == true {
                        Text("· Depth")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(pack.accentColor)
                    }
                }
            }

            if let prog = progress {
                downloadProgressRow(progress: prog, tint: pack.accentColor)
            } else if let existing = vaultItem {
                HStack(spacing: 6) {
                    Button {
                        applyVaultItem(existing)
                    } label: {
                        Text(Bi("上锁屏", "Apply"))
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))

                    Button {
                        inspectItem = existing
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(8)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
                }
            } else {
                HStack(spacing: 6) {
                    Button {
                        downloadPack(pack, applyImmediately: true)
                    } label: {
                        Text(Bi("下载并上锁屏", "Get & Apply"))
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
                    .disabled(manager.activeDownloadID != nil)

                    Button {
                        downloadPack(pack, applyImmediately: false)
                    } label: {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(8)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
                    .disabled(manager.activeDownloadID != nil)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Community Pack Grid

    @ViewBuilder
    private var communityGridSection: some View {
        let items = filteredCommunityPacks
        if activeIsRefreshing && items.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(Bi(
                    "正在从 \(manager.selectedChannel.localizedTitle) 同步清单…",
                    "Syncing catalog from \(manager.selectedChannel.localizedTitle)…"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
        } else if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(searchText.isEmpty
                     ? Bi("暂无可显示条目", "No Wallpapers Loaded")
                     : Bi("未匹配到「\(searchText)」", "No matches for \"\(searchText)\""))
                    .font(.headline)
                Button {
                    Task { await manager.refreshChannel(manager.selectedChannel, force: true) }
                } label: {
                    Label(Bi("立即拉取云端目录", "Sync Catalog Now"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(items) { pack in
                    communityPackCard(pack)
                }
            }
        }
    }

    private func communityPackCard(_ pack: CommunityWallpaperPack) -> some View {
        let vaultItem = manager.downloadedCommunityVaultItem(for: pack, in: vault.items)
        let progress = manager.downloadProgressByID[pack.id]

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                previewCommunityPack = pack
            } label: {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .overlay {
                            CamloRemotePreview(
                                cacheKey: pack.id,
                                candidateURLs: pack.previewCandidateURLs,
                                mode: .still(maxPixel: 640),
                                contentMode: .scaleAspectFill
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .clipped()
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack(spacing: 4) {
                        if pack.isAnimatedPreview {
                            Label("GIF", systemImage: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        if pack.isContest {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10, weight: .bold))
                                .padding(5)
                                .background(Color.orange.opacity(0.85), in: Circle())
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        if vaultItem != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white))
                        }
                    }
                    .padding(8)
                }
            }
            .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.97))

            VStack(alignment: .leading, spacing: 3) {
                Text(pack.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                Text(pack.description.isEmpty ? pack.displayAuthor : pack.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)

                HStack(spacing: 4) {
                    Text(pack.displayAuthor)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                    if let date = pack.dateString, !date.isEmpty {
                        Text("· \(date)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            if let prog = progress {
                downloadProgressRow(progress: prog, tint: .accentColor)
            } else if let existing = vaultItem {
                HStack(spacing: 6) {
                    Button {
                        applyVaultItem(existing)
                    } label: {
                        Text(Bi("上锁屏", "Apply"))
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))

                    Button {
                        inspectItem = existing
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(8)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
                }
            } else {
                HStack(spacing: 6) {
                    Button {
                        downloadCommunityPack(pack, applyImmediately: true)
                    } label: {
                        Text(Bi("下载并上锁屏", "Get & Apply"))
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
                    .disabled(manager.activeDownloadID != nil)

                    Button {
                        downloadCommunityPack(pack, applyImmediately: false)
                    } label: {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(8)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(CamloTapButtonStyle(scaleAmount: 0.96))
                    .disabled(manager.activeDownloadID != nil)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func downloadProgressRow(progress: Double, tint: Color) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .tint(tint)
                Text(Bi("下载校验中 \(Int(progress * 100))%", "Downloading \(Int(progress * 100))%"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Button {
                manager.cancelActiveDownload()
                CamloHaptics.impact(.light)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Preview Sheets

    private func cloudPackPreviewSheet(_ pack: CloudWallpaperPack) -> some View {
        let vaultItem = manager.downloadedVaultItem(for: pack, in: vault.items)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .frame(maxWidth: 240)
                        .overlay {
                            CamloRemotePreview(
                                cacheKey: "official_sheet_\(pack.id)",
                                candidateURLs: pack.previewCandidateURLs,
                                mode: .motion(maxPixel: 720, maxKeyframes: 32),
                                contentMode: .scaleAspectFill,
                                placeholderColors: [pack.accentColor.opacity(0.36), Color.black.opacity(0.88)],
                                bundledFileURL: pack.bundledPreviewURL
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .clipped()
                        .shadow(color: pack.accentColor.opacity(0.28), radius: 16, y: 8)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(pack.localizedTitle)
                                .font(.title3.weight(.bold))
                            Spacer()
                            Text(pack.localizedBadge)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(pack.accentColor.opacity(0.16), in: Capsule())
                                .foregroundStyle(pack.accentColor)
                        }

                        Text(pack.localizedSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            ForEach(pack.localizedTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(Bi("包路径：\(pack.packagePath)", "Path: \(pack.packagePath)"))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                            Text(Bi("文件体积：\(pack.formattedSize)", "Size: \(pack.formattedSize)"))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                            if !pack.sha256.isEmpty {
                                Text("SHA-256: \(pack.sha256.prefix(24))…")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let existing = vaultItem {
                        VStack(spacing: 10) {
                            Button {
                                previewPack = nil
                                applyVaultItem(existing)
                            } label: {
                                Label(Bi("一键直写系统锁屏", "Apply to Lock Screen"), systemImage: "iphone.badge.play")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(CamloTapButtonStyle())

                            Button {
                                previewPack = nil
                                inspectItem = existing
                            } label: {
                                Label(Bi("120Hz 原生交互试穿 & X-Ray", "120Hz Live .ca Preview & X-Ray"), systemImage: "bolt.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(CamloTapButtonStyle())
                        }
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                previewPack = nil
                                downloadPack(pack, applyImmediately: true)
                            } label: {
                                Label(Bi("下载、校验并直写锁屏", "Download, Verify & Apply"), systemImage: "icloud.and.arrow.down.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(CamloTapButtonStyle())
                            .disabled(manager.activeDownloadID != nil)

                            Button {
                                previewPack = nil
                                tryOnOfficialPack(pack)
                            } label: {
                                Label(Bi("120Hz 原生 Core Animation 交互试穿", "120Hz Interactive .ca Try-On"), systemImage: "bolt.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(CamloTapButtonStyle())
                            .disabled(manager.activeDownloadID != nil)

                            Button {
                                previewPack = nil
                                downloadPack(pack, applyImmediately: false)
                            } label: {
                                Label(Bi("仅存入本地壁纸金库", "Save to Vault Only"), systemImage: "tray.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(CamloTapButtonStyle())
                            .disabled(manager.activeDownloadID != nil)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Bi("壁纸包预览", "Pack Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Bi("关闭", "Close")) { previewPack = nil }
                }
            }
        }
    }

    private func communityPackPreviewSheet(_ pack: CommunityWallpaperPack) -> some View {
        let vaultItem = manager.downloadedCommunityVaultItem(for: pack, in: vault.items)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .frame(maxWidth: 240)
                        .overlay {
                            CamloRemotePreview(
                                cacheKey: pack.id,
                                candidateURLs: pack.previewCandidateURLs,
                                mode: .motion(maxPixel: 880, maxKeyframes: 72),
                                contentMode: .scaleAspectFill
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .clipped()
                        .shadow(color: Color.accentColor.opacity(0.24), radius: 16, y: 8)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(pack.name)
                                .font(.title3.weight(.bold))
                            Spacer()
                            Text(pack.isAnimatedPreview ? Bi("GIF 动态预览", "Animated GIF") : pack.channel.shortTitle)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.16), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }

                        if !pack.description.isEmpty {
                            Text(pack.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(Bi("作者 / 来源：\(pack.displayAuthor) · \(pack.channel.localizedTitle)", "Creator: \(pack.displayAuthor) · \(pack.channel.localizedTitle)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let date = pack.dateString, !date.isEmpty {
                                Text(Bi("收录日期：\(date)", "Date: \(date)"))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            if let origin = pack.originTag, !origin.isEmpty {
                                Text(Bi("标签：\(origin)", "Origin: \(origin)"))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(Bi("包路径：\(pack.fileRelativeOrAbsoluteURL)", "Package: \(pack.fileRelativeOrAbsoluteURL)"))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let existing = vaultItem {
                        VStack(spacing: 10) {
                            Button {
                                previewCommunityPack = nil
                                applyVaultItem(existing)
                            } label: {
                                Label(Bi("一键直写系统锁屏", "Apply to Lock Screen"), systemImage: "iphone.badge.play")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(CamloTapButtonStyle())

                            Button {
                                previewCommunityPack = nil
                                inspectItem = existing
                            } label: {
                                Label(Bi("120Hz 原生交互试穿 & X-Ray", "120Hz Live .ca Preview & X-Ray"), systemImage: "bolt.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(CamloTapButtonStyle())
                        }
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                previewCommunityPack = nil
                                downloadCommunityPack(pack, applyImmediately: true)
                            } label: {
                                Label(Bi("下载并直写锁屏", "Download & Apply"), systemImage: "icloud.and.arrow.down.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(CamloTapButtonStyle())
                            .disabled(manager.activeDownloadID != nil)

                            Button {
                                previewCommunityPack = nil
                                downloadCommunityPack(pack, applyImmediately: false)
                            } label: {
                                Label(Bi("仅存入本地壁纸金库", "Save to Vault Only"), systemImage: "tray.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(CamloTapButtonStyle())
                            .disabled(manager.activeDownloadID != nil)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Bi("社区壁纸预览", "Community Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Bi("关闭", "Close")) { previewCommunityPack = nil }
                }
            }
        }
    }

    // MARK: - Download & Apply

    private func tryOnOfficialPack(_ pack: CloudWallpaperPack) {
        CamloHaptics.impact(.light)
        Task {
            do {
                let imported = try await manager.downloadAndImport(pack: pack)
                CamloHaptics.notify(.success)
                inspectItem = imported
            } catch is CancellationError {
                return
            } catch {
                CamloHaptics.notify(.error)
                showApplyActions = false
                alertTitle = Bi("试穿加载失败", "Failed to Load Live Preview")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func downloadPack(_ pack: CloudWallpaperPack, applyImmediately: Bool) {
        CamloHaptics.impact(.light)
        Task {
            do {
                let imported = try await manager.downloadAndImport(pack: pack)
                CamloHaptics.notify(.success)
                if applyImmediately {
                    applyVaultItem(imported)
                } else {
                    showApplyActions = false
                    alertTitle = Bi("已存入壁纸金库", "Saved to Vault")
                    alertMessage = Bi(
                        "「\(pack.localizedTitle)」已通过 SHA-256 校验并导入本地金库，可随时直写锁屏或分享给好友。",
                        "\"\(pack.localizedTitle)\" passed SHA-256 verification and was saved to your Vault."
                    )
                    showAlert = true
                }
            } catch is CancellationError {
                return
            } catch {
                CamloHaptics.notify(.error)
                showApplyActions = false
                alertTitle = Bi("下载失败", "Download Failed")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func downloadCommunityPack(_ pack: CommunityWallpaperPack, applyImmediately: Bool) {
        CamloHaptics.impact(.light)
        Task {
            do {
                let imported = try await manager.downloadAndImportCommunity(pack: pack)
                CamloHaptics.notify(.success)
                if applyImmediately {
                    applyVaultItem(imported)
                } else {
                    showApplyActions = false
                    alertTitle = Bi("已存入壁纸金库", "Saved to Vault")
                    alertMessage = Bi(
                        "「\(pack.name)」已通过兼容引擎导入本地金库，保留完整结构与容器信息。",
                        "\"\(pack.name)\" was imported into your local Vault."
                    )
                    showAlert = true
                }
            } catch is CancellationError {
                return
            } catch {
                CamloHaptics.notify(.error)
                showApplyActions = false
                alertTitle = Bi("下载失败", "Download Failed")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func applyVaultItem(_ item: TendiesVaultItem) {
        let res = bridge.applyTendiesItems([item], autoRefreshGalleryCache: true)
        if res.0 {
            CamloHaptics.notify(.success)
            showApplyActions = true
            let destinationHint = PosterBoardBridge.galleryDestinationHint(for: [item])
            alertTitle = Bi("已直写至系统壁纸容器", "Applied to PosterBoard")
            alertMessage = Bi(
                "「\(item.title)」已注入系统壁纸库（不在系统「照片」相册里！）。\n\n目标位置：\(destinationHint)。\n\n请先点击「立即注销桌面生效」（或打开 PosterBoard 后在后台上滑划掉），随后长按锁屏点「+」号，在对应专区即可选用！",
                "\"\(item.title)\" is injected into PosterBoard (\(destinationHint)). Respring or force-close PosterBoard, then long-press Lock Screen -> '+' to select it."
            )
        } else {
            CamloHaptics.notify(.error)
            showApplyActions = false
            alertTitle = Bi("已存入金库 · 暂未直写", "Saved in Vault")
            alertMessage = res.1.isEmpty
                ? Bi("已保存至本地金库，可随时导出 .tendies 文件。", "Saved to local Vault; you can export or share the .tendies file anytime.")
                : res.1
        }
        showAlert = true
    }
}
