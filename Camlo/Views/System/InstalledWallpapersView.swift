//
//  InstalledWallpapersView.swift
//  Camlo · 开幕
//
//  Visual system Lock Screen wallpaper manager backed by SystemPosterStore.
//

import SwiftUI
import UIKit

struct InstalledWallpapersView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var store = SystemPosterStore.shared

    @State private var selectedSlot: CamloPosterSlot = .galleryTemplate
    @State private var onlyCamloInjected = false
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var pendingDeleteTargets: [SystemPosterRecord] = []
    @State private var showDeleteConfirm = false
    @State private var showRespringAlert = false
    @State private var lastDeletedCount = 0
    @State private var errorAlertMessage: String?

    private var slotItems: [SystemPosterRecord] {
        store.records.filter { $0.slot == selectedSlot }
    }

    private var filteredItems: [SystemPosterRecord] {
        let byOrigin = onlyCamloInjected
            ? slotItems.filter(\.isCamloOrigin)
            : slotItems

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return byOrigin }
        return byOrigin.filter { item in
            item.title.localizedCaseInsensitiveContains(q)
                || item.sectionTitle.localizedCaseInsensitiveContains(q)
                || item.providerID.localizedCaseInsensitiveContains(q)
                || item.uuid.localizedCaseInsensitiveContains(q)
                || (item.numericTag?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    private var camloCountInSlot: Int {
        slotItems.filter(\.isCamloOrigin).count
    }

    var body: some View {
        VStack(spacing: 0) {
            filterHeader
            contentBody
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Bi("系统已装锁屏管理", "Installed Lock Screens"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Bi("搜索壁纸名称、类型或 UUID", "Search name, provider or UUID")
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isScanning || store.isRemoving)

                Button(isSelecting ? Bi("完成", "Done") : Bi("多选", "Select")) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedIDs.removeAll()
                        }
                    }
                }
                .disabled(filteredItems.isEmpty || store.isRemoving)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                batchSelectionBar
            }
        }
        .overlay {
            if store.isRemoving {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(Bi("正在安全清理系统锁屏与索引…", "Removing posters and pruning indexes…"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(24)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .confirmationDialog(
            Bi("确认移除选中的系统锁屏？", "Remove selected Lock Screens?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(
                Bi("确认移除 (\(pendingDeleteTargets.count) 项)", "Remove (\(pendingDeleteTargets.count))"),
                role: .destructive
            ) {
                let targets = pendingDeleteTargets
                pendingDeleteTargets = []
                Task { await executeDelete(targets) }
            }
            Button(Bi("取消", "Cancel"), role: .cancel) {
                pendingDeleteTargets = []
            }
        } message: {
            Text(Bi(
                "将从系统 PosterBoard 容器移除所选描述符/配置并修剪索引。若误删可通过右上角刷新后重新注入，或前往系统壁纸库重建。",
                "Deletes the selected descriptor/configuration folders from PosterBoard and prunes switcher/gallery indexes."
            ))
        }
        .alert(Bi("清理完成", "Removed"), isPresented: $showRespringAlert) {
            Button(Bi("一键注销生效", "Respring Now")) {
                PosterBoardBridge.shared.triggerRespring()
            }
            Button(Bi("打开壁纸库预览", "Open PosterBoard")) {
                CamloShare.openPosterBoardApp()
            }
            Button(Bi("稍后", "Later"), role: .cancel) {}
        } message: {
            Text(Bi(
                "已成功移除 \(lastDeletedCount) 个系统锁屏并刷新画廊缓存，建议立即注销使桌面与锁屏切换器生效。",
                "Removed \(lastDeletedCount) Lock Screen(s) and refreshed GalleryCache. Respring to update system UI."
            ))
        }
        .alert(Bi("操作失败", "Action Failed"), isPresented: Binding(
            get: { errorAlertMessage != nil },
            set: { if !$0 { errorAlertMessage = nil } }
        )) {
            Button(Bi("好", "OK"), role: .cancel) {}
        } message: {
            Text(errorAlertMessage ?? "")
        }
        .task {
            if store.records.isEmpty {
                await store.refresh()
            }
        }
    }

    private var filterHeader: some View {
        VStack(spacing: 10) {
            Picker(Bi("来源分类", "Source"), selection: $selectedSlot) {
                ForEach(CamloPosterSlot.allCases) { slot in
                    let count = store.records.filter { $0.slot == slot }.count
                    Text("\(slot.shortLabel) (\(count))").tag(slot)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                originFilterChip(
                    title: Bi("全部来源 (\(slotItems.count))", "All (\(slotItems.count))"),
                    selected: !onlyCamloInjected
                ) {
                    onlyCamloInjected = false
                }

                originFilterChip(
                    title: Bi("仅 Camlo 注入 (\(camloCountInSlot))", "Camlo Only (\(camloCountInSlot))"),
                    selected: onlyCamloInjected
                ) {
                    onlyCamloInjected = true
                }

                Spacer()

                if isSelecting && !filteredItems.isEmpty {
                    let allFilteredIDs = Set(filteredItems.map(\.id))
                    let allSelected = !allFilteredIDs.isEmpty && allFilteredIDs.isSubset(of: selectedIDs)
                    Button(allSelected ? Bi("全不选", "None") : Bi("全选当前", "Select All")) {
                        CamloHaptics.selection()
                        if allSelected {
                            selectedIDs.subtract(allFilteredIDs)
                        } else {
                            selectedIDs.formUnion(allFilteredIDs)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func originFilterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            CamloHaptics.selection()
            action()
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selected ? Color.accentColor : Color(.tertiarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(CamloTapButtonStyle())
    }

    @ViewBuilder
    private var contentBody: some View {
        if store.isScanning && store.records.isEmpty {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(Bi("正在扫描 PosterBoard 容器与图库预览…", "Scanning PosterBoard store and thumbnails…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if let err = store.lastError, filteredItems.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.orange)
                Text(Bi("无法读取系统锁屏列表", "Unable to Read Installed Lock Screens"))
                    .font(.headline)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label(Bi("重新扫描", "Retry Scan"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(CamloTapButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else if filteredItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(Bi("当前筛选条件下暂无壁纸", "No Wallpapers Match Filter"))
                    .font(.headline)
                Text(Bi("可切换「图库模板 / 锁屏切换栏」或取消「仅 Camlo 注入」筛选。", "Switch between Gallery Template and Active Switcher, or clear filters."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            List {
                if let err = store.lastError {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    ForEach(filteredItems) { poster in
                        posterRow(poster)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    requestDelete([poster])
                                } label: {
                                    Label(Bi("移除", "Delete"), systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = poster.uuid
                                    CamloHaptics.notify(.success)
                                } label: {
                                    Label(Bi("复制 UUID", "Copy UUID"), systemImage: "doc.on.doc")
                                }

                                Button(role: .destructive) {
                                    requestDelete([poster])
                                } label: {
                                    Label(Bi("从系统移除", "Delete from System"), systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    Text(Bi(
                        "提示：缩略图由 Camlo 原生 ImageIO 引擎从壁纸图层与资产按 520px 采样并磁盘缓存。",
                        "Thumbnails are sampled locally from poster layer assets via ImageIO."
                    ))
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await store.refresh()
            }
        }
    }

    private func posterRow(_ poster: SystemPosterRecord) -> some View {
        let isSelected = selectedIDs.contains(poster.id)

        return HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }

            posterThumbnail(poster)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(poster.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if poster.isCamloOrigin {
                        Text("Camlo")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.16), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Text(Bi("系统/其他", "System"))
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 5) {
                    Image(systemName: poster.symbolName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(poster.sectionTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(String(poster.uuid.prefix(8)))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)

                    if let descID = poster.numericTag, !descID.isEmpty {
                        Text("ID: \(descID)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Text(poster.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            if !isSelecting {
                Button(role: .destructive) {
                    requestDelete([poster])
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(8)
                        .background(Color.red.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelecting else { return }
            CamloHaptics.selection()
            if isSelected {
                selectedIDs.remove(poster.id)
            } else {
                selectedIDs.insert(poster.id)
            }
        }
    }

    private func posterThumbnail(_ poster: SystemPosterRecord) -> some View {
        ZStack {
            if let data = poster.previewJPEG, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 102)
                    .clipped()
            } else {
                LinearGradient(
                    colors: poster.isCamloOrigin
                        ? [Color.accentColor.opacity(0.45), Color.indigo.opacity(0.55)]
                        : [Color(.systemGray4), Color(.systemGray5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 102)
                .overlay {
                    VStack(spacing: 4) {
                        Text("09:41")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                        Image(systemName: poster.symbolName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .frame(width: 50, height: 102)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var batchSelectionBar: some View {
        let targets = filteredItems.filter { selectedIDs.contains($0.id) }
        return HStack {
            Text(Bi("已选择 \(targets.count) 项", "\(targets.count) Selected"))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button(role: .destructive) {
                requestDelete(targets)
            } label: {
                Label(Bi("移除所选", "Delete Selected"), systemImage: "trash.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(targets.isEmpty ? Color.gray.opacity(0.3) : Color.red, in: Capsule())
                    .foregroundStyle(.white)
            }
            .disabled(targets.isEmpty || store.isRemoving)
            .buttonStyle(CamloTapButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func requestDelete(_ targets: [SystemPosterRecord]) {
        guard !targets.isEmpty else { return }
        CamloHaptics.impact(.medium)
        pendingDeleteTargets = targets
        showDeleteConfirm = true
    }

    private func executeDelete(_ targets: [SystemPosterRecord]) async {
        do {
            let deleted = try await store.remove(targets)
            CamloHaptics.notify(.success)
            let deletedSet = Set(targets.map(\.id))
            selectedIDs.subtract(deletedSet)
            if selectedIDs.isEmpty {
                isSelecting = false
            }
            lastDeletedCount = deleted
            showRespringAlert = true
        } catch {
            CamloHaptics.notify(.error)
            errorAlertMessage = error.localizedDescription
        }
    }
}
