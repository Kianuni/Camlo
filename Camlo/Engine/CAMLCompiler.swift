//
//  CAMLCompiler.swift
//  Camlo · 开幕
//
//  Pure-Swift Apple Core Animation Markup Language (CAML 1.0) compiler.
//  Generates 100% LayerKit / PosterBoard & CAPlayground compliant Background.ca,
//  Floating.ca (in front of Lock Screen Clock), and Foreground.ca (particles & flash) bundles.
//

import Foundation
import UIKit

struct MorphCompileSpec {
    var title: String
    var lockImage: UIImage
    var unlockImage: UIImage
    var customSleepImage: UIImage?
    var lockSubjectCutout: UIImage?
    var unlockSubjectCutout: UIImage?
    var lockLiveSequence: ExtractedVideoSequence? = nil
    var unlockLiveSequence: ExtractedVideoSequence? = nil
    var liveLoopStyle: VideoLoopStyle = .pingPong
    var preset: MorphTransitionPreset
    var durationSeconds: Double       // 0.35 ... 1.40
    var springBounce: Double          // 0.0 (smooth) ... 1.0 (bouncy)
    var particlePreset: ParticlePreset
    var enableGyroParallax: Bool = false
    var gyroIntensity: Double = 0.65
    var enableDayNightMode: Bool = false
    var nightLockImage: UIImage? = nil
    var nightUnlockImage: UIImage? = nil
    var nightLockCutout: UIImage? = nil
    var nightUnlockCutout: UIImage? = nil
    var nightParticlePreset: ParticlePreset? = nil
    var posterStyle: PosterStyleSpec = PosterStyleSpec()
    var canvasProfile: CanvasDisplayProfile = .standardPhone
    var innerLockImage: UIImage? = nil
    var innerUnlockImage: UIImage? = nil
    var innerSleepImage: UIImage? = nil
    var innerLockSubjectCutout: UIImage? = nil
    var innerUnlockSubjectCutout: UIImage? = nil
    var innerLockLiveSequence: ExtractedVideoSequence? = nil
    var innerUnlockLiveSequence: ExtractedVideoSequence? = nil
    var nightInnerLockImage: UIImage? = nil
    var nightInnerUnlockImage: UIImage? = nil
    var nightInnerLockCutout: UIImage? = nil
    var nightInnerUnlockCutout: UIImage? = nil
}

struct VideoCompileSpec {
    var title: String
    var sequence: ExtractedVideoSequence
    var loopStyle: VideoLoopStyle
    var unlockZoomScale: Double       // e.g. 1.0 ... 1.12
    var dimInSleepMode: Bool
    var renderAboveClock: Bool
    var particlePreset: ParticlePreset
    var enableGyroParallax: Bool = false
    var gyroIntensity: Double = 0.55
    var posterStyle: PosterStyleSpec = PosterStyleSpec()
    var canvasProfile: CanvasDisplayProfile = .standardPhone
    var innerSequence: ExtractedVideoSequence? = nil
}

enum CAMLCompiler {
    struct CanvasMetrics: Sendable {
        let width: Int
        let height: Int
        let pixelSize: CGSize
        let assetPrefix: String
        let idPrefix: String
        let namePrefix: String
        let bgParallaxName: String
        let bgOverscanName: String
        let fgParallaxName: String
        let fgOverscanName: String
        let fxParallaxName: String

        static func fmtCoord(_ v: Double) -> String {
            if abs(v - v.rounded()) < 0.0001 {
                return String(Int(v.rounded()))
            }
            return String(format: "%.1f", v)
        }

        var centerX: Int { width / 2 }
        var centerY: Int { height / 2 }
        var centerXDouble: Double { Double(width) * 0.5 }
        var centerYDouble: Double { Double(height) * 0.5 }
        var centerPosString: String { "\(Self.fmtCoord(centerXDouble)) \(Self.fmtCoord(centerYDouble))" }
        var scaleX: Double { Double(width) / 390.0 }
        var scaleY: Double { Double(height) / 844.0 }

        static let standardPhone = CanvasMetrics(
            width: 390,
            height: 844,
            pixelSize: CGSize(width: 1170, height: 2532),
            assetPrefix: "",
            idPrefix: "",
            namePrefix: "",
            bgParallaxName: "Camlo_BG_Parallax",
            bgOverscanName: "Camlo_BG_Overscan",
            fgParallaxName: "Camlo_FG_Parallax",
            fgOverscanName: "Camlo_FG_Overscan",
            fxParallaxName: "Camlo_FX_Parallax"
        )

        static let duoOuterCover = CanvasMetrics(
            width: 466,
            height: 678,
            pixelSize: CGSize(width: 1398, height: 2034),
            assetPrefix: "",
            idPrefix: "",
            namePrefix: "",
            bgParallaxName: "Camlo_BG_Parallax",
            bgOverscanName: "Camlo_BG_Overscan",
            fgParallaxName: "Camlo_FG_Parallax",
            fgOverscanName: "Camlo_FG_Overscan",
            fxParallaxName: "Camlo_FX_Parallax"
        )

        static let duoInnerUnfolded = CanvasMetrics(
            width: 951,
            height: 669,
            pixelSize: CGSize(width: 2282, height: 1606),
            assetPrefix: "inner_",
            idPrefix: "inner_",
            namePrefix: "Inner ",
            bgParallaxName: "Camlo_Inner_BG_Parallax",
            bgOverscanName: "Camlo_Inner_BG_Overscan",
            fgParallaxName: "Camlo_Inner_FG_Parallax",
            fgOverscanName: "Camlo_Inner_FG_Overscan",
            fxParallaxName: "Camlo_Inner_FX_Parallax"
        )
    }

    static let canvasW = 390
    static let canvasH = 844
    static let centerX = 195
    static let centerY = 422
    static let retinaSize = CGSize(width: 1170, height: 2532)

    private struct StateOverride {
        let targetId: String
        let layerName: String
        let keyPath: String
        let sleepVal: Double
        let lockedVal: Double
        let unlockVal: Double
        let isInteger: Bool
    }

    private struct LayerBuildResult {
        let sublayersXML: String
        let overrides: [StateOverride]
    }

    // MARK: - Public Bundle Writers

    static func writeMorphWallpaperDirectory(spec: MorphCompileSpec, into wallpaperDir: URL) throws {
        if spec.canvasProfile == .duoDualScreen {
            try writeDuoMorphParameterizedBundle(
                bundleName: "wallpaper.ca",
                outerLockImage: spec.lockImage,
                outerUnlockImage: spec.unlockImage,
                outerSleepImage: spec.customSleepImage,
                outerLockCutout: spec.lockSubjectCutout,
                outerUnlockCutout: spec.unlockSubjectCutout,
                outerLockLiveSequence: spec.lockLiveSequence,
                outerUnlockLiveSequence: spec.unlockLiveSequence,
                innerLockImage: spec.innerLockImage ?? spec.lockImage,
                innerUnlockImage: spec.innerUnlockImage ?? spec.unlockImage,
                innerSleepImage: spec.innerSleepImage ?? spec.customSleepImage,
                innerLockCutout: spec.innerLockSubjectCutout,
                innerUnlockCutout: spec.innerUnlockSubjectCutout,
                innerLockLiveSequence: spec.innerLockLiveSequence,
                innerUnlockLiveSequence: spec.innerUnlockLiveSequence,
                particlePreset: spec.particlePreset,
                spec: spec,
                into: wallpaperDir
            )
            if spec.enableDayNightMode {
                let nOuterLock = spec.nightLockImage ?? PosterStyleGenerator.synthesizeNightImage(from: spec.lockImage)
                let nOuterUnlock = spec.nightUnlockImage ?? PosterStyleGenerator.synthesizeNightImage(from: spec.unlockImage)
                let nOuterLockCut = spec.nightLockCutout ?? (spec.nightLockImage == nil ? spec.lockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)
                let nOuterUnlockCut = spec.nightUnlockCutout ?? (spec.nightUnlockImage == nil ? spec.unlockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)

                let baseInnerLock = spec.innerLockImage ?? spec.lockImage
                let baseInnerUnlock = spec.innerUnlockImage ?? spec.unlockImage
                let nInnerLock = spec.nightInnerLockImage ?? PosterStyleGenerator.synthesizeNightImage(from: baseInnerLock)
                let nInnerUnlock = spec.nightInnerUnlockImage ?? PosterStyleGenerator.synthesizeNightImage(from: baseInnerUnlock)
                let nInnerLockCut = spec.nightInnerLockCutout ?? (spec.nightInnerLockImage == nil ? spec.innerLockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)
                let nInnerUnlockCut = spec.nightInnerUnlockCutout ?? (spec.nightInnerUnlockImage == nil ? spec.innerUnlockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)
                let nightParticles = spec.nightParticlePreset ?? spec.particlePreset

                try writeDuoMorphParameterizedBundle(
                    bundleName: "wallpaper_dark.ca",
                    outerLockImage: nOuterLock,
                    outerUnlockImage: nOuterUnlock,
                    outerSleepImage: nil,
                    outerLockCutout: nOuterLockCut,
                    outerUnlockCutout: nOuterUnlockCut,
                    outerLockLiveSequence: nil,
                    outerUnlockLiveSequence: nil,
                    innerLockImage: nInnerLock,
                    innerUnlockImage: nInnerUnlock,
                    innerSleepImage: nil,
                    innerLockCutout: nInnerLockCut,
                    innerUnlockCutout: nInnerUnlockCut,
                    innerLockLiveSequence: nil,
                    innerUnlockLiveSequence: nil,
                    particlePreset: nightParticles,
                    spec: spec,
                    into: wallpaperDir
                )
            }
            return
        }

        if spec.enableGyroParallax {
            try writeMorphParameterizedBundle(
                bundleName: "wallpaper.ca",
                lockImage: spec.lockImage,
                unlockImage: spec.unlockImage,
                sleepImage: spec.customSleepImage,
                lockCutout: spec.lockSubjectCutout,
                unlockCutout: spec.unlockSubjectCutout,
                lockLiveSequence: spec.lockLiveSequence,
                unlockLiveSequence: spec.unlockLiveSequence,
                particlePreset: spec.particlePreset,
                spec: spec,
                into: wallpaperDir
            )
            if spec.enableDayNightMode {
                let nightLock = spec.nightLockImage ?? PosterStyleGenerator.synthesizeNightImage(from: spec.lockImage)
                let nightUnlock = spec.nightUnlockImage ?? PosterStyleGenerator.synthesizeNightImage(from: spec.unlockImage)
                let nightLockCut = spec.nightLockCutout ?? (spec.nightLockImage == nil ? spec.lockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)
                let nightUnlockCut = spec.nightUnlockCutout ?? (spec.nightUnlockImage == nil ? spec.unlockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)
                let nightParticles = spec.nightParticlePreset ?? spec.particlePreset

                try writeMorphParameterizedBundle(
                    bundleName: "wallpaper_dark.ca",
                    lockImage: nightLock,
                    unlockImage: nightUnlock,
                    sleepImage: nil,
                    lockCutout: nightLockCut,
                    unlockCutout: nightUnlockCut,
                    lockLiveSequence: nil,
                    unlockLiveSequence: nil,
                    particlePreset: nightParticles,
                    spec: spec,
                    into: wallpaperDir
                )
            }
        } else {
            try writeMorphLayeredBundleSet(
                prefix: "7400.WWDC_2022",
                lockImage: spec.lockImage,
                unlockImage: spec.unlockImage,
                sleepImage: spec.customSleepImage,
                lockCutout: spec.lockSubjectCutout,
                unlockCutout: spec.unlockSubjectCutout,
                lockLiveSequence: spec.lockLiveSequence,
                unlockLiveSequence: spec.unlockLiveSequence,
                particlePreset: spec.particlePreset,
                spec: spec,
                into: wallpaperDir
            )
            if spec.enableDayNightMode {
                let nightLock = spec.nightLockImage ?? PosterStyleGenerator.synthesizeNightImage(from: spec.lockImage)
                let nightUnlock = spec.nightUnlockImage ?? PosterStyleGenerator.synthesizeNightImage(from: spec.unlockImage)
                let nightLockCut = spec.nightLockCutout ?? (spec.nightLockImage == nil ? spec.lockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)
                let nightUnlockCut = spec.nightUnlockCutout ?? (spec.nightUnlockImage == nil ? spec.unlockSubjectCutout.map { PosterStyleGenerator.synthesizeNightImage(from: $0, preserveAlpha: true) } : nil)
                let nightParticles = spec.nightParticlePreset ?? spec.particlePreset

                try writeMorphLayeredBundleSet(
                    prefix: "7401.WWDC_2022_Dark",
                    lockImage: nightLock,
                    unlockImage: nightUnlock,
                    sleepImage: nil,
                    lockCutout: nightLockCut,
                    unlockCutout: nightUnlockCut,
                    lockLiveSequence: nil,
                    unlockLiveSequence: nil,
                    particlePreset: nightParticles,
                    spec: spec,
                    into: wallpaperDir
                )
            }
        }
    }

    static func writeVideoWallpaperDirectory(spec: VideoCompileSpec, into wallpaperDir: URL) throws {
        if spec.canvasProfile == .duoDualScreen {
            let ca = wallpaperDir.appendingPathComponent("wallpaper.ca", isDirectory: true)
            let outer = CanvasMetrics.duoOuterCover
            let inner = CanvasMetrics.duoInnerUnfolded
            try prepareCABundle(at: ca, documentWidth: outer.width, documentHeight: outer.height)
            let assetsDir = ca.appendingPathComponent("assets", isDirectory: true)

            let outerBuild = try buildAndEncodeVideoLayers(spec: spec, assetsDir: assetsDir, canvas: outer)
            let outerFX = try buildAndEncodeForegroundFX(
                particlePreset: spec.particlePreset,
                includeFlashPulse: false,
                assetsDir: assetsDir,
                canvas: outer,
                encodeAssets: true
            )

            let innerSeq = spec.innerSequence ?? spec.sequence
            let innerBuild = try buildAndEncodeVideoLayers(
                spec: spec,
                assetsDir: assetsDir,
                canvas: inner,
                sequenceOverride: innerSeq
            )
            let innerFX = try buildAndEncodeForegroundFX(
                particlePreset: spec.particlePreset,
                includeFlashPulse: false,
                assetsDir: assetsDir,
                canvas: inner,
                encodeAssets: false
            )

            let fgScale: Double = spec.renderAboveClock
                ? (1.0 + 0.16 * max(0.20, min(spec.gyroIntensity, 1.0)))
                : 1.0

            let caml = wrapDuoDualRootCAML(
                outer: outer,
                inner: inner,
                outerBgSublayersXML: spec.renderAboveClock ? "" : outerBuild.sublayersXML,
                outerFgSublayersXML: spec.renderAboveClock ? outerBuild.sublayersXML : "",
                outerFxSublayersXML: outerFX.sublayersXML,
                innerBgSublayersXML: spec.renderAboveClock ? "" : innerBuild.sublayersXML,
                innerFgSublayersXML: spec.renderAboveClock ? innerBuild.sublayersXML : "",
                innerFxSublayersXML: innerFX.sublayersXML,
                outerFgOverscanScale: fgScale,
                innerFgOverscanScale: fgScale,
                outerBgOverrides: spec.renderAboveClock ? [] : outerBuild.overrides,
                outerFloatingOverrides: (spec.renderAboveClock ? outerBuild.overrides : []) + outerFX.overrides,
                innerBgOverrides: spec.renderAboveClock ? [] : innerBuild.overrides,
                innerFloatingOverrides: (spec.renderAboveClock ? innerBuild.overrides : []) + innerFX.overrides,
                duration: 0.75,
                bounce: 0.35,
                gyroIntensity: spec.gyroIntensity
            )
            try caml.data(using: .utf8)?.write(to: ca.appendingPathComponent("main.caml"), options: .atomic)
            return
        }

        if spec.enableGyroParallax {
            let ca = wallpaperDir.appendingPathComponent("wallpaper.ca", isDirectory: true)
            try prepareCABundle(at: ca)
            let assetsDir = ca.appendingPathComponent("assets", isDirectory: true)

            let videoBuild = try buildAndEncodeVideoLayers(spec: spec, assetsDir: assetsDir)
            let fxBuild = try buildAndEncodeForegroundFX(
                particlePreset: spec.particlePreset,
                includeFlashPulse: false,
                assetsDir: assetsDir
            )

            let caml = wrapParameterizedRootCAML(
                bgSublayersXML: spec.renderAboveClock ? "" : videoBuild.sublayersXML,
                fgSublayersXML: spec.renderAboveClock ? videoBuild.sublayersXML : "",
                fxSublayersXML: fxBuild.sublayersXML,
                fgOverscanScale: spec.renderAboveClock ? (1.0 + 0.16 * max(0.20, min(spec.gyroIntensity, 1.0))) : 1.0,
                bgOverrides: spec.renderAboveClock ? [] : videoBuild.overrides,
                floatingOverrides: (spec.renderAboveClock ? videoBuild.overrides : []) + fxBuild.overrides,
                duration: 0.75,
                bounce: 0.35,
                gyroIntensity: spec.gyroIntensity
            )
            try caml.data(using: .utf8)?.write(to: ca.appendingPathComponent("main.caml"), options: .atomic)
            return
        }

        let bgCA = wallpaperDir.appendingPathComponent("7400.WWDC_2022_Background-390w-844h@3x~iphone.ca", isDirectory: true)
        let flCA = wallpaperDir.appendingPathComponent("7400.WWDC_2022_Floating-390w-844h@3x~iphone.ca", isDirectory: true)
        let fgCA = wallpaperDir.appendingPathComponent("7400.WWDC_2022_Foreground-390w-844h@3x~iphone.ca", isDirectory: true)

        for ca in [bgCA, flCA, fgCA] {
            try prepareCABundle(at: ca)
        }

        let targetVideoCA = spec.renderAboveClock ? flCA : bgCA
        let emptyOtherCA = spec.renderAboveClock ? bgCA : flCA

        let videoBuild = try buildAndEncodeVideoLayers(
            spec: spec,
            assetsDir: targetVideoCA.appendingPathComponent("assets", isDirectory: true)
        )
        let videoXML = wrapRootCAML(
            opaqueBlackBackground: !spec.renderAboveClock,
            sublayersXML: videoBuild.sublayersXML,
            overrides: videoBuild.overrides,
            duration: 0.75,
            bounce: 0.35
        )
        try videoXML.data(using: .utf8)?.write(to: targetVideoCA.appendingPathComponent("main.caml"), options: .atomic)

        let emptyXML = buildEmptyCAML(opaqueBlackRoot: spec.renderAboveClock)
        try emptyXML.data(using: .utf8)?.write(to: emptyOtherCA.appendingPathComponent("main.caml"), options: .atomic)

        let fxBuild = try buildAndEncodeForegroundFX(
            particlePreset: spec.particlePreset,
            includeFlashPulse: false,
            assetsDir: fgCA.appendingPathComponent("assets", isDirectory: true)
        )
        let fgXML = fxBuild.sublayersXML.isEmpty && fxBuild.overrides.isEmpty
            ? buildEmptyCAML(opaqueBlackRoot: false)
            : wrapRootCAML(
                opaqueBlackBackground: false,
                sublayersXML: fxBuild.sublayersXML,
                overrides: fxBuild.overrides,
                duration: 0.65,
                bounce: 0.25
            )
        try fgXML.data(using: .utf8)?.write(to: fgCA.appendingPathComponent("main.caml"), options: .atomic)
    }

    // MARK: - Bundle Variant Composers

    private static func prepareCABundle(
        at caURL: URL,
        documentWidth: Int = canvasW,
        documentHeight: Int = canvasH
    ) throws {
        try FileManager.default.createDirectory(at: caURL.appendingPathComponent("assets", isDirectory: true), withIntermediateDirectories: true)
        try standardIndexXML(documentWidth: documentWidth, documentHeight: documentHeight).data(using: .utf8)?.write(to: caURL.appendingPathComponent("index.xml"), options: .atomic)
        try standardAssetManifestXML().data(using: .utf8)?.write(to: caURL.appendingPathComponent("assetManifest.caml"), options: .atomic)
    }

    private static func writeMorphLayeredBundleSet(
        prefix: String,
        lockImage: UIImage,
        unlockImage: UIImage,
        sleepImage: UIImage?,
        lockCutout: UIImage?,
        unlockCutout: UIImage?,
        lockLiveSequence: ExtractedVideoSequence?,
        unlockLiveSequence: ExtractedVideoSequence?,
        particlePreset: ParticlePreset,
        spec: MorphCompileSpec,
        into wallpaperDir: URL
    ) throws {
        let bgCA = wallpaperDir.appendingPathComponent("\(prefix)_Background-390w-844h@3x~iphone.ca", isDirectory: true)
        let flCA = wallpaperDir.appendingPathComponent("\(prefix)_Floating-390w-844h@3x~iphone.ca", isDirectory: true)
        let fgCA = wallpaperDir.appendingPathComponent("\(prefix)_Foreground-390w-844h@3x~iphone.ca", isDirectory: true)

        for ca in [bgCA, flCA, fgCA] {
            try prepareCABundle(at: ca)
        }

        let bgBuild = try buildAndEncodeMorphBackground(
            lockImage: lockImage,
            unlockImage: unlockImage,
            sleepImage: sleepImage,
            lockLiveSequence: lockLiveSequence,
            unlockLiveSequence: unlockLiveSequence,
            autoReversesLive: spec.liveLoopStyle == .pingPong,
            preset: spec.preset,
            assetsDir: bgCA.appendingPathComponent("assets", isDirectory: true)
        )
        let bgXML = wrapRootCAML(
            opaqueBlackBackground: true,
            sublayersXML: bgBuild.sublayersXML,
            overrides: bgBuild.overrides,
            duration: spec.durationSeconds,
            bounce: spec.springBounce
        )
        try bgXML.data(using: .utf8)?.write(to: bgCA.appendingPathComponent("main.caml"), options: .atomic)

        let flBuild = try buildAndEncodeMorphFloating(
            lockCutout: lockCutout,
            unlockCutout: unlockCutout,
            preset: spec.preset,
            assetsDir: flCA.appendingPathComponent("assets", isDirectory: true)
        )
        let flXML = flBuild.sublayersXML.isEmpty && flBuild.overrides.isEmpty
            ? buildEmptyCAML(opaqueBlackRoot: false)
            : wrapRootCAML(
                opaqueBlackBackground: false,
                sublayersXML: flBuild.sublayersXML,
                overrides: flBuild.overrides,
                duration: spec.durationSeconds,
                bounce: spec.springBounce
            )
        try flXML.data(using: .utf8)?.write(to: flCA.appendingPathComponent("main.caml"), options: .atomic)

        let fxBuild = try buildAndEncodeForegroundFX(
            particlePreset: particlePreset,
            includeFlashPulse: spec.preset == .flashAwaken,
            assetsDir: fgCA.appendingPathComponent("assets", isDirectory: true)
        )
        let fgXML = fxBuild.sublayersXML.isEmpty && fxBuild.overrides.isEmpty
            ? buildEmptyCAML(opaqueBlackRoot: false)
            : wrapRootCAML(
                opaqueBlackBackground: false,
                sublayersXML: fxBuild.sublayersXML,
                overrides: fxBuild.overrides,
                duration: 0.65,
                bounce: 0.25
            )
        try fgXML.data(using: .utf8)?.write(to: fgCA.appendingPathComponent("main.caml"), options: .atomic)
    }

    private static func writeMorphParameterizedBundle(
        bundleName: String,
        lockImage: UIImage,
        unlockImage: UIImage,
        sleepImage: UIImage?,
        lockCutout: UIImage?,
        unlockCutout: UIImage?,
        lockLiveSequence: ExtractedVideoSequence?,
        unlockLiveSequence: ExtractedVideoSequence?,
        particlePreset: ParticlePreset,
        spec: MorphCompileSpec,
        into wallpaperDir: URL
    ) throws {
        let ca = wallpaperDir.appendingPathComponent(bundleName, isDirectory: true)
        try prepareCABundle(at: ca)
        let assetsDir = ca.appendingPathComponent("assets", isDirectory: true)

        let bgBuild = try buildAndEncodeMorphBackground(
            lockImage: lockImage,
            unlockImage: unlockImage,
            sleepImage: sleepImage,
            lockLiveSequence: lockLiveSequence,
            unlockLiveSequence: unlockLiveSequence,
            autoReversesLive: spec.liveLoopStyle == .pingPong,
            preset: spec.preset,
            assetsDir: assetsDir
        )
        let flBuild = try buildAndEncodeMorphFloating(
            lockCutout: lockCutout,
            unlockCutout: unlockCutout,
            preset: spec.preset,
            assetsDir: assetsDir
        )
        let fxBuild = try buildAndEncodeForegroundFX(
            particlePreset: particlePreset,
            includeFlashPulse: spec.preset == .flashAwaken,
            assetsDir: assetsDir
        )

        let cutoutOverscan = 1.0 + 0.08 * max(0.20, min(spec.gyroIntensity, 1.0))
        let caml = wrapParameterizedRootCAML(
            bgSublayersXML: bgBuild.sublayersXML,
            fgSublayersXML: flBuild.sublayersXML,
            fxSublayersXML: fxBuild.sublayersXML,
            fgOverscanScale: (lockCutout != nil || unlockCutout != nil) ? cutoutOverscan : 1.0,
            bgOverrides: bgBuild.overrides,
            floatingOverrides: flBuild.overrides + fxBuild.overrides,
            duration: spec.durationSeconds,
            bounce: spec.springBounce,
            gyroIntensity: spec.gyroIntensity
        )
        try caml.data(using: .utf8)?.write(to: ca.appendingPathComponent("main.caml"), options: .atomic)
    }

    private static func writeDuoMorphParameterizedBundle(
        bundleName: String,
        outerLockImage: UIImage,
        outerUnlockImage: UIImage,
        outerSleepImage: UIImage?,
        outerLockCutout: UIImage?,
        outerUnlockCutout: UIImage?,
        outerLockLiveSequence: ExtractedVideoSequence?,
        outerUnlockLiveSequence: ExtractedVideoSequence?,
        innerLockImage: UIImage,
        innerUnlockImage: UIImage,
        innerSleepImage: UIImage?,
        innerLockCutout: UIImage?,
        innerUnlockCutout: UIImage?,
        innerLockLiveSequence: ExtractedVideoSequence?,
        innerUnlockLiveSequence: ExtractedVideoSequence?,
        particlePreset: ParticlePreset,
        spec: MorphCompileSpec,
        into wallpaperDir: URL
    ) throws {
        let ca = wallpaperDir.appendingPathComponent(bundleName, isDirectory: true)
        let outer = CanvasMetrics.duoOuterCover
        let inner = CanvasMetrics.duoInnerUnfolded
        try prepareCABundle(at: ca, documentWidth: outer.width, documentHeight: outer.height)
        let assetsDir = ca.appendingPathComponent("assets", isDirectory: true)

        let outerBg = try buildAndEncodeMorphBackground(
            lockImage: outerLockImage,
            unlockImage: outerUnlockImage,
            sleepImage: outerSleepImage,
            lockLiveSequence: outerLockLiveSequence,
            unlockLiveSequence: outerUnlockLiveSequence,
            autoReversesLive: spec.liveLoopStyle == .pingPong,
            preset: spec.preset,
            assetsDir: assetsDir,
            canvas: outer
        )
        let outerFl = try buildAndEncodeMorphFloating(
            lockCutout: outerLockCutout,
            unlockCutout: outerUnlockCutout,
            preset: spec.preset,
            assetsDir: assetsDir,
            canvas: outer
        )
        let outerFx = try buildAndEncodeForegroundFX(
            particlePreset: particlePreset,
            includeFlashPulse: spec.preset == .flashAwaken,
            assetsDir: assetsDir,
            canvas: outer,
            encodeAssets: true
        )

        let innerBg = try buildAndEncodeMorphBackground(
            lockImage: innerLockImage,
            unlockImage: innerUnlockImage,
            sleepImage: innerSleepImage,
            lockLiveSequence: innerLockLiveSequence,
            unlockLiveSequence: innerUnlockLiveSequence,
            autoReversesLive: spec.liveLoopStyle == .pingPong,
            preset: spec.preset,
            assetsDir: assetsDir,
            canvas: inner
        )
        let innerFl = try buildAndEncodeMorphFloating(
            lockCutout: innerLockCutout,
            unlockCutout: innerUnlockCutout,
            preset: spec.preset,
            assetsDir: assetsDir,
            canvas: inner
        )
        let innerFx = try buildAndEncodeForegroundFX(
            particlePreset: particlePreset,
            includeFlashPulse: spec.preset == .flashAwaken,
            assetsDir: assetsDir,
            canvas: inner,
            encodeAssets: false
        )

        let cutoutOverscan = 1.0 + 0.08 * max(0.20, min(spec.gyroIntensity, 1.0))
        let caml = wrapDuoDualRootCAML(
            outer: outer,
            inner: inner,
            outerBgSublayersXML: outerBg.sublayersXML,
            outerFgSublayersXML: outerFl.sublayersXML,
            outerFxSublayersXML: outerFx.sublayersXML,
            innerBgSublayersXML: innerBg.sublayersXML,
            innerFgSublayersXML: innerFl.sublayersXML,
            innerFxSublayersXML: innerFx.sublayersXML,
            outerFgOverscanScale: (outerLockCutout != nil || outerUnlockCutout != nil) ? cutoutOverscan : 1.0,
            innerFgOverscanScale: (innerLockCutout != nil || innerUnlockCutout != nil) ? cutoutOverscan : 1.0,
            outerBgOverrides: outerBg.overrides,
            outerFloatingOverrides: outerFl.overrides + outerFx.overrides,
            innerBgOverrides: innerBg.overrides,
            innerFloatingOverrides: innerFl.overrides + innerFx.overrides,
            duration: spec.durationSeconds,
            bounce: spec.springBounce,
            gyroIntensity: spec.gyroIntensity
        )
        try caml.data(using: .utf8)?.write(to: ca.appendingPathComponent("main.caml"), options: .atomic)
    }

    // MARK: - Internal CAML Builders

    private static func buildAndEncodeMorphBackground(
        lockImage: UIImage,
        unlockImage: UIImage,
        sleepImage: UIImage?,
        lockLiveSequence: ExtractedVideoSequence?,
        unlockLiveSequence: ExtractedVideoSequence?,
        autoReversesLive: Bool,
        preset: MorphTransitionPreset,
        assetsDir: URL,
        canvas: CanvasMetrics = .standardPhone
    ) throws -> LayerBuildResult {
        let activeUnlockLive = (unlockLiveSequence?.frameJPEGs.isEmpty == false) ? unlockLiveSequence : nil
        let activeLockLive = (lockLiveSequence?.frameJPEGs.isEmpty == false) ? lockLiveSequence : nil
        let aPrefix = canvas.assetPrefix
        let idPrefix = canvas.idPrefix
        let namePrefix = canvas.namePrefix

        if let lockSeq = activeLockLive {
            for (idx, frameData) in lockSeq.frameJPEGs.enumerated() {
                try frameData.write(to: assetsDir.appendingPathComponent("\(aPrefix)lock_frame_\(idx).jpg"), options: .atomic)
            }
        } else {
            try autoreleasepool {
                let lockScaled = lockImage.aspectFilled(to: canvas.pixelSize)
                guard let lockJPG = lockScaled.jpegData(compressionQuality: 0.88) else {
                    throw NSError(domain: "CamloCompiler", code: -10, userInfo: [NSLocalizedDescriptionKey: Bi("图片编码失败", "Failed to encode wallpaper images")])
                }
                try lockJPG.write(to: assetsDir.appendingPathComponent("\(aPrefix)locked.jpg"), options: .atomic)
            }
        }

        if let unlockSeq = activeUnlockLive {
            for (idx, frameData) in unlockSeq.frameJPEGs.enumerated() {
                try frameData.write(to: assetsDir.appendingPathComponent("\(aPrefix)unlock_frame_\(idx).jpg"), options: .atomic)
            }
        } else {
            try autoreleasepool {
                let unlockScaled = unlockImage.aspectFilled(to: canvas.pixelSize)
                guard let unlockJPG = unlockScaled.jpegData(compressionQuality: 0.88) else {
                    throw NSError(domain: "CamloCompiler", code: -10, userInfo: [NSLocalizedDescriptionKey: Bi("图片编码失败", "Failed to encode wallpaper images")])
                }
                try unlockJPG.write(to: assetsDir.appendingPathComponent("\(aPrefix)unlock.jpg"), options: .atomic)
            }
        }

        var hasCustomSleep = false
        if let sleepImage {
            autoreleasepool {
                if let sleepJPG = sleepImage.aspectFilled(to: canvas.pixelSize).jpegData(compressionQuality: 0.84),
                   (try? sleepJPG.write(to: assetsDir.appendingPathComponent("\(aPrefix)sleep.jpg"), options: .atomic)) != nil {
                    hasCustomSleep = true
                }
            }
        }

        var sublayers: [String] = []
        var overrides: [StateOverride] = []

        let unlockId = "\(idPrefix)unlock_layer"
        let unlockName = "\(namePrefix)Unlock Layer"
        let lockedId = "\(idPrefix)locked_layer"
        let lockedName = "\(namePrefix)Locked Layer"
        let sleepId = "\(idPrefix)sleep_layer"
        let sleepName = "\(namePrefix)Sleep Layer"
        let sleepDimId = "\(idPrefix)sleep_dimmer"
        let sleepDimName = "\(namePrefix)Sleep Dimmer"

        sublayers.append(
            morphMediaLayerXML(
                id: unlockId,
                name: unlockName,
                zPosition: 0,
                staticFilename: "\(aPrefix)unlock.jpg",
                livePrefix: "\(aPrefix)unlock_frame",
                liveSequence: activeUnlockLive,
                autoReverses: autoReversesLive,
                canvas: canvas
            )
        )

        sublayers.append(
            morphMediaLayerXML(
                id: lockedId,
                name: lockedName,
                zPosition: 1,
                staticFilename: "\(aPrefix)locked.jpg",
                livePrefix: "\(aPrefix)lock_frame",
                liveSequence: activeLockLive,
                autoReverses: autoReversesLive,
                canvas: canvas
            )
        )

        if hasCustomSleep {
            sublayers.append("""
                  <CALayer id="\(sleepId)" name="\(sleepName)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="2" opacity="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents>
                      <CGImage src="assets/\(aPrefix)sleep.jpg"/>
                    </contents>
                  </CALayer>
            """)
            overrides.append(StateOverride(targetId: sleepId, layerName: sleepName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 0.0, unlockVal: 0.0, isInteger: false))
        } else {
            let sleepDimAlpha = (preset == .aodGaze) ? 0.78 : 0.48
            sublayers.append("""
                  <CALayer id="\(sleepDimId)" name="\(sleepDimName)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
            """)
            overrides.append(StateOverride(targetId: sleepDimId, layerName: sleepDimName, keyPath: "opacity", sleepVal: sleepDimAlpha, lockedVal: 0.0, unlockVal: 0.0, isInteger: false))
        }

        let cy = canvas.centerYDouble
        let cx = canvas.centerXDouble
        let cxIsInt = abs(cx - cx.rounded()) < 0.001
        let cyIsInt = abs(cy - cy.rounded()) < 0.001
        let lockExitY = (Double(canvas.height) * 1.1137).rounded()
        let unlockSleepY = (cy - 30.0 * canvas.scaleY).rounded()
        let unlockLockedY = (cy - 18.0 * canvas.scaleY).rounded()
        let holoLockUnlockX = (cx + 20.0 * canvas.scaleX).rounded()
        let holoUnlockSleepX = (cx - 20.0 * canvas.scaleX).rounded()
        let holoUnlockLockedX = (cx - 17.0 * canvas.scaleX).rounded()

        switch preset {
        case .curtainRise:
            overrides.append(contentsOf: [
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "position.y", sleepVal: cy, lockedVal: cy, unlockVal: lockExitY, isInteger: cyIsInt),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 0.96, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "position.y", sleepVal: unlockSleepY, lockedVal: unlockLockedY, unlockVal: cy, isInteger: cyIsInt),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false),
            ])

        case .burstZoom:
            overrides.append(contentsOf: [
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "transform.scale.xy", sleepVal: 1.04, lockedVal: 1.0, unlockVal: 0.86, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "transform.scale.xy", sleepVal: 1.24, lockedVal: 1.22, unlockVal: 1.0, isInteger: false),
            ])

        case .crossfade:
            overrides.append(contentsOf: [
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.03, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "transform.scale.xy", sleepVal: 1.04, lockedVal: 1.03, unlockVal: 1.0, isInteger: false),
            ])

        case .flashAwaken:
            overrides.append(contentsOf: [
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.08, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "transform.scale.xy", sleepVal: 1.12, lockedVal: 1.10, unlockVal: 1.0, isInteger: false),
            ])

        case .holoCard:
            overrides.append(contentsOf: [
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "transform.rotation.y", sleepVal: -0.06, lockedVal: 0.0, unlockVal: 0.24, isInteger: false),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "position.x", sleepVal: cx, lockedVal: cx, unlockVal: holoLockUnlockX, isInteger: cxIsInt),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "transform.rotation.y", sleepVal: -0.24, lockedVal: -0.22, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "position.x", sleepVal: holoUnlockSleepX, lockedVal: holoUnlockLockedX, unlockVal: cx, isInteger: cxIsInt),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "transform.scale.xy", sleepVal: 1.06, lockedVal: 1.05, unlockVal: 1.0, isInteger: false),
            ])

        case .aodGaze:
            overrides.append(contentsOf: [
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: lockedId, layerName: lockedName, keyPath: "transform.scale.xy", sleepVal: 0.94, lockedVal: 1.0, unlockVal: 1.06, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: unlockId, layerName: unlockName, keyPath: "transform.scale.xy", sleepVal: 1.14, lockedVal: 1.12, unlockVal: 1.0, isInteger: false),
            ])
        }

        return LayerBuildResult(sublayersXML: sublayers.joined(separator: "\n"), overrides: overrides)
    }

    private static func buildAndEncodeMorphFloating(
        lockCutout: UIImage?,
        unlockCutout: UIImage?,
        preset: MorphTransitionPreset,
        assetsDir: URL,
        canvas: CanvasMetrics = .standardPhone
    ) throws -> LayerBuildResult {
        let aPrefix = canvas.assetPrefix
        let idPrefix = canvas.idPrefix
        let namePrefix = canvas.namePrefix

        var hasLockCutout = false
        var hasUnlockCutout = false
        if let lockCut = lockCutout {
            try autoreleasepool {
                let scaled = lockCut.aspectFilled(to: canvas.pixelSize)
                if let png = scaled.pngData() {
                    try png.write(to: assetsDir.appendingPathComponent("\(aPrefix)cutout_lock.png"), options: .atomic)
                    hasLockCutout = true
                }
            }
        }
        if let unlockCut = unlockCutout {
            try autoreleasepool {
                let scaled = unlockCut.aspectFilled(to: canvas.pixelSize)
                if let png = scaled.pngData() {
                    try png.write(to: assetsDir.appendingPathComponent("\(aPrefix)cutout_unlock.png"), options: .atomic)
                    hasUnlockCutout = true
                }
            }
        }

        guard hasLockCutout || hasUnlockCutout else {
            return LayerBuildResult(sublayersXML: "", overrides: [])
        }

        var sublayers: [String] = []
        var overrides: [StateOverride] = []

        if hasUnlockCutout {
            let fid = "\(idPrefix)float_unlock"
            let fname = "\(namePrefix)Floating Unlock Subject"
            sublayers.append("""
                  <CALayer id="\(fid)" name="\(fname)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="1" opacity="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents>
                      <CGImage src="assets/\(aPrefix)cutout_unlock.png"/>
                    </contents>
                  </CALayer>
            """)
            overrides.append(contentsOf: [
                StateOverride(targetId: fid, layerName: fname, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: fid, layerName: fname, keyPath: "transform.scale.xy", sleepVal: 1.16, lockedVal: 1.14, unlockVal: 1.0, isInteger: false),
            ])
        }

        if hasLockCutout {
            let fid = "\(idPrefix)float_lock"
            let fname = "\(namePrefix)Floating Lock Subject"
            let cy = canvas.centerYDouble
            let cyIsInt = abs(cy - cy.rounded()) < 0.001
            sublayers.append("""
                  <CALayer id="\(fid)" name="\(fname)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="2" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents>
                      <CGImage src="assets/\(aPrefix)cutout_lock.png"/>
                    </contents>
                  </CALayer>
            """)
            let unlockY: Double = (preset == .curtainRise) ? (Double(canvas.height) * 1.137).rounded() : cy
            let unlockScale: Double = (preset == .burstZoom) ? 0.84 : 1.06
            overrides.append(contentsOf: [
                StateOverride(targetId: fid, layerName: fname, keyPath: "opacity", sleepVal: 0.72, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: fid, layerName: fname, keyPath: "position.y", sleepVal: cy, lockedVal: cy, unlockVal: unlockY, isInteger: cyIsInt),
                StateOverride(targetId: fid, layerName: fname, keyPath: "transform.scale.xy", sleepVal: 0.98, lockedVal: 1.0, unlockVal: unlockScale, isInteger: false),
            ])
        }

        return LayerBuildResult(sublayersXML: sublayers.joined(separator: "\n"), overrides: overrides)
    }

    private static func discreteContentsAnimationXML(
        prefix: String,
        frameCount: Int,
        duration: Double,
        autoReverses: Bool
    ) -> String {
        var frameTags: [String] = []
        frameTags.reserveCapacity(frameCount)
        for i in 0..<frameCount {
            frameTags.append("              <CGImage src=\"assets/\(prefix)_\(i).jpg\"/>")
        }
        let framesJoined = frameTags.joined(separator: "\n")
        let durStr = String(format: "%.3f", max(0.2, duration))
        let revInt = autoReverses ? 1 : 0

        return """
                <contents><CGImage src="assets/\(prefix)_0.jpg"/></contents>
                <animations>
                  <animation type="CAKeyframeAnimation" calculationMode="discrete" fillMode="both" keyPath="contents" beginTime="1e-100" duration="\(durStr)" removedOnCompletion="0" repeatCount="inf" repeatDuration="0" speed="1" timeOffset="0" autoreverses="\(revInt)">
                    <values>
        \(framesJoined)
                    </values>
                  </animation>
                </animations>
        """
    }

    private static func morphMediaLayerXML(
        id: String,
        name: String,
        zPosition: Int,
        staticFilename: String,
        livePrefix: String,
        liveSequence: ExtractedVideoSequence?,
        autoReverses: Bool,
        canvas: CanvasMetrics = .standardPhone
    ) -> String {
        let bodyXML: String
        if let seq = liveSequence, !seq.frameJPEGs.isEmpty {
            bodyXML = discreteContentsAnimationXML(
                prefix: livePrefix,
                frameCount: seq.frameJPEGs.count,
                duration: seq.durationSeconds,
                autoReverses: autoReverses
            )
        } else {
            bodyXML = """
                <contents>
                  <CGImage src="assets/\(staticFilename)"/>
                </contents>
            """
        }

        return """
              <CALayer id="\(id)" name="\(name)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="\(zPosition)" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
        \(bodyXML)
              </CALayer>
        """
    }

    private static func buildAndEncodeVideoLayers(
        spec: VideoCompileSpec,
        assetsDir: URL,
        canvas: CanvasMetrics = .standardPhone,
        sequenceOverride: ExtractedVideoSequence? = nil
    ) throws -> LayerBuildResult {
        let seq = sequenceOverride ?? spec.sequence
        let aPrefix = canvas.assetPrefix
        let idPrefix = canvas.idPrefix
        let namePrefix = canvas.namePrefix

        for (idx, frameData) in seq.frameJPEGs.enumerated() {
            try frameData.write(to: assetsDir.appendingPathComponent("\(aPrefix)frame_\(idx).jpg"), options: .atomic)
        }

        let animBody = discreteContentsAnimationXML(
            prefix: "\(aPrefix)frame",
            frameCount: seq.frameJPEGs.count,
            duration: seq.durationSeconds,
            autoReverses: spec.loopStyle == .pingPong
        )

        let seqId = "\(idPrefix)video_seq_layer"
        let seqName = "\(namePrefix)Video Sequence Layer"
        var sublayers: [String] = []
        sublayers.append("""
              <CALayer id="\(seqId)" name="\(seqName)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
        \(animBody)
              </CALayer>
        """)

        var overrides: [StateOverride] = [
            StateOverride(targetId: seqId, layerName: seqName, keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: spec.unlockZoomScale, isInteger: false)
        ]

        if spec.dimInSleepMode {
            let dimId = "\(idPrefix)video_sleep_dim"
            let dimName = "\(namePrefix)Sleep Dimmer"
            sublayers.append("""
                  <CALayer id="\(dimId)" name="\(dimName)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
            """)
            overrides.append(StateOverride(targetId: dimId, layerName: dimName, keyPath: "opacity", sleepVal: 0.65, lockedVal: 0.0, unlockVal: 0.0, isInteger: false))
        }

        return LayerBuildResult(sublayersXML: sublayers.joined(separator: "\n"), overrides: overrides)
    }

    private static func buildAndEncodeForegroundFX(
        particlePreset: ParticlePreset,
        includeFlashPulse: Bool,
        assetsDir: URL,
        canvas: CanvasMetrics = .standardPhone,
        encodeAssets: Bool = true
    ) throws -> LayerBuildResult {
        if encodeAssets && particlePreset != .none {
            let spriteAssets = ParticleSpriteRenderer.assets(for: particlePreset)
            for asset in spriteAssets {
                try asset.data.write(to: assetsDir.appendingPathComponent(asset.filename), options: .atomic)
            }
        }

        guard particlePreset != .none || includeFlashPulse else {
            return LayerBuildResult(sublayersXML: "", overrides: [])
        }

        var sublayers: [String] = []
        var overrides: [StateOverride] = []

        if includeFlashPulse {
            let fid = "\(canvas.idPrefix)flash_veil"
            let fname = "\(canvas.namePrefix)Flash Veil"
            let veilW = Int((510.0 * canvas.scaleX).rounded())
            let veilH = Int((964.0 * canvas.scaleY).rounded())
            sublayers.append("""
                  <CALayer id="\(fid)" name="\(fname)" bounds="0 0 \(veilW) \(veilH)" position="\(canvas.centerPosString)" zPosition="1" opacity="0" backgroundColor="1 0.98 0.94" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
            """)
            overrides.append(StateOverride(targetId: fid, layerName: fname, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 0.06, isInteger: false))
        }

        if particlePreset != .none {
            let volumetric = buildVolumetricLightLayers(for: particlePreset, canvas: canvas)
            sublayers.append(contentsOf: volumetric.layersXML)
            overrides.append(contentsOf: volumetric.overrides)

            let emitters = buildEmitterLayers(for: particlePreset, canvas: canvas)
            sublayers.append(contentsOf: emitters.layersXML)
            for emitter in emitters.layerRefs {
                overrides.append(StateOverride(targetId: emitter.id, layerName: emitter.name, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 0.88, isInteger: false))
                overrides.append(StateOverride(targetId: emitter.id, layerName: emitter.name, keyPath: "birthRate", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false))
            }
        }

        return LayerBuildResult(sublayersXML: sublayers.joined(separator: "\n"), overrides: overrides)
    }

    private struct EmitterCellSpec {
        let id: String
        let spriteFilename: String
        let colorRGB: String
        let colorAlpha: String
        let birthRate: String
        let lifetime: String
        let velocity: String
        let velocityRange: String
        let emissionLong: String
        let emissionRange: String
        let scale: String
        let scaleRange: String
        let scaleSpeed: String
        let alphaRange: String
        let alphaSpeed: String
        let spin: String
        let spinRange: String
        let xAccel: String
        let yAccel: String
        let redRange: String
        let greenRange: String
        let blueRange: String
        let greenSpeed: String
        let blueSpeed: String

        init(
            id: String,
            spriteFilename: String,
            colorRGB: String = "1 1 1",
            colorAlpha: String = "0.94",
            birthRate: String,
            lifetime: String,
            velocity: String,
            velocityRange: String = "8",
            emissionLong: String,
            emissionRange: String,
            scale: String,
            scaleRange: String,
            scaleSpeed: String = "-0.01",
            alphaRange: String = "0.25",
            alphaSpeed: String = "-0.10",
            spin: String = "0",
            spinRange: String = "0",
            xAccel: String = "0",
            yAccel: String = "0",
            redRange: String = "0.04",
            greenRange: String = "0.04",
            blueRange: String = "0.04",
            greenSpeed: String = "0",
            blueSpeed: String = "0"
        ) {
            self.id = id
            self.spriteFilename = spriteFilename
            self.colorRGB = colorRGB
            self.colorAlpha = colorAlpha
            self.birthRate = birthRate
            self.lifetime = lifetime
            self.velocity = velocity
            self.velocityRange = velocityRange
            self.emissionLong = emissionLong
            self.emissionRange = emissionRange
            self.scale = scale
            self.scaleRange = scaleRange
            self.scaleSpeed = scaleSpeed
            self.alphaRange = alphaRange
            self.alphaSpeed = alphaSpeed
            self.spin = spin
            self.spinRange = spinRange
            self.xAccel = xAccel
            self.yAccel = yAccel
            self.redRange = redRange
            self.greenRange = greenRange
            self.blueRange = blueRange
            self.greenSpeed = greenSpeed
            self.blueSpeed = blueSpeed
        }
    }

    private struct EmitterLayerSpec {
        let id: String
        let name: String
        let zPos: Int
        let renderMode: String
        let emitterPosX: Int
        let emitterPosY: Int
        let emitterW: Int
        let emitterH: Int
        let cells: [EmitterCellSpec]
    }

    private static func buildVolumetricLightLayers(
        for preset: ParticlePreset,
        canvas: CanvasMetrics = .standardPhone
    ) -> (layersXML: [String], overrides: [StateOverride]) {
        let sx = canvas.scaleX
        let sy = canvas.scaleY
        let idP = canvas.idPrefix
        let nP = canvas.namePrefix

        switch preset {
        case .sunbeamRays:
            let s0Id = "\(idP)sunbeam_layer_0"
            let s0Name = "\(nP)Sunbeam Shaft A"
            let s1Id = "\(idP)sunbeam_layer_1"
            let s1Name = "\(nP)Sunbeam Shaft B"
            let s0W = Int((520.0 * sx).rounded())
            let s0H = Int((960.0 * sy).rounded())
            let s0X = Int((165.0 * sx).rounded())
            let s0Y = Int((480.0 * sy).rounded())
            let s0MinX = Int((145.0 * sx).rounded())
            let s0MaxX = Int((195.0 * sx).rounded())
            let s1W = Int((480.0 * sx).rounded())
            let s1H = Int((920.0 * sy).rounded())
            let s1X = Int((235.0 * sx).rounded())
            let s1Y = Int((450.0 * sy).rounded())

            let layer0 = """
                  <CALayer id="\(s0Id)" name="\(s0Name)" bounds="0 0 \(s0W) \(s0H)" position="\(s0X) \(s0Y)" zPosition="2" opacity="0.78" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents type="CGImage" src="assets/particle_sunbeam_veil.png"/>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                    <animations>
                      <animation type="CAKeyframeAnimation" keyPath="opacity" autoreverses="1" beginTime="1e-100" duration="5.6" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="0.42"/>
                          <real value="0.85"/>
                        </values>
                      </animation>
                      <animation type="CAKeyframeAnimation" keyPath="position.x" autoreverses="1" beginTime="1e-100" duration="7.8" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="\(s0MinX)"/>
                          <real value="\(s0MaxX)"/>
                        </values>
                      </animation>
                    </animations>
                  </CALayer>
            """
            let layer1 = """
                  <CALayer id="\(s1Id)" name="\(s1Name)" bounds="0 0 \(s1W) \(s1H)" position="\(s1X) \(s1Y)" zPosition="3" opacity="0.55" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents type="CGImage" src="assets/particle_sunbeam_veil.png"/>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                    <animations>
                      <animation type="CAKeyframeAnimation" keyPath="opacity" autoreverses="1" beginTime="1e-100" duration="7.2" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="0.25"/>
                          <real value="0.62"/>
                        </values>
                      </animation>
                      <animation type="CAKeyframeAnimation" keyPath="transform.rotation.z" autoreverses="1" beginTime="1e-100" duration="9.4" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="-0.06"/>
                          <real value="0.05"/>
                        </values>
                      </animation>
                    </animations>
                  </CALayer>
            """
            return (
                [layer0, layer1],
                [
                    StateOverride(targetId: s0Id, layerName: s0Name, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.78, unlockVal: 0.65, isInteger: false),
                    StateOverride(targetId: s0Id, layerName: s0Name, keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                    StateOverride(targetId: s1Id, layerName: s1Name, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.55, unlockVal: 0.45, isInteger: false),
                    StateOverride(targetId: s1Id, layerName: s1Name, keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false)
                ]
            )

        case .auroraRibbon:
            let a0Id = "\(idP)aurora_layer_0"
            let a0Name = "\(nP)Aurora Silk Veil A"
            let a1Id = "\(idP)aurora_layer_1"
            let a1Name = "\(nP)Aurora Silk Veil B"
            let a0W = Int((560.0 * sx).rounded())
            let a0H = Int((620.0 * sy).rounded())
            let a0X = Int((195.0 * sx).rounded())
            let a0Y = Int((570.0 * sy).rounded())
            let a1W = Int((540.0 * sx).rounded())
            let a1H = Int((560.0 * sy).rounded())
            let a1X = Int((195.0 * sx).rounded())
            let a1Y = Int((390.0 * sy).rounded())
            let minX = Int((145.0 * sx).rounded())
            let maxX = Int((245.0 * sx).rounded())

            let layer0 = """
                  <CALayer id="\(a0Id)" name="\(a0Name)" bounds="0 0 \(a0W) \(a0H)" position="\(a0X) \(a0Y)" zPosition="2" opacity="0.80" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents type="CGImage" src="assets/particle_aurora_silk_a.png"/>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                    <animations>
                      <animation type="CAKeyframeAnimation" keyPath="position.x" autoreverses="1" beginTime="1e-100" duration="6.8" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="\(minX)"/>
                          <real value="\(maxX)"/>
                        </values>
                      </animation>
                      <animation type="CAKeyframeAnimation" keyPath="transform.scale.x" autoreverses="1" beginTime="1e-100" duration="5.4" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="0.96"/>
                          <real value="1.14"/>
                        </values>
                      </animation>
                      <animation type="CAKeyframeAnimation" keyPath="opacity" autoreverses="1" beginTime="1e-100" duration="4.9" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="0.48"/>
                          <real value="0.86"/>
                        </values>
                      </animation>
                    </animations>
                  </CALayer>
            """
            let layer1 = """
                  <CALayer id="\(a1Id)" name="\(a1Name)" bounds="0 0 \(a1W) \(a1H)" position="\(a1X) \(a1Y)" zPosition="3" opacity="0.58" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents type="CGImage" src="assets/particle_aurora_silk_a.png"/>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                    <animations>
                      <animation type="CAKeyframeAnimation" keyPath="position.x" autoreverses="1" beginTime="1e-100" duration="8.4" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="\(maxX)"/>
                          <real value="\(minX)"/>
                        </values>
                      </animation>
                      <animation type="CAKeyframeAnimation" keyPath="transform.rotation.z" autoreverses="1" beginTime="1e-100" duration="9.2" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="-0.08"/>
                          <real value="0.08"/>
                        </values>
                      </animation>
                      <animation type="CAKeyframeAnimation" keyPath="opacity" autoreverses="1" beginTime="1e-100" duration="6.3" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="0.32"/>
                          <real value="0.68"/>
                        </values>
                      </animation>
                    </animations>
                  </CALayer>
            """
            return (
                [layer0, layer1],
                [
                    StateOverride(targetId: a0Id, layerName: a0Name, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.80, unlockVal: 0.68, isInteger: false),
                    StateOverride(targetId: a0Id, layerName: a0Name, keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                    StateOverride(targetId: a1Id, layerName: a1Name, keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.58, unlockVal: 0.48, isInteger: false),
                    StateOverride(targetId: a1Id, layerName: a1Name, keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false)
                ]
            )

        default:
            return ([], [])
        }
    }

    private static func buildEmitterLayers(
        for preset: ParticlePreset,
        canvas: CanvasMetrics = .standardPhone
    ) -> (layersXML: [String], layerRefs: [(id: String, name: String)]) {
        let specs: [EmitterLayerSpec]
        switch preset {
        case .none:
            specs = []

        case .meteorShower:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Shooting Meteors",
                    zPos: 5,
                    renderMode: "additive",
                    emitterPosX: 260,
                    emitterPosY: 760,
                    emitterW: 420,
                    emitterH: 260,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_meteor_streak",
                            spriteFilename: "particle_meteor_streak.png",
                            colorRGB: "1 1 1",
                            colorAlpha: "0.96",
                            birthRate: "1.6",
                            lifetime: "2.2",
                            velocity: "320",
                            velocityRange: "90",
                            emissionLong: "-2.3562",
                            emissionRange: "0.035",
                            scale: "0.72",
                            scaleRange: "0.28",
                            scaleSpeed: "-0.04",
                            alphaRange: "0.18",
                            alphaSpeed: "-0.38",
                            spin: "0",
                            spinRange: "0",
                            xAccel: "-20",
                            yAccel: "-20"
                        )
                    ]
                ),
                EmitterLayerSpec(
                    id: "camlo_emitter_1",
                    name: "Sky Cross Stars",
                    zPos: 6,
                    renderMode: "additive",
                    emitterPosX: 195,
                    emitterPosY: 560,
                    emitterW: 390,
                    emitterH: 520,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_meteor_star",
                            spriteFilename: "particle_meteor_star.png",
                            colorRGB: "0.86 0.94 1",
                            colorAlpha: "0.90",
                            birthRate: "4.5",
                            lifetime: "4.2",
                            velocity: "2",
                            velocityRange: "2",
                            emissionLong: "0",
                            emissionRange: "6.283",
                            scale: "0.34",
                            scaleRange: "0.18",
                            scaleSpeed: "-0.02",
                            alphaRange: "0.30",
                            alphaSpeed: "-0.22",
                            spin: "0",
                            spinRange: "0"
                        )
                    ]
                )
            ]

        case .sunbeamRays:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Sunbeam Prism Motes",
                    zPos: 5,
                    renderMode: "additive",
                    emitterPosX: 175,
                    emitterPosY: 520,
                    emitterW: 340,
                    emitterH: 560,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_sunbeam_mote",
                            spriteFilename: "particle_sunbeam_mote.png",
                            colorRGB: "1 0.94 0.76",
                            colorAlpha: "0.88",
                            birthRate: "5.5",
                            lifetime: "6.5",
                            velocity: "12",
                            velocityRange: "6",
                            emissionLong: "-0.85",
                            emissionRange: "0.70",
                            scale: "0.42",
                            scaleRange: "0.22",
                            scaleSpeed: "-0.01",
                            alphaRange: "0.30",
                            alphaSpeed: "-0.12",
                            spin: "0.15",
                            spinRange: "0.25",
                            xAccel: "2",
                            yAccel: "-2"
                        )
                    ]
                )
            ]

        case .auroraRibbon:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Aurora Prism Flares",
                    zPos: 5,
                    renderMode: "additive",
                    emitterPosX: 195,
                    emitterPosY: 480,
                    emitterW: 390,
                    emitterH: 560,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_aurora_flare",
                            spriteFilename: "particle_aurora_flare.png",
                            colorRGB: "0.82 0.96 1",
                            colorAlpha: "0.88",
                            birthRate: "4.8",
                            lifetime: "5.0",
                            velocity: "10",
                            velocityRange: "5",
                            emissionLong: "0.20",
                            emissionRange: "3.14",
                            scale: "0.38",
                            scaleRange: "0.20",
                            scaleSpeed: "-0.015",
                            alphaRange: "0.32",
                            alphaSpeed: "-0.16",
                            spin: "0",
                            spinRange: "0.08",
                            redRange: "0.15",
                            greenRange: "0.12",
                            blueRange: "0.15"
                        )
                    ]
                )
            ]

        case .sakura:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Sakura Petals",
                    zPos: 5,
                    renderMode: "unordered",
                    emitterPosX: 230,
                    emitterPosY: 870,
                    emitterW: 440,
                    emitterH: 80,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_sakura_a",
                            spriteFilename: "particle_sakura_a.png",
                            colorRGB: "1 0.94 0.96",
                            colorAlpha: "0.94",
                            birthRate: "5.2",
                            lifetime: "9.5",
                            velocity: "48",
                            velocityRange: "18",
                            emissionLong: "-1.82",
                            emissionRange: "0.45",
                            scale: "0.34",
                            scaleRange: "0.14",
                            alphaRange: "0.16",
                            alphaSpeed: "-0.04",
                            spin: "0.90",
                            spinRange: "1.40",
                            xAccel: "-8",
                            yAccel: "-10"
                        ),
                        EmitterCellSpec(
                            id: "camlo_cell_sakura_b",
                            spriteFilename: "particle_sakura_b.png",
                            colorRGB: "1 0.90 0.94",
                            colorAlpha: "0.94",
                            birthRate: "4.5",
                            lifetime: "9.0",
                            velocity: "56",
                            velocityRange: "20",
                            emissionLong: "-1.75",
                            emissionRange: "0.52",
                            scale: "0.30",
                            scaleRange: "0.12",
                            alphaRange: "0.18",
                            alphaSpeed: "-0.05",
                            spin: "1.50",
                            spinRange: "1.80",
                            xAccel: "-12",
                            yAccel: "-13"
                        ),
                        EmitterCellSpec(
                            id: "camlo_cell_sakura_bokeh",
                            spriteFilename: "particle_sakura_bokeh.png",
                            colorRGB: "1 0.88 0.93",
                            colorAlpha: "0.78",
                            birthRate: "1.1",
                            lifetime: "7.5",
                            velocity: "72",
                            velocityRange: "16",
                            emissionLong: "-1.80",
                            emissionRange: "0.35",
                            scale: "0.68",
                            scaleRange: "0.22",
                            alphaRange: "0.20",
                            alphaSpeed: "-0.05",
                            spin: "0.40",
                            spinRange: "0.60",
                            xAccel: "-14",
                            yAccel: "-14"
                        )
                    ]
                )
            ]

        case .snowfall:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Crystal Snowfall",
                    zPos: 5,
                    renderMode: "unordered",
                    emitterPosX: 195,
                    emitterPosY: 870,
                    emitterW: 430,
                    emitterH: 70,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_snow_a",
                            spriteFilename: "particle_snow_crystal_a.png",
                            colorRGB: "0.96 0.99 1",
                            colorAlpha: "0.94",
                            birthRate: "6.5",
                            lifetime: "10.5",
                            velocity: "38",
                            velocityRange: "14",
                            emissionLong: "-1.42",
                            emissionRange: "0.38",
                            scale: "0.36",
                            scaleRange: "0.16",
                            alphaRange: "0.20",
                            alphaSpeed: "-0.04",
                            spin: "0.45",
                            spinRange: "0.70",
                            xAccel: "6",
                            yAccel: "-6"
                        ),
                        EmitterCellSpec(
                            id: "camlo_cell_snow_b",
                            spriteFilename: "particle_snow_crystal_b.png",
                            colorRGB: "0.92 0.97 1",
                            colorAlpha: "0.90",
                            birthRate: "7.5",
                            lifetime: "11.5",
                            velocity: "26",
                            velocityRange: "10",
                            emissionLong: "-1.48",
                            emissionRange: "0.45",
                            scale: "0.24",
                            scaleRange: "0.10",
                            alphaRange: "0.22",
                            alphaSpeed: "-0.04",
                            spin: "0.30",
                            spinRange: "0.50",
                            xAccel: "4",
                            yAccel: "-4"
                        )
                    ]
                )
            ]

        case .starlight:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Anamorphic Cross Flares",
                    zPos: 5,
                    renderMode: "additive",
                    emitterPosX: 195,
                    emitterPosY: 460,
                    emitterW: 380,
                    emitterH: 760,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_star_cross",
                            spriteFilename: "particle_star_cross.png",
                            colorRGB: "0.90 0.95 1",
                            colorAlpha: "0.92",
                            birthRate: "5.5",
                            lifetime: "4.6",
                            velocity: "4",
                            velocityRange: "3",
                            emissionLong: "1.5708",
                            emissionRange: "3.1416",
                            scale: "0.44",
                            scaleRange: "0.24",
                            scaleSpeed: "-0.02",
                            alphaRange: "0.35",
                            alphaSpeed: "-0.18",
                            spin: "0",
                            spinRange: "0"
                        ),
                        EmitterCellSpec(
                            id: "camlo_cell_star_octa",
                            spriteFilename: "particle_star_octa.png",
                            colorRGB: "1 0.96 0.88",
                            colorAlpha: "0.90",
                            birthRate: "4.5",
                            lifetime: "5.2",
                            velocity: "6",
                            velocityRange: "4",
                            emissionLong: "1.5708",
                            emissionRange: "3.1416",
                            scale: "0.32",
                            scaleRange: "0.16",
                            scaleSpeed: "-0.015",
                            alphaRange: "0.30",
                            alphaSpeed: "-0.15",
                            spin: "0",
                            spinRange: "0"
                        )
                    ]
                )
            ]

        case .embers:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Fire Spark Lances",
                    zPos: 5,
                    renderMode: "additive",
                    emitterPosX: 195,
                    emitterPosY: -15,
                    emitterW: 400,
                    emitterH: 70,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_ember_streak",
                            spriteFilename: "particle_ember_streak.png",
                            colorRGB: "1 0.86 0.62",
                            colorAlpha: "0.96",
                            birthRate: "9.0",
                            lifetime: "4.6",
                            velocity: "92",
                            velocityRange: "34",
                            emissionLong: "1.45",
                            emissionRange: "0.14",
                            scale: "0.38",
                            scaleRange: "0.18",
                            alphaRange: "0.22",
                            alphaSpeed: "-0.18",
                            spin: "0",
                            spinRange: "0",
                            xAccel: "10",
                            yAccel: "22",
                            greenSpeed: "-0.12",
                            blueSpeed: "-0.16"
                        ),
                        EmitterCellSpec(
                            id: "camlo_cell_ember_shard",
                            spriteFilename: "particle_ember_shard.png",
                            colorRGB: "1 0.62 0.24",
                            colorAlpha: "0.92",
                            birthRate: "8.0",
                            lifetime: "5.8",
                            velocity: "58",
                            velocityRange: "22",
                            emissionLong: "1.48",
                            emissionRange: "0.42",
                            scale: "0.26",
                            scaleRange: "0.12",
                            alphaRange: "0.25",
                            alphaSpeed: "-0.14",
                            spin: "1.80",
                            spinRange: "2.40",
                            xAccel: "14",
                            yAccel: "14",
                            greenSpeed: "-0.09"
                        )
                    ]
                )
            ]

        case .fireflies:
            specs = [
                EmitterLayerSpec(
                    id: "camlo_emitter_0",
                    name: "Bioluminescent Fireflies",
                    zPos: 5,
                    renderMode: "additive",
                    emitterPosX: 195,
                    emitterPosY: 360,
                    emitterW: 380,
                    emitterH: 680,
                    cells: [
                        EmitterCellSpec(
                            id: "camlo_cell_firefly_wisp",
                            spriteFilename: "particle_firefly_wisp.png",
                            colorRGB: "0.92 1 0.56",
                            colorAlpha: "0.94",
                            birthRate: "5.5",
                            lifetime: "6.8",
                            velocity: "18",
                            velocityRange: "8",
                            emissionLong: "1.25",
                            emissionRange: "1.20",
                            scale: "0.38",
                            scaleRange: "0.16",
                            alphaRange: "0.30",
                            alphaSpeed: "-0.12",
                            spin: "0.25",
                            spinRange: "0.50",
                            yAccel: "4"
                        ),
                        EmitterCellSpec(
                            id: "camlo_cell_firefly_hex",
                            spriteFilename: "particle_firefly_hex.png",
                            colorRGB: "1 0.90 0.52",
                            colorAlpha: "0.65",
                            birthRate: "2.4",
                            lifetime: "8.0",
                            velocity: "10",
                            velocityRange: "5",
                            emissionLong: "1.57",
                            emissionRange: "2.40",
                            scale: "0.58",
                            scaleRange: "0.24",
                            alphaRange: "0.25",
                            alphaSpeed: "-0.08",
                            spin: "0.10",
                            spinRange: "0.20",
                            yAccel: "2"
                        )
                    ]
                )
            ]
        }

        var xmls: [String] = []
        var refs: [(id: String, name: String)] = []
        for layer in specs {
            let scaledID = "\(canvas.idPrefix)\(layer.id)"
            let scaledName = "\(canvas.namePrefix)\(layer.name)"
            let ePosX = Int((Double(layer.emitterPosX) * canvas.scaleX).rounded())
            let ePosY = Int((Double(layer.emitterPosY) * canvas.scaleY).rounded())
            let eW = Int((Double(layer.emitterW) * canvas.scaleX).rounded())
            let eH = Int((Double(layer.emitterH) * canvas.scaleY).rounded())
            refs.append((id: scaledID, name: scaledName))
            let cellsXML = layer.cells.map { c in
                """
                          <CAEmitterCell id="\(canvas.idPrefix)\(c.id)" name="\(canvas.idPrefix)\(c.id)" contentsScale="2" birthRate="\(c.birthRate)" lifetime="\(c.lifetime)" velocity="\(c.velocity)" velocityRange="\(c.velocityRange)" emissionRange="\(c.emissionRange)" emissionLongitude="\(c.emissionLong)" emissionLatitude="0" scale="\(c.scale)" scaleRange="\(c.scaleRange)" scaleSpeed="\(c.scaleSpeed)" alphaRange="\(c.alphaRange)" alphaSpeed="\(c.alphaSpeed)" spin="\(c.spin)" spinRange="\(c.spinRange)" xAcceleration="\(c.xAccel)" yAcceleration="\(c.yAccel)" redRange="\(c.redRange)" greenRange="\(c.greenRange)" blueRange="\(c.blueRange)" redSpeed="0" greenSpeed="\(c.greenSpeed)" blueSpeed="\(c.blueSpeed)">
                            <color value="\(c.colorRGB)" opacity="\(c.colorAlpha)"/>
                            <contents>
                              <CGImage src="assets/\(c.spriteFilename)"/>
                            </contents>
                          </CAEmitterCell>
                """
            }.joined(separator: "\n")

            xmls.append("""
                  <CAEmitterLayer id="\(scaledID)" name="\(scaledName)" bounds="0 0 \(canvas.width) \(canvas.height)" position="\(canvas.centerPosString)" zPosition="\(layer.zPos)" emitterPosition="\(ePosX) \(ePosY)" emitterSize="\(eW) \(eH)" emitterShape="rectangle" emitterMode="volume" renderMode="\(layer.renderMode)" birthRate="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <emitterCells>
            \(cellsXML)
                    </emitterCells>
                  </CAEmitterLayer>
            """)
        }
        return (xmls, refs)
    }

    private static func buildEmptyCAML(opaqueBlackRoot: Bool) -> String {
        wrapRootCAML(opaqueBlackBackground: opaqueBlackRoot, sublayersXML: "", overrides: [], duration: 0.7, bounce: 0.3)
    }

    // MARK: - Symmetric 3-State & Spring Transition Serializer

    private static func statesAndTransitionsXML(
        overrides: [StateOverride],
        duration: Double,
        bounce: Double
    ) -> String {
        let clampedDur = max(0.25, min(duration, 2.0))
        let clampedBounce = max(0.0, min(bounce, 1.0))

        let mass = 1.0
        let stiffness = (260.0 / max(0.35, clampedDur)).rounded()
        let criticalDamping = 2.0 * sqrt(stiffness * mass)
        let dampingRatio = 1.02 - (clampedBounce * 0.48)
        let damping = max(12.0, (criticalDamping * dampingRatio).rounded())
        let durAttr = String(format: "%.2f", clampedDur)

        func formatStateElements(for stage: LockScreenStage) -> String {
            guard !overrides.isEmpty else { return "        <elements/>" }
            var lines: [String] = ["        <elements>"]
            for ov in overrides {
                let raw: Double
                switch stage {
                case .sleep: raw = ov.sleepVal
                case .locked: raw = ov.lockedVal
                case .unlock: raw = ov.unlockVal
                }
                let typeStr = ov.isInteger ? "integer" : "real"
                let valStr = ov.isInteger ? String(Int(raw.rounded())) : String(format: "%.4f", raw)
                lines.append("""
                          <LKStateSetValue targetId="\(ov.targetId)" keyPath="\(ov.keyPath)">
                            <value type="\(typeStr)" value="\(valStr)"/>
                          </LKStateSetValue>
                """)
            }
            lines.append("        </elements>")
            return lines.joined(separator: "\n")
        }

        func formatTransitionElements() -> String {
            guard !overrides.isEmpty else { return "        <elements/>" }
            var lines: [String] = ["        <elements>"]
            for ov in overrides {
                lines.append("""
                          <LKStateTransitionElement targetId="\(ov.targetId)" key="\(ov.keyPath)">
                            <animation type="CASpringAnimation" damping="\(Int(damping))" mass="1" stiffness="\(Int(stiffness))" velocity="0" duration="\(durAttr)" fillMode="backwards" keyPath="\(ov.keyPath)" mica_autorecalculatesDuration="1"/>
                          </LKStateTransitionElement>
                """)
            }
            lines.append("        </elements>")
            return lines.joined(separator: "\n")
        }

        let lockedEls = formatStateElements(for: .locked)
        let unlockEls = formatStateElements(for: .unlock)
        let sleepEls = formatStateElements(for: .sleep)
        let transEls = formatTransitionElements()

        return """
            <modules/>
            <states>
              <LKState name="Locked">
        \(lockedEls)
              </LKState>
              <LKState name="Unlock">
        \(unlockEls)
              </LKState>
              <LKState name="Sleep">
        \(sleepEls)
              </LKState>
            </states>
            <stateTransitions>
              <LKStateTransition fromState="*" toState="Unlock">
        \(transEls)
              </LKStateTransition>
              <LKStateTransition fromState="Unlock" toState="*">
        \(transEls)
              </LKStateTransition>
              <LKStateTransition fromState="*" toState="Locked">
        \(transEls)
              </LKStateTransition>
              <LKStateTransition fromState="Locked" toState="*">
        \(transEls)
              </LKStateTransition>
              <LKStateTransition fromState="*" toState="Sleep">
        \(transEls)
              </LKStateTransition>
              <LKStateTransition fromState="Sleep" toState="*">
        \(transEls)
              </LKStateTransition>
            </stateTransitions>
        """
    }

    private static func wrapRootCAML(
        opaqueBlackBackground: Bool,
        sublayersXML: String,
        overrides: [StateOverride],
        duration: Double,
        bounce: Double
    ) -> String {
        let bgAttr = opaqueBlackBackground ? " backgroundColor=\"0 0 0\"" : ""
        let innerSublayers = sublayersXML.isEmpty ? "" : "\n      <sublayers>\n\(sublayersXML)\n      </sublayers>"
        let statesXML = statesAndTransitionsXML(overrides: overrides, duration: duration, bounce: bounce)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!-- Generated by Camlo · 开幕 (Zero-Threshold CAML Wallpaper Studio) -->
        <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
          <CALayer id="__capRootLayer__" name="CAPlayground Root Layer" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" geometryFlipped="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
            <sublayers>
              <CALayer id="camlo_root" name="Root Layer" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" geometryFlipped="0" opacity="1"\(bgAttr) allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(innerSublayers)
              </CALayer>
            </sublayers>
        \(statesXML)
          </CALayer>
        </caml>
        """
    }

    private static func parallaxGroupXML(
        axis: String,
        keyPath: String,
        layerName: String,
        minVal: Int,
        maxVal: Int,
        title: String,
        view: String
    ) -> String {
        """
                <NSDictionary>
                  <axis type="string" value="\(axis)"/>
                  <image type="string" value="null"/>
                  <keyPath type="string" value="\(keyPath)"/>
                  <layerName type="string" value="\(layerName)"/>
                  <mapMaxTo type="integer" value="\(maxVal)"/>
                  <mapMinTo type="integer" value="\(minVal)"/>
                  <title type="string" value="\(title)"/>
                  <view type="string" value="\(view)"/>
                </NSDictionary>
        """
    }

    private static func singlePropertyGroupXML(
        keyPath: String,
        layerName: String,
        sleepVal: Double,
        lockVal: Double,
        homeVal: Double,
        view: String
    ) -> String {
        let homeStr = String(format: "%.4f", homeVal)
        let lockStr = String(format: "%.4f", lockVal)
        let sleepStr = String(format: "%.4f", sleepVal)
        return """
                <NSDictionary>
                  <image type="null"/>
                  <keyPath type="string" value="\(keyPath)"/>
                  <layerName type="string" value="\(layerName)"/>
                  <v_home type="real" value="\(homeStr)"/>
                  <v_lock type="real" value="\(lockStr)"/>
                  <v_sleep type="real" value="\(sleepStr)"/>
                  <view type="string" value="\(view)"/>
                </NSDictionary>
        """
    }

    private static func propertyGroupEntriesXML(for ov: StateOverride, view: String) -> [String] {
        if ov.keyPath == "transform.scale.xy" {
            let s = max(0.0, ov.sleepVal)
            let l = max(0.0, ov.lockedVal)
            let h = max(0.0, ov.unlockVal)
            return [
                singlePropertyGroupXML(keyPath: "transform.scale.x", layerName: ov.layerName, sleepVal: s, lockVal: l, homeVal: h, view: view),
                singlePropertyGroupXML(keyPath: "transform.scale.y", layerName: ov.layerName, sleepVal: s, lockVal: l, homeVal: h, view: view)
            ]
        }
        return [
            singlePropertyGroupXML(keyPath: ov.keyPath, layerName: ov.layerName, sleepVal: ov.sleepVal, lockVal: ov.lockedVal, homeVal: ov.unlockVal, view: view)
        ]
    }

    private static func wrapParameterizedRootCAML(
        bgSublayersXML: String,
        fgSublayersXML: String,
        fxSublayersXML: String,
        fgOverscanScale: Double,
        bgOverrides: [StateOverride],
        floatingOverrides: [StateOverride],
        duration: Double,
        bounce: Double,
        gyroIntensity: Double
    ) -> String {
        let clampedGyro = max(0.20, min(gyroIntensity, 1.0))
        let bgShiftX = Int((26.0 * clampedGyro).rounded())
        let bgShiftY = Int((34.0 * clampedGyro).rounded())
        let fgShiftX = Int((34.0 * clampedGyro).rounded())
        let fgShiftY = Int((44.0 * clampedGyro).rounded())
        let fxShiftX = Int((46.0 * clampedGyro).rounded())
        let fxShiftY = Int((58.0 * clampedGyro).rounded())

        let bgOverscan = String(format: "%.4f", 1.0 + 0.16 * clampedGyro)
        let fgOverscanStr = String(format: "%.4f", max(1.0, fgOverscanScale))
        let bgInner = bgSublayersXML.isEmpty ? "" : "\n                <sublayers>\n\(bgSublayersXML)\n                </sublayers>"
        let fgInner = fgSublayersXML.isEmpty ? "" : "\n                <sublayers>\n\(fgSublayersXML)\n                </sublayers>"
        let fxInner = fxSublayersXML.isEmpty ? "" : "\n              <sublayers>\n\(fxSublayersXML)\n              </sublayers>"

        let parallaxXML = [
            parallaxGroupXML(axis: "x", keyPath: "transform.translation.x", layerName: "Camlo_BG_Parallax", minVal: -bgShiftX, maxVal: bgShiftX, title: "Camlo BG X", view: "Background"),
            parallaxGroupXML(axis: "y", keyPath: "transform.translation.y", layerName: "Camlo_BG_Parallax", minVal: -bgShiftY, maxVal: bgShiftY, title: "Camlo BG Y", view: "Background"),
            parallaxGroupXML(axis: "x", keyPath: "transform.translation.x", layerName: "Camlo_FG_Parallax", minVal: fgShiftX, maxVal: -fgShiftX, title: "Camlo FG X", view: "Floating"),
            parallaxGroupXML(axis: "y", keyPath: "transform.translation.y", layerName: "Camlo_FG_Parallax", minVal: fgShiftY, maxVal: -fgShiftY, title: "Camlo FG Y", view: "Floating"),
            parallaxGroupXML(axis: "x", keyPath: "transform.translation.x", layerName: "Camlo_FX_Parallax", minVal: fxShiftX, maxVal: -fxShiftX, title: "Camlo FX X", view: "Floating"),
            parallaxGroupXML(axis: "y", keyPath: "transform.translation.y", layerName: "Camlo_FX_Parallax", minVal: fxShiftY, maxVal: -fxShiftY, title: "Camlo FX Y", view: "Floating")
        ].joined(separator: "\n")

        let propertyEntries = bgOverrides.flatMap { propertyGroupEntriesXML(for: $0, view: "Background") }
            + floatingOverrides.flatMap { propertyGroupEntriesXML(for: $0, view: "Floating") }
        let propertyGroupsXML: String
        if propertyEntries.isEmpty {
            propertyGroupsXML = "      <wallpaperPropertyGroups type=\"NSArray\"/>"
        } else {
            propertyGroupsXML = """
                  <wallpaperPropertyGroups type="NSArray">
            \(propertyEntries.joined(separator: "\n"))
                  </wallpaperPropertyGroups>
            """
        }

        let statesXML = statesAndTransitionsXML(overrides: bgOverrides + floatingOverrides, duration: duration, bounce: bounce)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!-- Generated by Camlo · 开幕 (ParameterizedCA 3D Gyroscope Engine) -->
        <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
          <CALayer id="__capRootLayer__" name="Root Layer" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" geometryFlipped="0" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
            <style>
              <wallpaperBackgroundAssetNames type="NSArray"/>
              <wallpaperFloatingAssetNames type="NSArray"/>
              <wallpaperParallaxGroups type="NSArray">
        \(parallaxXML)
              </wallpaperParallaxGroups>
        \(propertyGroupsXML)
            </style>
            <sublayers>
              <CALayer id="background" name="BACKGROUND" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" geometryFlipped="0" masksToBounds="1" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="camlo_bg_parallax" name="Camlo_BG_Parallax" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <sublayers>
                      <CALayer id="camlo_bg_overscan" name="Camlo_BG_Overscan" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" opacity="1" transform="scale(\(bgOverscan), \(bgOverscan), 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(bgInner)
                      </CALayer>
                    </sublayers>
                  </CALayer>
                </sublayers>
              </CALayer>
              <CALayer id="floating" name="FLOATING" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="10" geometryFlipped="0" masksToBounds="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="camlo_fg_parallax" name="Camlo_FG_Parallax" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="10" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <sublayers>
                      <CALayer id="camlo_fg_overscan" name="Camlo_FG_Overscan" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" opacity="1" transform="scale(\(fgOverscanStr), \(fgOverscanStr), 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(fgInner)
                      </CALayer>
                    </sublayers>
                  </CALayer>
                  <CALayer id="camlo_fx_parallax" name="Camlo_FX_Parallax" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="20" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(fxInner)
                  </CALayer>
                </sublayers>
              </CALayer>
            </sublayers>
        \(statesXML)
          </CALayer>
        </caml>
        """
    }

    private static func dualParallaxEntries(for canvas: CanvasMetrics, gyroIntensity: Double) -> (bg: [String], fg: [String], bgOverscan: String) {
        let clampedGyro = max(0.20, min(gyroIntensity, 1.0))
        let bgShiftX = Int((26.0 * clampedGyro * canvas.scaleX).rounded())
        let bgShiftY = Int((34.0 * clampedGyro * canvas.scaleY).rounded())
        let fgShiftX = Int((34.0 * clampedGyro * canvas.scaleX).rounded())
        let fgShiftY = Int((44.0 * clampedGyro * canvas.scaleY).rounded())
        let fxShiftX = Int((46.0 * clampedGyro * canvas.scaleX).rounded())
        let fxShiftY = Int((58.0 * clampedGyro * canvas.scaleY).rounded())

        let bg = [
            parallaxGroupXML(axis: "x", keyPath: "transform.translation.x", layerName: canvas.bgParallaxName, minVal: -bgShiftX, maxVal: bgShiftX, title: "\(canvas.namePrefix)Camlo BG X", view: "Background"),
            parallaxGroupXML(axis: "y", keyPath: "transform.translation.y", layerName: canvas.bgParallaxName, minVal: -bgShiftY, maxVal: bgShiftY, title: "\(canvas.namePrefix)Camlo BG Y", view: "Background")
        ]
        let fg = [
            parallaxGroupXML(axis: "x", keyPath: "transform.translation.x", layerName: canvas.fgParallaxName, minVal: fgShiftX, maxVal: -fgShiftX, title: "\(canvas.namePrefix)Camlo FG X", view: "Floating"),
            parallaxGroupXML(axis: "y", keyPath: "transform.translation.y", layerName: canvas.fgParallaxName, minVal: fgShiftY, maxVal: -fgShiftY, title: "\(canvas.namePrefix)Camlo FG Y", view: "Floating"),
            parallaxGroupXML(axis: "x", keyPath: "transform.translation.x", layerName: canvas.fxParallaxName, minVal: fxShiftX, maxVal: -fxShiftX, title: "\(canvas.namePrefix)Camlo FX X", view: "Floating"),
            parallaxGroupXML(axis: "y", keyPath: "transform.translation.y", layerName: canvas.fxParallaxName, minVal: fxShiftY, maxVal: -fxShiftY, title: "\(canvas.namePrefix)Camlo FX Y", view: "Floating")
        ]
        return (bg, fg, String(format: "%.4f", 1.0 + 0.16 * clampedGyro))
    }

    private static func displayVariantDictionaryXML(
        screenName: String,
        backgroundLayerName: String,
        floatingLayerName: String,
        canvas: CanvasMetrics,
        bgParallaxEntries: [String],
        fgParallaxEntries: [String],
        bgPropertyEntries: [String],
        fgPropertyEntries: [String]
    ) -> String {
        let bgPropBlock = bgPropertyEntries.isEmpty
            ? "          <backgroundPropertyGroups type=\"NSArray\"/>"
            : "          <backgroundPropertyGroups type=\"NSArray\">\n\(bgPropertyEntries.joined(separator: "\n"))\n          </backgroundPropertyGroups>"
        let fgPropBlock = fgPropertyEntries.isEmpty
            ? "          <floatingPropertyGroups type=\"NSArray\"/>"
            : "          <floatingPropertyGroups type=\"NSArray\">\n\(fgPropertyEntries.joined(separator: "\n"))\n          </floatingPropertyGroups>"
        return """
                <NSDictionary>
                  <screenName type="string" value="\(screenName)"/>
                  <backgroundLayerName type="string" value="\(backgroundLayerName)"/>
                  <floatingLayerName type="string" value="\(floatingLayerName)"/>
                  <idealWidth type="integer" value="\(canvas.width)"/>
                  <idealHeight type="integer" value="\(canvas.height)"/>
                  <retinaMultiplier type="integer" value="1"/>
                  <backgroundParallaxGroups type="NSArray">
        \(bgParallaxEntries.joined(separator: "\n"))
                  </backgroundParallaxGroups>
                  <floatingParallaxGroups type="NSArray">
        \(fgParallaxEntries.joined(separator: "\n"))
                  </floatingParallaxGroups>
        \(bgPropBlock)
        \(fgPropBlock)
                </NSDictionary>
        """
    }

    private static func wrapDuoDualRootCAML(
        outer: CanvasMetrics,
        inner: CanvasMetrics,
        outerBgSublayersXML: String,
        outerFgSublayersXML: String,
        outerFxSublayersXML: String,
        innerBgSublayersXML: String,
        innerFgSublayersXML: String,
        innerFxSublayersXML: String,
        outerFgOverscanScale: Double,
        innerFgOverscanScale: Double,
        outerBgOverrides: [StateOverride],
        outerFloatingOverrides: [StateOverride],
        innerBgOverrides: [StateOverride],
        innerFloatingOverrides: [StateOverride],
        duration: Double,
        bounce: Double,
        gyroIntensity: Double
    ) -> String {
        let outerPx = dualParallaxEntries(for: outer, gyroIntensity: gyroIntensity)
        let innerPx = dualParallaxEntries(for: inner, gyroIntensity: gyroIntensity)

        let outerBgProps = outerBgOverrides.flatMap { propertyGroupEntriesXML(for: $0, view: "Background") }
        let outerFgProps = outerFloatingOverrides.flatMap { propertyGroupEntriesXML(for: $0, view: "Floating") }
        let innerBgProps = innerBgOverrides.flatMap { propertyGroupEntriesXML(for: $0, view: "Background") }
        let innerFgProps = innerFloatingOverrides.flatMap { propertyGroupEntriesXML(for: $0, view: "Floating") }

        let allOuterProps = outerBgProps + outerFgProps
        let topPropertyGroupsXML: String = allOuterProps.isEmpty
            ? "      <wallpaperPropertyGroups type=\"NSArray\"/>"
            : "      <wallpaperPropertyGroups type=\"NSArray\">\n\(allOuterProps.joined(separator: "\n"))\n      </wallpaperPropertyGroups>"

        let wallpapersXML = [
            displayVariantDictionaryXML(
                screenName: "Outer",
                backgroundLayerName: "BACKGROUND",
                floatingLayerName: "FLOATING",
                canvas: outer,
                bgParallaxEntries: outerPx.bg,
                fgParallaxEntries: outerPx.fg,
                bgPropertyEntries: outerBgProps,
                fgPropertyEntries: outerFgProps
            ),
            displayVariantDictionaryXML(
                screenName: "Inner",
                backgroundLayerName: "BACKGROUND_INNER",
                floatingLayerName: "FLOATING_INNER",
                canvas: inner,
                bgParallaxEntries: innerPx.bg,
                fgParallaxEntries: innerPx.fg,
                bgPropertyEntries: innerBgProps,
                fgPropertyEntries: innerFgProps
            )
        ].joined(separator: "\n")

        func planePairXML(
            canvas: CanvasMetrics,
            rootPositionString: String,
            bgID: String,
            bgName: String,
            fgID: String,
            fgName: String,
            bgZ: Int,
            fgZ: Int,
            bgOverscan: String,
            fgOverscan: Double,
            bgSublayers: String,
            fgSublayers: String,
            fxSublayers: String
        ) -> String {
            let fgScaleStr = String(format: "%.4f", max(1.0, fgOverscan))
            let bIn = bgSublayers.isEmpty ? "" : "\n                <sublayers>\n\(bgSublayers)\n                </sublayers>"
            let fIn = fgSublayers.isEmpty ? "" : "\n                <sublayers>\n\(fgSublayers)\n                </sublayers>"
            let xIn = fxSublayers.isEmpty ? "" : "\n              <sublayers>\n\(fxSublayers)\n              </sublayers>"
            let w = canvas.width
            let h = canvas.height
            let cPos = canvas.centerPosString
            return """
              <CALayer id="\(bgID)" name="\(bgName)" bounds="0 0 \(w) \(h)" position="\(rootPositionString)" zPosition="\(bgZ)" geometryFlipped="0" masksToBounds="1" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="\(canvas.idPrefix)camlo_bg_parallax" name="\(canvas.bgParallaxName)" bounds="0 0 \(w) \(h)" position="\(cPos)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <sublayers>
                      <CALayer id="\(canvas.idPrefix)camlo_bg_overscan" name="\(canvas.bgOverscanName)" bounds="0 0 \(w) \(h)" position="\(cPos)" zPosition="0" opacity="1" transform="scale(\(bgOverscan), \(bgOverscan), 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(bIn)
                      </CALayer>
                    </sublayers>
                  </CALayer>
                </sublayers>
              </CALayer>
              <CALayer id="\(fgID)" name="\(fgName)" bounds="0 0 \(w) \(h)" position="\(rootPositionString)" zPosition="\(fgZ)" geometryFlipped="0" masksToBounds="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CALayer id="\(canvas.idPrefix)camlo_fg_parallax" name="\(canvas.fgParallaxName)" bounds="0 0 \(w) \(h)" position="\(cPos)" zPosition="10" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <sublayers>
                      <CALayer id="\(canvas.idPrefix)camlo_fg_overscan" name="\(canvas.fgOverscanName)" bounds="0 0 \(w) \(h)" position="\(cPos)" zPosition="0" opacity="1" transform="scale(\(fgScaleStr), \(fgScaleStr), 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(fIn)
                      </CALayer>
                    </sublayers>
                  </CALayer>
                  <CALayer id="\(canvas.idPrefix)camlo_fx_parallax" name="\(canvas.fxParallaxName)" bounds="0 0 \(w) \(h)" position="\(cPos)" zPosition="20" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(xIn)
                  </CALayer>
                </sublayers>
              </CALayer>
            """
        }

        let innerPlanes = planePairXML(
            canvas: inner,
            rootPositionString: outer.centerPosString,
            bgID: "background_inner",
            bgName: "BACKGROUND_INNER",
            fgID: "floating_inner",
            fgName: "FLOATING_INNER",
            bgZ: -10,
            fgZ: -9,
            bgOverscan: innerPx.bgOverscan,
            fgOverscan: innerFgOverscanScale,
            bgSublayers: innerBgSublayersXML,
            fgSublayers: innerFgSublayersXML,
            fxSublayers: innerFxSublayersXML
        )
        let outerPlanes = planePairXML(
            canvas: outer,
            rootPositionString: outer.centerPosString,
            bgID: "background",
            bgName: "BACKGROUND",
            fgID: "floating",
            fgName: "FLOATING",
            bgZ: 0,
            fgZ: 10,
            bgOverscan: outerPx.bgOverscan,
            fgOverscan: outerFgOverscanScale,
            bgSublayers: outerBgSublayersXML,
            fgSublayers: outerFgSublayersXML,
            fxSublayers: outerFxSublayersXML
        )

        let statesXML = statesAndTransitionsXML(
            overrides: outerBgOverrides + outerFloatingOverrides + innerBgOverrides + innerFloatingOverrides,
            duration: duration,
            bounce: bounce
        )

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!-- Generated by Camlo · 开幕 (iPhone Duo Dual-Canvas ParameterizedCA Engine) -->
        <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
          <CALayer id="__capRootLayer__" name="Root Layer" bounds="0 0 \(outer.width) \(outer.height)" position="\(outer.centerPosString)" zPosition="0" geometryFlipped="0" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
            <style>
              <wallpaperBackgroundAssetNames type="NSArray"/>
              <wallpaperFloatingAssetNames type="NSArray"/>
              <wallpaperParallaxGroups type="NSArray">
        \((outerPx.bg + outerPx.fg).joined(separator: "\n"))
              </wallpaperParallaxGroups>
        \(topPropertyGroupsXML)
              <wallpapers type="NSArray">
        \(wallpapersXML)
              </wallpapers>
            </style>
            <sublayers>
        \(innerPlanes)
        \(outerPlanes)
            </sublayers>
        \(statesXML)
          </CALayer>
        </caml>
        """
    }

    private static func standardIndexXML(
        documentWidth: Int = canvasW,
        documentHeight: Int = canvasH
    ) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>assetManifest</key>
        \t<string>assetManifest.caml</string>
        \t<key>documentHeight</key>
        \t<real>\(documentHeight)</real>
        \t<key>documentResizesToView</key>
        \t<false/>
        \t<key>documentWidth</key>
        \t<real>\(documentWidth)</real>
        \t<key>geometryFlipped</key>
        \t<false/>
        \t<key>loopEnd</key>
        \t<real>+infinity</real>
        \t<key>loopStart</key>
        \t<real>0.0</real>
        \t<key>loopingEnabled</key>
        \t<true/>
        \t<key>rootDocument</key>
        \t<string>main.caml</string>
        \t<key>scalesToFitInPlayer</key>
        \t<true/>
        </dict>
        </plist>
        """
    }

    private static func standardAssetManifestXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>

        <caml xmlns="http://www.apple.com/CoreAnimation/1.0">
          <MicaAssetManifest>
            <modules type="NSArray"/>
          </MicaAssetManifest>
        </caml>
        """
    }
}
