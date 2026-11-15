//
//  RootTabView.swift
//  Camlo · 开幕
//

import SwiftUI

struct RootTabView: View {
    @Binding var selectedTab: Int
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var vault = TendiesVaultStore.shared
    @ObservedObject private var appSource = AppSourceManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            StudioHomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label(Bi("开幕工坊", "Studio"), systemImage: "wand.and.stars")
                }
                .tag(0)

            VaultView()
                .tabItem {
                    Label(Bi("壁纸金库", "Vault"), systemImage: "sparkles.rectangle.stack.fill")
                }
                .badge(vault.items.count)
                .tag(1)

            SystemStatusView()
                .tabItem {
                    Label(Bi("设备与设置", "System"), systemImage: "cpu")
                }
                .badge(appSource.hasNewerUpdate ? "NEW" : nil)
                .tag(2)
        }
        .environment(\.locale, localization.effectiveLocale)
    }
}
