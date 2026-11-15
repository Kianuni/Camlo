//
//  CamloApp.swift
//  Camlo · 开幕
//
//  Zero-threshold Slide-to-Unlock Morph & Dynamic Lock Screen (.tendies / CAML) Studio.
//

import SwiftUI
import UIKit
import ObjectiveC.runtime
import UniformTypeIdentifiers

@main
struct CamloApp: App {
    private static var didSwizzlePicker = false

    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var bridge = PosterBoardBridge.shared
    @State private var selectedTab: Int = 0

    @State private var openURLAlertTitle = ""
    @State private var openURLAlertMessage = ""
    @State private var showOpenURLAlert = false

    init() {
        if !Self.didSwizzlePicker {
            Self.didSwizzlePicker = true
            let origSelector = #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:))
            let fixSelector = #selector(UIDocumentPickerViewController.camlo_fix_init(forOpeningContentTypes:asCopy:))
            if let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, origSelector),
               let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, fixSelector) {
                method_exchangeImplementations(origMethod, fixMethod)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let nonce = bridge.respringNonce {
                    Color.black.ignoresSafeArea()
                    CamloRespringView()
                        .id(nonce)
                        .brightness(-1.0)
                        .ignoresSafeArea()
                } else {
                    RootTabView(selectedTab: $selectedTab)
                }
            }
            .onAppear {
                PosterBoardBridge.shared.bootstrapIfNeeded()
            }
            .onOpenURL { url in
                handleIncomingFileURL(url)
            }
            .alert(openURLAlertTitle, isPresented: $showOpenURLAlert) {
                Button(Bi("好的", "OK"), role: .cancel) {}
            } message: {
                Text(openURLAlertMessage)
            }
        }
    }

    @MainActor
    private func handleIncomingFileURL(_ url: URL) {
        let hasScope = url.startAccessingSecurityScopedResource()
        defer { if hasScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let item = try TendiesVaultStore.shared.importExternalTendies(from: url)
            selectedTab = 1
            CamloHaptics.notify(.success)
            openURLAlertTitle = Bi("已导入 .tendies 壁纸包", "Imported .tendies Package")
            openURLAlertMessage = Bi("「\(item.title)」已存入壁纸金库，可一键写入锁屏或透视检查。", "\"\(item.title)\" has been added to your Vault.")
            showOpenURLAlert = true
        } catch {
            CamloHaptics.notify(.error)
            openURLAlertTitle = Bi("无法导入文件", "Import Failed")
            openURLAlertMessage = error.localizedDescription
            showOpenURLAlert = true
        }
    }
}

extension UIDocumentPickerViewController {
    @objc func camlo_fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return camlo_fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}
