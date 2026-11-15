//
//  LocalizationManager.swift
//  Camlo · 开幕
//

import Foundation
import Combine
import SwiftUI

public enum AppLanguageMode: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .system: return L("跟随系统")
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

private final class LocalizationBundleState: @unchecked Sendable {
    static let shared = LocalizationBundleState()
    private let lock = NSLock()
    private var cachedCode: String = "zh-Hans"
    private var cachedBundle: Bundle = .main

    init() {
        reloadFromDefaults()
    }

    static func detectSystemLanguageCode() -> String {
        let globalLangs = UserDefaults.standard.volatileDomain(forName: UserDefaults.globalDomain)["AppleLanguages"] as? [String]
        let candidates = (globalLangs?.isEmpty == false) ? globalLangs! : Locale.preferredLanguages
        if let first = candidates.first?.lowercased() {
            if first.hasPrefix("zh") {
                return "zh-Hans"
            }
            return "en"
        }
        return "zh-Hans"
    }

    func reloadFromDefaults() {
        let raw = UserDefaults.standard.string(forKey: "appLanguageMode") ?? "system"
        let resolved: String
        switch raw {
        case "en":
            resolved = "en"
        case "zh-Hans":
            resolved = "zh-Hans"
        default:
            resolved = Self.detectSystemLanguageCode()
        }
        let bundle: Bundle
        if let path = Bundle.main.path(forResource: resolved, ofType: "lproj"),
           let sub = Bundle(path: path) {
            bundle = sub
        } else {
            bundle = .main
        }
        lock.lock()
        cachedCode = resolved
        cachedBundle = bundle
        lock.unlock()
    }

    var snapshot: (code: String, bundle: Bundle) {
        lock.lock()
        defer { lock.unlock() }
        return (cachedCode, cachedBundle)
    }
}

public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    public static let defaultsKey = "appLanguageMode"

    @Published public var languageModeRaw: String {
        didSet {
            guard oldValue != languageModeRaw else { return }
            UserDefaults.standard.set(languageModeRaw, forKey: Self.defaultsKey)
            switch languageModeRaw {
            case "en":
                UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            case "zh-Hans":
                UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
            default:
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
            LocalizationBundleState.shared.reloadFromDefaults()
            refreshID = UUID()
        }
    }

    @Published public private(set) var refreshID = UUID()

    private init() {
        self.languageModeRaw = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? "system"
        LocalizationBundleState.shared.reloadFromDefaults()
    }

    public static var effectiveLanguageCode: String {
        LocalizationBundleState.shared.snapshot.code
    }

    public static var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }

    public var isEnglish: Bool {
        Self.isEnglish
    }

    public var effectiveLocale: Locale {
        Locale(identifier: Self.effectiveLanguageCode)
    }

    public static func localizedKey(_ key: String) -> String {
        guard !key.isEmpty else { return key }
        let snap = LocalizationBundleState.shared.snapshot
        guard snap.code != "zh-Hans" else { return key }
        return snap.bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

@inline(__always)
public func L(_ value: String.LocalizationValue) -> String {
    let snap = LocalizationBundleState.shared.snapshot
    return String(
        localized: value,
        bundle: snap.bundle,
        locale: Locale(identifier: snap.code)
    )
}

@inline(__always)
public func Bi(_ zh: String, _ en: String) -> String {
    LocalizationManager.isEnglish ? en : zh
}
