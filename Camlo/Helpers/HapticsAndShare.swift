//
//  HapticsAndShare.swift
//  Camlo · 开幕
//

import Foundation
import SwiftUI
import UIKit
import WebKit

enum CamloPaths {
    nonisolated static var fm: FileManager { .default }

    nonisolated static var vaultRoot: URL {
        URL.documentsDirectory.appendingPathComponent("CamloVault", isDirectory: true)
    }

    nonisolated static var packagesDir: URL {
        vaultRoot.appendingPathComponent("Packages", isDirectory: true)
    }

    nonisolated static var exportsDir: URL {
        URL.temporaryDirectory.appendingPathComponent("CamloExports", isDirectory: true)
    }

    nonisolated static var thumbnailsDir: URL {
        vaultRoot.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    nonisolated static var catalogJSON: URL {
        vaultRoot.appendingPathComponent("vault_catalog.json")
    }

    nonisolated static var runtimeCacheRoot: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return base.appendingPathComponent("CamloRuntime", isDirectory: true)
    }

    nonisolated static var posterThumbsCacheDir: URL {
        runtimeCacheRoot.appendingPathComponent("PosterThumbs", isDirectory: true)
    }

    nonisolated static var cloudPreviewCacheDir: URL {
        runtimeCacheRoot.appendingPathComponent("CloudPreviews", isDirectory: true)
    }

    nonisolated static func ensureDirectories() {
        for dir in [vaultRoot, packagesDir, exportsDir, thumbnailsDir, runtimeCacheRoot, posterThumbsCacheDir, cloudPreviewCacheDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}

enum CamloHaptics {
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    @MainActor
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }

    @MainActor
    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }
}

/// Reusable press-feedback button style that keeps ScrollView drag gestures smooth
/// while ensuring full-rect hit testing and subtle tactile feedback.
struct CamloTapButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

enum CamloShare {
    @MainActor
    static func resolveTopViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        for scene in scenes {
            if let keyWin = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
               var top = keyWin.rootViewController {
                while let presented = top.presentedViewController {
                    top = presented
                }
                return top
            }
        }
        return nil
    }

    @MainActor
    static func presentShareSheet(for url: URL) {
        guard let top = resolveTopViewController() else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }

    @MainActor
    static func openInFilesApp(_ fileURL: URL) {
        guard var comp = URLComponents(url: fileURL, resolvingAgainstBaseURL: false) else { return }
        comp.scheme = "shareddocuments"
        if let target = comp.url {
            UIApplication.shared.open(target)
        }
    }

    @MainActor
    static func openPosterBoardApp() {
        _ = csstore_open_bundle_id("com.apple.PosterBoard")
    }
}

enum CamloDevice {
    static var osVersionString: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static var buildNumber: String {
        var buf = [CChar](repeating: 0, count: 24)
        var len = size_t(buf.count - 1)
        if sysctlbyname("kern.osversion", &buf, &len, nil, 0) == 0,
           let s = String(validatingUTF8: buf) {
            return s
        }
        return "Unknown"
    }

    static var machineIdentifier: String {
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        return mirror.children.reduce("") { acc, elem in
            guard let v = elem.value as? Int8, v != 0 else { return acc }
            return acc + String(UnicodeScalar(UInt8(v)))
        }
    }

    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.2.1"
    }

    static func formattedLockScreenDate(for date: Date = Date()) -> String {
        let isEnglish: Bool
        if let explicit = UserDefaults.standard.string(forKey: "camlo_app_language") {
            isEnglish = (explicit == "en")
        } else {
            isEnglish = LocalizationManager.isEnglish
        }
        let formatter = DateFormatter()
        if isEnglish {
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, MMM d"
        } else {
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 EEEE"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Jailed WebKit Respring (Adapted from GPLv3 Erosion by @neonmodder123 & @skadz108)

private let camloRespringHTML = """
<!DOCTYPE html>
<html>
    <body>
        <iframe id="frame" srcdoc="" sandbox="allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-popups allow-presentation allow-scripts"></iframe>
        <script>
            const frame = document.getElementById('frame');
            const respringScript = `
                <html>
                <body>
                    <script>
                        const container = document.createElement('div');
                        container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';
                        document.body.appendChild(container);
                        for (let i = 0; i < 500; i++) {
                            let d = document.createElement('div');
                            d.style.cssText = 'position: absolute; width: 100vw; height: 100vh; backdrop-filter: blur(100px); -webkit-backdrop-filter: blur(100px); transform: translate3d(100000px, 100000px, ' + i + 'px) rotateY(90deg);';
                            container.appendChild(d);
                        }
                        setInterval(() => {
                            navigator.share({ title: 'R', text: 'R'.repeat(100000) }).catch(() => {});
                            let x = new Uint8Array(1024 * 1024 * 10);
                            crypto.getRandomValues(x);
                        }, 0);
                    <\\/script>
                </body>
                </html>
            `;
            frame.srcdoc = respringScript;
        </script>
    </body>
</html>
"""

struct CamloRespringView: UIViewRepresentable {
    final class Coordinator: NSObject, WKNavigationDelegate {
        var didInitialLoad = false
        var retryCount = 0

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard retryCount < 6 else { return }
            retryCount += 1
            webView.loadHTMLString(camloRespringHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs

        let bounds = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }?
            .effectiveGeometry.coordinateSpace.bounds ?? CGRect(x: 0, y: 0, width: 440, height: 956)

        let webView = WKWebView(frame: bounds, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = true
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !context.coordinator.didInitialLoad else { return }
        context.coordinator.didInitialLoad = true
        webView.loadHTMLString(camloRespringHTML, baseURL: nil)
    }
}
