//
//  SystemStatusView.swift
//  Camlo · 开幕
//
//  PosterBoard container diagnostics, non-destructive GalleryCache refresh,
//  Camlo-only descriptor cleanup, instant bilingual switcher, and open-source credits.
//

import SwiftUI

struct SystemStatusView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared
    @ObservedObject private var appSource = AppSourceManager.shared

    @State private var confirmResetTarget: PBExtensionTarget?
    @State private var confirmCleanCamloOnly = false
    @State private var showCustomRepoField = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            List {
                // 0. App Source Subscription & Signing Tool Updates
                appSourceSection

                // 1. PosterBoard Container & Direct Apply Status
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: bridge.hasContainerAccess ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(bridge.hasContainerAccess ? .green : .orange)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(bridge.hasContainerAccess
                                 ? Bi("免电脑直写通道：已连通", "On-Device Direct Apply: Connected")
                                 : Bi("免电脑直写通道：未就绪", "On-Device Direct Apply: Standby"))
                                .font(.subheadline.weight(.bold))
                            Text(bridge.statusSummary.isEmpty
                                 ? Bi("点击下方按钮扫描定位系统 PosterBoard 容器", "Tap below to scan for PosterBoard container")
                                 : bridge.statusSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(Bi("PosterBoard 容器路径", "PosterBoard Container Path"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("/private/var/mobile/Containers/Data/Application/...", text: $bridge.containerPath)
                            .font(.system(.caption, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                bridge.validateManualPath(bridge.containerPath)
                            }
                    }

                    Button {
                        CamloHaptics.selection()
                        bridge.refreshContainerAccess(forceRescan: true)
                    } label: {
                        HStack {
                            if bridge.isScanning {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "magnifyingglass.circle.fill")
                            }
                            Text(bridge.isScanning
                                 ? Bi("正在解析 CSStore2 定位容器…", "Scanning CSStore2…")
                                 : Bi("重新扫描并授权 PosterBoard 容器", "Rescan & Grant Container Access"))
                        }
                    }
                    .disabled(bridge.isScanning)

                    Button {
                        CamloShare.openPosterBoardApp()
                    } label: {
                        Label(Bi("唤起 PosterBoard（随后请在后台上滑关闭它）", "Launch PosterBoard (Then Swipe Up to Close)"), systemImage: "arrow.up.forward.app.fill")
                    }

                    Button {
                        bridge.triggerRespring()
                    } label: {
                        Label(Bi("一键注销桌面重载锁屏画廊 (Respring)", "Respring Device to Reload Gallery"), systemImage: "bolt.horizontal.circle.fill")
                    }
                } header: {
                    Text(Bi("锁屏容器直写引擎 (iOS 26 / iOS 27)", "PosterBoard Bridge (iOS 26 & 27)"))
                } footer: {
                    Text(Bi("提示：使用 SideStore / AltStore / 巨魔 / 个人证书签名安装时，请确保保留 App Group 权限以启用免电脑直写；无 App Group 环境下仍可完整创作并导出 .tendies。", "Keep an App Group entitlement when signing with SideStore/AltStore/Xcode to enable 1-tap on-device apply."))
                }

                // 2. Safe Maintenance & Cleanup
                Section {
                    NavigationLink {
                        InstalledWallpapersView()
                    } label: {
                        Label(Bi("系统已装锁屏视觉管理 (预览与精准删除)", "Installed Lock Screens Manager"), systemImage: "iphone.badge.checkmark")
                    }

                    Button {
                        let res = bridge.refreshGalleryCacheNonDestructive()
                        CamloHaptics.notify(res.0 ? .success : .error)
                        alertTitle = res.0 ? Bi("画廊缓存已刷新", "Gallery Cache Refreshed") : Bi("操作失败", "Action Failed")
                        alertMessage = res.1
                        showAlert = true
                    } label: {
                        Label(Bi("无损刷新锁屏画廊缓存 (GalleryCache)", "Refresh Gallery Cache (Non-Destructive)"), systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button {
                        confirmCleanCamloOnly = true
                    } label: {
                        Label(Bi("仅清理「开幕 Camlo」写入的壁纸", "Remove Camlo-Injected Wallpapers Only"), systemImage: "sparkles.square.filled.on.square")
                    }

                    Menu {
                        ForEach(PBExtensionTarget.allCases) { target in
                            Button(role: .destructive) {
                                confirmResetTarget = target
                            } label: {
                                Text(target.displayName)
                            }
                        }
                    } label: {
                        Label(Bi("深度重置指定锁屏扩展目录…", "Reset Extension Descriptors…"), systemImage: "trash.slash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text(Bi("画廊维护与安全清理", "Gallery Maintenance & Cleanup"))
                } footer: {
                    Text(Bi("「系统已装锁屏视觉管理」可直接预览 .atx 系统快照与 .ca 图层缩略图并单个或批量移除。「仅清理开幕写入的壁纸」仅删除 Camlo 追踪记录或旧版 .camlo_origin 标记的描述符，不误删系统原生壁纸。", "Installed Lock Screens Manager previews .atx snapshots & CAML layers for precise removal. Camlo-only cleanup removes tracked Camlo descriptors without touching stock wallpapers."))
                }

                // 3. Language & Preferences
                Section {
                    Picker(Bi("界面语言 / Language", "Language / 界面语言"), selection: $localization.languageModeRaw) {
                        ForEach(AppLanguageMode.allCases) { mode in
                            Text(mode.displayTitle).tag(mode.rawValue)
                        }
                    }
                } header: {
                    Text(Bi("语言与外观", "Language"))
                }

                // 4. Device & Signing Telemetry
                Section {
                    infoRow(Bi("应用版本", "App Version"), "Camlo v\(CamloDevice.appVersion)")
                    infoRow(Bi("设备型号", "Device Model"), CamloDevice.machineIdentifier)
                    infoRow(Bi("系统版本", "iOS Version"), "iOS \(CamloDevice.osVersionString) (\(CamloDevice.buildNumber))")
                    infoRow(
                        Bi("当前 App Group", "Active App Group"),
                        bridge.activeAppGroup.isEmpty ? Bi("未检测到", "None") : bridge.activeAppGroup
                    )
                } header: {
                    Text(Bi("设备与环境信息", "Device Telemetry"))
                }

                // 5. Related / Companion Projects
                Section {
                    Link(destination: URL(string: "https://github.com/Kianuni/Erosion-CN")!) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Erosion-CN", systemImage: "wrench.and.screwdriver.fill")
                                .font(.subheadline.weight(.semibold))
                            Text(Bi("iOS 26/27 系统配置、国行 AI 解锁与跨容器工具箱", "Bootloop-hardened MobileGestalt & cross-container toolkit"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Link(destination: URL(string: "https://github.com/Kianuni/AppleFlow")!) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("AppleFlow", systemImage: "arrow.triangle.branch")
                                .font(.subheadline.weight(.semibold))
                            Text(Bi("零 MitM Apple 智能、高质量消除与中文 Siri 分流方案", "Zero-MitM routing & Config Doctor for Apple Intelligence"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Link(destination: URL(string: "https://github.com/Kianuni/WQGuard")!) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("WQGuard", systemImage: "checkerboard.shield")
                                .font(.subheadline.weight(.semibold))
                            Text(Bi("只读沙盒逃逸静态审计与固件 CVE 防护系统", "Read-only sandbox escape detector & firmware CVE guard"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(Bi("关联项目", "Related Projects"))
                }

                // 6. Open-Source Attribution (GPLv3)
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Camlo · 开幕 (GPL-3.0)")
                            .font(.subheadline.weight(.bold))
                        Text(Bi(
                            "本项目遵循 GNU GPLv3 开源协议发布，四大核心能力均为 100% Camlo 原生独立实现。外部开源项目与研究者致谢：\n• jailbreakdotparty/Erosion — CSStore2 容器解析、PosterBoard 注入与注销参考\n• frs0n/placard — 产品功能与交互体验灵感来源（缓存守护、已装管理、多扩展识别、动态预览与社区源思路）\n• forcequitOS/worse_query — iOS 沙盒跨容器读写核心研究\n• CAPlayground & CAPlayground/wallpapers — Core Animation CAML 规范与社区静态壁纸库\n• Nugget & SerStars/nugget-wallpapers — .tendies 格式规范与社区创作 / Apple 机型库\n• ZIPFoundation (weichsel) — 高性能压缩归档引擎",
                            "Licensed under GNU GPLv3. All core Camlo v\(CamloDevice.appVersion) capabilities are 100% Camlo clean-room native implementations. Acknowledgements:\n• jailbreakdotparty/Erosion — CSStore2, PosterBoard & Respring references\n• frs0n/placard — Feature & UX inspiration (Caches protection, installed manager, multi-extension & community gallery ideas)\n• forcequitOS/worse_query — iOS cross-container sandbox R/W\n• CAPlayground & CAPlayground/wallpapers — Core Animation CAML specs & community gallery\n• Nugget & SerStars/nugget-wallpapers — .tendies specs, custom & Apple collections gallery\n• ZIPFoundation by Thomas Zoechling"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(Bi("开源致谢与许可", "Credits & GPLv3 License"))
                }
            }
            .navigationTitle(Bi("设备与设置", "System & Settings"))
            .confirmationDialog(
                Bi("确认仅清理 Camlo 壁纸？", "Remove Camlo Wallpapers?"),
                isPresented: $confirmCleanCamloOnly,
                titleVisibility: .visible
            ) {
                Button(Bi("清理 Camlo 注入项", "Clean Camlo Wallpapers"), role: .destructive) {
                    let res = bridge.removeCamloInjectedDescriptorsOnly()
                    if let err = res.1 {
                        CamloHaptics.notify(.error)
                        alertTitle = Bi("清理失败", "Cleanup Failed")
                        alertMessage = err
                    } else {
                        CamloHaptics.notify(.success)
                        alertTitle = Bi("清理完成", "Cleanup Complete")
                        alertMessage = Bi("已安全移除 \(res.0) 组由 Camlo 写入的壁纸描述符，并刷新了画廊缓存。", "Removed \(res.0) Camlo descriptor(s) and refreshed gallery cache.")
                    }
                    showAlert = true
                }
                Button(Bi("取消", "Cancel"), role: .cancel) {}
            }
            .confirmationDialog(
                Bi("深度重置锁屏扩展目录", "Reset Extension Directory"),
                isPresented: Binding(
                    get: { confirmResetTarget != nil },
                    set: { if !$0 { confirmResetTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let target = confirmResetTarget {
                    Button(Bi("清空 \(target.displayName)", "Reset \(target.displayName)"), role: .destructive) {
                        let res = bridge.resetExtensionDescriptors(for: target)
                        confirmResetTarget = nil
                        CamloHaptics.notify(res.0 ? .success : .error)
                        alertTitle = res.0 ? Bi("已重置目录", "Directory Reset") : Bi("重置失败", "Reset Failed")
                        alertMessage = res.0
                            ? Bi("已清空该分类下的自定义描述符，建议重启一次设备或重开锁屏画廊以恢复系统默认模板。", "Custom descriptors cleared. Reopen PosterBoard or reboot to restore stock defaults.")
                            : res.1
                        showAlert = true
                    }
                }
                Button(Bi("取消", "Cancel"), role: .cancel) {
                    confirmResetTarget = nil
                }
            } message: {
                Text(Bi("此操作将清空该分类下的全部描述符文件夹（重启手机后系统会自动重建自带「收藏」壁纸）。", "Clears all descriptor folders in the selected PosterBoard extension."))
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(Bi("好的", "OK"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - App Source & Signing Tool Update Section

    private var appSourceSection: some View {
        Section {
            // Route Picker (GitHub Direct vs Mainland China Accelerated)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(Bi("软件源线路", "Source Route"), systemImage: "network")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                Picker(Bi("线路", "Route"), selection: $appSource.routeMode) {
                    ForEach(SourceRouteMode.allCases) { mode in
                        Text(mode.displayTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 2)

            // 1-Tap Import into Signing Tools
            VStack(alignment: .leading, spacing: 10) {
                Text(Bi("一键导入软件源到签名工具", "1-Tap Add to Signing Tool"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SigningClientTarget.allCases) { client in
                            Button {
                                appSource.openInSigningClient(client) { copiedURL in
                                    alertTitle = Bi("已复制软件源链接", "Source URL Copied")
                                    alertMessage = Bi(
                                        "已复制对应源地址：\n\(copiedURL)\n\n未检测到默认跳转协议（部分重签名版 \(client.displayName) / 全能签 修改了 URL Scheme），请直接打开你的签名工具 →「软件源」→ 粘贴添加即可自动接收后续更新！",
                                        "Copied source URL:\n\(copiedURL)\n\nOpen \(client.displayName) -> Sources -> Paste to subscribe for automatic updates."
                                    )
                                    showAlert = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: client.symbolName)
                                        .font(.system(size: 12, weight: .bold))
                                    Text(client.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(CamloTapButtonStyle())
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            // Copy Universal Repo URL (Feather / SideStore / AltStore / LiveContainer)
            Button {
                let copied = appSource.copyRepoURL(esignFormat: false)
                alertTitle = Bi("已复制通用软件源地址", "Copied Universal Source URL")
                alertMessage = Bi(
                    "已复制到剪贴板：\n\(copied)\n\n适用于 Feather、SideStore、AltStore、TrollApps、LiveContainer（及开启 AltStore 格式的全能签）。",
                    "Copied to clipboard:\n\(copied)\n\nCompatible with Feather, SideStore, AltStore, TrollApps, and LiveContainer."
                )
                showAlert = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label(Bi("复制 Feather / SideStore / AltStore 源地址", "Copy Feather / SideStore / AltStore URL"), systemImage: "doc.on.doc.fill")
                        .font(.subheadline.weight(.medium))
                    Text(appSource.activeAltStoreRepoURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            // Copy ESign / QuanNengQian URL
            Button {
                let copied = appSource.copyRepoURL(esignFormat: true)
                alertTitle = Bi("已复制全能签 / 轻松签源地址", "Copied ESign Source URL")
                alertMessage = Bi(
                    "已复制到剪贴板：\n\(copied)\n\n打开「全能签」或「轻松签 (ESign)」→ 软件源 → 右上角添加软件源 → 粘贴即可。",
                    "Copied to clipboard:\n\(copied)\n\nPaste inside ESign -> App Source -> Add Source."
                )
                showAlert = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label(Bi("复制 全能签 / 轻松签 (ESign) 专用源地址", "Copy ESign Dedicated Source URL"), systemImage: "doc.on.clipboard")
                        .font(.subheadline.weight(.medium))
                    Text(appSource.activeESignRepoURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            // Live In-App Update Check
            Button {
                appSource.checkForUpdates()
            } label: {
                HStack(spacing: 8) {
                    if appSource.isCheckingUpdate {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: appSource.hasNewerUpdate ? "arrow.down.circle.fill" : "arrow.clockwise.circle.fill")
                            .foregroundStyle(appSource.hasNewerUpdate ? .green : Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appSource.isCheckingUpdate
                             ? Bi("正在连接软件源检查更新…", "Checking app source for updates…")
                             : Bi("在线检查新版本 (当前 v\(CamloDevice.appVersion))", "Check for Updates (Current v\(CamloDevice.appVersion))"))
                            .font(.subheadline.weight(.medium))
                        if !appSource.lastCheckStatus.isEmpty {
                            Text(appSource.lastCheckStatus)
                                .font(.caption)
                                .foregroundStyle(appSource.hasNewerUpdate ? .green : .secondary)
                        }
                    }
                }
            }
            .disabled(appSource.isCheckingUpdate)

            if let latest = appSource.latestRelease, appSource.hasNewerUpdate {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("v\(latest.version)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.green)
                        if latest.sizeBytes > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: latest.sizeBytes, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let dlURL = URL(string: latest.downloadURL), !latest.downloadURL.isEmpty {
                            Link(destination: dlURL) {
                                Label(Bi("直接下载 IPA", "Download IPA"), systemImage: "arrow.down.to.line.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.16), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    if !latest.changelog.isEmpty {
                        Text(latest.changelog)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                    }
                }
                .padding(.vertical, 4)
            }

            DisclosureGroup(Bi("高级：自定义 GitHub 仓库路径", "Advanced: Custom GitHub Repo"), isExpanded: $showCustomRepoField) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Kianuni/Camlo", text: $appSource.repoSlug)
                        .font(.system(.caption, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if appSource.repoSlug != AppSourceManager.defaultRepoSlug {
                        Button(Bi("恢复默认官方仓库 (Kianuni/Camlo)", "Reset to Official Repo")) {
                            appSource.repoSlug = AppSourceManager.defaultRepoSlug
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        } header: {
            Text(Bi("软件源订阅与在线更新", "App Source & Updates"))
        } footer: {
            Text(Bi("将上方源地址添加到 Feather / SideStore / AltStore / 全能签 / 轻松签后，后续发布新版本即可在签名工具内一键覆盖更新（保留壁纸金库数据）。国内无代理环境建议切换至「国内加速镜像」。", "Subscribe in Feather, SideStore, AltStore, or ESign to receive 1-tap in-place updates while keeping all Vault wallpapers."))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}
