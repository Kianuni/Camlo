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
}

enum CAMLCompiler {
    static let canvasW = 390
    static let canvasH = 844
    static let centerX = 195
    static let centerY = 422
    static let retinaSize = CGSize(width: 1170, height: 2532)

    private struct StateOverride {
        let targetId: String
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
                overrides: videoBuild.overrides + fxBuild.overrides,
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

    private static func prepareCABundle(at caURL: URL) throws {
        try FileManager.default.createDirectory(at: caURL.appendingPathComponent("assets", isDirectory: true), withIntermediateDirectories: true)
        try standardIndexXML().data(using: .utf8)?.write(to: caURL.appendingPathComponent("index.xml"), options: .atomic)
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
            overrides: bgBuild.overrides + flBuild.overrides + fxBuild.overrides,
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
        assetsDir: URL
    ) throws -> LayerBuildResult {
        let activeUnlockLive = (unlockLiveSequence?.frameJPEGs.isEmpty == false) ? unlockLiveSequence : nil
        let activeLockLive = (lockLiveSequence?.frameJPEGs.isEmpty == false) ? lockLiveSequence : nil

        if let lockSeq = activeLockLive {
            for (idx, frameData) in lockSeq.frameJPEGs.enumerated() {
                try frameData.write(to: assetsDir.appendingPathComponent("lock_frame_\(idx).jpg"), options: .atomic)
            }
        } else {
            try autoreleasepool {
                let lockScaled = lockImage.aspectFilled(to: retinaSize)
                guard let lockJPG = lockScaled.jpegData(compressionQuality: 0.88) else {
                    throw NSError(domain: "CamloCompiler", code: -10, userInfo: [NSLocalizedDescriptionKey: Bi("图片编码失败", "Failed to encode wallpaper images")])
                }
                try lockJPG.write(to: assetsDir.appendingPathComponent("locked.jpg"), options: .atomic)
            }
        }

        if let unlockSeq = activeUnlockLive {
            for (idx, frameData) in unlockSeq.frameJPEGs.enumerated() {
                try frameData.write(to: assetsDir.appendingPathComponent("unlock_frame_\(idx).jpg"), options: .atomic)
            }
        } else {
            try autoreleasepool {
                let unlockScaled = unlockImage.aspectFilled(to: retinaSize)
                guard let unlockJPG = unlockScaled.jpegData(compressionQuality: 0.88) else {
                    throw NSError(domain: "CamloCompiler", code: -10, userInfo: [NSLocalizedDescriptionKey: Bi("图片编码失败", "Failed to encode wallpaper images")])
                }
                try unlockJPG.write(to: assetsDir.appendingPathComponent("unlock.jpg"), options: .atomic)
            }
        }

        var hasCustomSleep = false
        if let sleepImage {
            autoreleasepool {
                if let sleepJPG = sleepImage.aspectFilled(to: retinaSize).jpegData(compressionQuality: 0.84),
                   (try? sleepJPG.write(to: assetsDir.appendingPathComponent("sleep.jpg"), options: .atomic)) != nil {
                    hasCustomSleep = true
                }
            }
        }

        var sublayers: [String] = []
        var overrides: [StateOverride] = []

        sublayers.append(
            morphMediaLayerXML(
                id: "unlock_layer",
                name: "Unlock Layer",
                zPosition: 0,
                staticFilename: "unlock.jpg",
                livePrefix: "unlock_frame",
                liveSequence: activeUnlockLive,
                autoReverses: autoReversesLive
            )
        )

        sublayers.append(
            morphMediaLayerXML(
                id: "locked_layer",
                name: "Locked Layer",
                zPosition: 1,
                staticFilename: "locked.jpg",
                livePrefix: "lock_frame",
                liveSequence: activeLockLive,
                autoReverses: autoReversesLive
            )
        )

        if hasCustomSleep {
            sublayers.append("""
                  <CALayer id="sleep_layer" name="Sleep Layer" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="2" opacity="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents>
                      <CGImage src="assets/sleep.jpg"/>
                    </contents>
                  </CALayer>
            """)
            overrides.append(StateOverride(targetId: "sleep_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 0.0, unlockVal: 0.0, isInteger: false))
        } else {
            let sleepDimAlpha = (preset == .aodGaze) ? 0.78 : 0.48
            sublayers.append("""
                  <CALayer id="sleep_dimmer" name="Sleep Dimmer" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
            """)
            overrides.append(StateOverride(targetId: "sleep_dimmer", keyPath: "opacity", sleepVal: sleepDimAlpha, lockedVal: 0.0, unlockVal: 0.0, isInteger: false))
        }

        switch preset {
        case .curtainRise:
            overrides.append(contentsOf: [
                StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "locked_layer", keyPath: "position.y", sleepVal: 422, lockedVal: 422, unlockVal: 940, isInteger: true),
                StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 0.96, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "position.y", sleepVal: 392, lockedVal: 404, unlockVal: 422, isInteger: true),
                StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.08, lockedVal: 1.06, unlockVal: 1.0, isInteger: false),
            ])

        case .burstZoom:
            overrides.append(contentsOf: [
                StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.04, lockedVal: 1.0, unlockVal: 0.86, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.24, lockedVal: 1.22, unlockVal: 1.0, isInteger: false),
            ])

        case .crossfade:
            overrides.append(contentsOf: [
                StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.03, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.04, lockedVal: 1.03, unlockVal: 1.0, isInteger: false),
            ])

        case .flashAwaken:
            overrides.append(contentsOf: [
                StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: 1.08, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.12, lockedVal: 1.10, unlockVal: 1.0, isInteger: false),
            ])

        case .holoCard:
            overrides.append(contentsOf: [
                StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "locked_layer", keyPath: "transform.rotation.y", sleepVal: -0.06, lockedVal: 0.0, unlockVal: 0.24, isInteger: false),
                StateOverride(targetId: "locked_layer", keyPath: "position.x", sleepVal: 195, lockedVal: 195, unlockVal: 215, isInteger: true),
                StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "transform.rotation.y", sleepVal: -0.24, lockedVal: -0.22, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "position.x", sleepVal: 175, lockedVal: 178, unlockVal: 195, isInteger: true),
                StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.06, lockedVal: 1.05, unlockVal: 1.0, isInteger: false),
            ])

        case .aodGaze:
            overrides.append(contentsOf: [
                StateOverride(targetId: "locked_layer", keyPath: "opacity", sleepVal: 1.0, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "locked_layer", keyPath: "transform.scale.xy", sleepVal: 0.94, lockedVal: 1.0, unlockVal: 1.06, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: "unlock_layer", keyPath: "transform.scale.xy", sleepVal: 1.14, lockedVal: 1.12, unlockVal: 1.0, isInteger: false),
            ])
        }

        return LayerBuildResult(sublayersXML: sublayers.joined(separator: "\n"), overrides: overrides)
    }

    private static func buildAndEncodeMorphFloating(
        lockCutout: UIImage?,
        unlockCutout: UIImage?,
        preset: MorphTransitionPreset,
        assetsDir: URL
    ) throws -> LayerBuildResult {
        var hasLockCutout = false
        var hasUnlockCutout = false
        if let lockCut = lockCutout {
            try autoreleasepool {
                if let png = lockCut.pngData() {
                    try png.write(to: assetsDir.appendingPathComponent("cutout_lock.png"), options: .atomic)
                    hasLockCutout = true
                }
            }
        }
        if let unlockCut = unlockCutout {
            try autoreleasepool {
                if let png = unlockCut.pngData() {
                    try png.write(to: assetsDir.appendingPathComponent("cutout_unlock.png"), options: .atomic)
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
            sublayers.append("""
                  <CALayer id="float_unlock" name="Floating Unlock Subject" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="1" opacity="0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents>
                      <CGImage src="assets/cutout_unlock.png"/>
                    </contents>
                  </CALayer>
            """)
            overrides.append(contentsOf: [
                StateOverride(targetId: "float_unlock", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 1.0, isInteger: false),
                StateOverride(targetId: "float_unlock", keyPath: "transform.scale.xy", sleepVal: 1.16, lockedVal: 1.14, unlockVal: 1.0, isInteger: false),
            ])
        }

        if hasLockCutout {
            sublayers.append("""
                  <CALayer id="float_lock" name="Floating Lock Subject" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="2" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents>
                      <CGImage src="assets/cutout_lock.png"/>
                    </contents>
                  </CALayer>
            """)
            let unlockY: Double = (preset == .curtainRise) ? 960 : 422
            let unlockScale: Double = (preset == .burstZoom) ? 0.84 : 1.06
            overrides.append(contentsOf: [
                StateOverride(targetId: "float_lock", keyPath: "opacity", sleepVal: 0.72, lockedVal: 1.0, unlockVal: 0.0, isInteger: false),
                StateOverride(targetId: "float_lock", keyPath: "position.y", sleepVal: 422, lockedVal: 422, unlockVal: unlockY, isInteger: true),
                StateOverride(targetId: "float_lock", keyPath: "transform.scale.xy", sleepVal: 0.98, lockedVal: 1.0, unlockVal: unlockScale, isInteger: false),
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
        autoReverses: Bool
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
              <CALayer id="\(id)" name="\(name)" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="\(zPosition)" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
        \(bodyXML)
              </CALayer>
        """
    }

    private static func buildAndEncodeVideoLayers(
        spec: VideoCompileSpec,
        assetsDir: URL
    ) throws -> LayerBuildResult {
        for (idx, frameData) in spec.sequence.frameJPEGs.enumerated() {
            try frameData.write(to: assetsDir.appendingPathComponent("frame_\(idx).jpg"), options: .atomic)
        }

        let animBody = discreteContentsAnimationXML(
            prefix: "frame",
            frameCount: spec.sequence.frameJPEGs.count,
            duration: spec.sequence.durationSeconds,
            autoReverses: spec.loopStyle == .pingPong
        )

        var sublayers: [String] = []
        sublayers.append("""
              <CALayer id="video_seq_layer" name="Video Sequence Layer" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
        \(animBody)
              </CALayer>
        """)

        var overrides: [StateOverride] = [
            StateOverride(targetId: "video_seq_layer", keyPath: "transform.scale.xy", sleepVal: 1.02, lockedVal: 1.0, unlockVal: spec.unlockZoomScale, isInteger: false)
        ]

        if spec.dimInSleepMode {
            sublayers.append("""
                  <CALayer id="video_sleep_dim" name="Sleep Dimmer" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="2" opacity="0" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
            """)
            overrides.append(StateOverride(targetId: "video_sleep_dim", keyPath: "opacity", sleepVal: 0.65, lockedVal: 0.0, unlockVal: 0.0, isInteger: false))
        }

        return LayerBuildResult(sublayersXML: sublayers.joined(separator: "\n"), overrides: overrides)
    }

    private static func buildAndEncodeForegroundFX(
        particlePreset: ParticlePreset,
        includeFlashPulse: Bool,
        assetsDir: URL
    ) throws -> LayerBuildResult {
        if particlePreset != .none {
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
            sublayers.append("""
                  <CALayer id="flash_veil" name="Flash Veil" bounds="0 0 510 964" position="\(centerX) \(centerY)" zPosition="1" opacity="0" backgroundColor="1 0.98 0.94" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular"/>
            """)
            overrides.append(StateOverride(targetId: "flash_veil", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.0, unlockVal: 0.06, isInteger: false))
        }

        if particlePreset != .none {
            let volumetric = buildVolumetricLightLayers(for: particlePreset)
            sublayers.append(contentsOf: volumetric.layersXML)
            overrides.append(contentsOf: volumetric.overrides)

            let emitters = buildEmitterLayers(for: particlePreset)
            sublayers.append(contentsOf: emitters.layersXML)
            for emitterID in emitters.layerIDs {
                overrides.append(StateOverride(targetId: emitterID, keyPath: "opacity", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 0.88, isInteger: false))
                overrides.append(StateOverride(targetId: emitterID, keyPath: "birthRate", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false))
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

    private static func buildVolumetricLightLayers(for preset: ParticlePreset) -> (layersXML: [String], overrides: [StateOverride]) {
        switch preset {
        case .sunbeamRays:
            let layer0 = """
                  <CALayer id="sunbeam_layer_0" name="Sunbeam Shaft A" bounds="0 0 520 960" position="165 480" zPosition="2" opacity="0.78" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
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
                          <real value="145"/>
                          <real value="195"/>
                        </values>
                      </animation>
                    </animations>
                  </CALayer>
            """
            let layer1 = """
                  <CALayer id="sunbeam_layer_1" name="Sunbeam Shaft B" bounds="0 0 480 920" position="235 450" zPosition="3" opacity="0.55" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
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
                    StateOverride(targetId: "sunbeam_layer_0", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.78, unlockVal: 0.65, isInteger: false),
                    StateOverride(targetId: "sunbeam_layer_0", keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                    StateOverride(targetId: "sunbeam_layer_1", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.55, unlockVal: 0.45, isInteger: false),
                    StateOverride(targetId: "sunbeam_layer_1", keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false)
                ]
            )

        case .auroraRibbon:
            let layer0 = """
                  <CALayer id="aurora_layer_0" name="Aurora Silk Veil A" bounds="0 0 560 620" position="195 570" zPosition="2" opacity="0.80" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents type="CGImage" src="assets/particle_aurora_silk_a.png"/>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                    <animations>
                      <animation type="CAKeyframeAnimation" keyPath="position.x" autoreverses="1" beginTime="1e-100" duration="6.8" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="145"/>
                          <real value="245"/>
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
                  <CALayer id="aurora_layer_1" name="Aurora Silk Veil B" bounds="0 0 540 560" position="195 390" zPosition="3" opacity="0.58" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <contents type="CGImage" src="assets/particle_aurora_silk_a.png"/>
                    <compositingFilter type="CAFilter" filter="plusL" name="plusL"/>
                    <animations>
                      <animation type="CAKeyframeAnimation" keyPath="position.x" autoreverses="1" beginTime="1e-100" duration="8.4" fillMode="both" removedOnCompletion="0" repeatCount="inf" timingFunction="easeInEaseOut">
                        <keyTimes>
                          <integer value="0"/>
                          <integer value="1"/>
                        </keyTimes>
                        <values>
                          <real value="245"/>
                          <real value="145"/>
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
                    StateOverride(targetId: "aurora_layer_0", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.80, unlockVal: 0.68, isInteger: false),
                    StateOverride(targetId: "aurora_layer_0", keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false),
                    StateOverride(targetId: "aurora_layer_1", keyPath: "opacity", sleepVal: 0.0, lockedVal: 0.58, unlockVal: 0.48, isInteger: false),
                    StateOverride(targetId: "aurora_layer_1", keyPath: "speed", sleepVal: 0.0, lockedVal: 1.0, unlockVal: 1.0, isInteger: false)
                ]
            )

        default:
            return ([], [])
        }
    }

    private static func buildEmitterLayers(for preset: ParticlePreset) -> (layersXML: [String], layerIDs: [String]) {
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
        var ids: [String] = []
        for layer in specs {
            ids.append(layer.id)
            let cellsXML = layer.cells.map { c in
                """
                          <CAEmitterCell id="\(c.id)" name="\(c.id)" contentsScale="2" birthRate="\(c.birthRate)" lifetime="\(c.lifetime)" velocity="\(c.velocity)" velocityRange="\(c.velocityRange)" emissionRange="\(c.emissionRange)" emissionLongitude="\(c.emissionLong)" emissionLatitude="0" scale="\(c.scale)" scaleRange="\(c.scaleRange)" scaleSpeed="\(c.scaleSpeed)" alphaRange="\(c.alphaRange)" alphaSpeed="\(c.alphaSpeed)" spin="\(c.spin)" spinRange="\(c.spinRange)" xAcceleration="\(c.xAccel)" yAcceleration="\(c.yAccel)" redRange="\(c.redRange)" greenRange="\(c.greenRange)" blueRange="\(c.blueRange)" redSpeed="0" greenSpeed="\(c.greenSpeed)" blueSpeed="\(c.blueSpeed)">
                            <color value="\(c.colorRGB)" opacity="\(c.colorAlpha)"/>
                            <contents>
                              <CGImage src="assets/\(c.spriteFilename)"/>
                            </contents>
                          </CAEmitterCell>
                """
            }.joined(separator: "\n")

            xmls.append("""
                  <CAEmitterLayer id="\(layer.id)" name="\(layer.name)" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="\(layer.zPos)" emitterPosition="\(layer.emitterPosX) \(layer.emitterPosY)" emitterSize="\(layer.emitterW) \(layer.emitterH)" emitterShape="rectangle" emitterMode="volume" renderMode="\(layer.renderMode)" birthRate="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                    <emitterCells>
            \(cellsXML)
                    </emitterCells>
                  </CAEmitterLayer>
            """)
        }
        return (xmls, ids)
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

    private static func wrapParameterizedRootCAML(
        bgSublayersXML: String,
        fgSublayersXML: String,
        fxSublayersXML: String,
        fgOverscanScale: Double,
        overrides: [StateOverride],
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

        let statesXML = statesAndTransitionsXML(overrides: overrides, duration: duration, bounce: bounce)

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
              <wallpaperPropertyGroups type="NSArray"/>
            </style>
            <sublayers>
              <CALayer id="background" name="BACKGROUND" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" geometryFlipped="0" masksToBounds="1" opacity="1" backgroundColor="0 0 0" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CATransformLayer id="camlo_bg_parallax" name="Camlo_BG_Parallax" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" opacity="1">
                    <sublayers>
                      <CALayer id="camlo_bg_overscan" name="Camlo_BG_Overscan" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" opacity="1" transform="scale(\(bgOverscan), \(bgOverscan), 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(bgInner)
                      </CALayer>
                    </sublayers>
                  </CATransformLayer>
                </sublayers>
              </CALayer>
              <CALayer id="floating" name="FLOATING" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="10" geometryFlipped="0" masksToBounds="1" opacity="1" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">
                <sublayers>
                  <CATransformLayer id="camlo_fg_parallax" name="Camlo_FG_Parallax" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="10" opacity="1">
                    <sublayers>
                      <CALayer id="camlo_fg_overscan" name="Camlo_FG_Overscan" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="0" opacity="1" transform="scale(\(fgOverscanStr), \(fgOverscanStr), 1)" allowsEdgeAntialiasing="1" allowsGroupOpacity="1" contentsFormat="RGBA8" cornerCurve="circular">\(fgInner)
                      </CALayer>
                    </sublayers>
                  </CATransformLayer>
                  <CATransformLayer id="camlo_fx_parallax" name="Camlo_FX_Parallax" bounds="0 0 \(canvasW) \(canvasH)" position="\(centerX) \(centerY)" zPosition="20" opacity="1">\(fxInner)
                  </CATransformLayer>
                </sublayers>
              </CALayer>
            </sublayers>
        \(statesXML)
          </CALayer>
        </caml>
        """
    }

    private static func standardIndexXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>assetManifest</key>
        \t<string>assetManifest.caml</string>
        \t<key>documentHeight</key>
        \t<real>\(canvasH)</real>
        \t<key>documentResizesToView</key>
        \t<false/>
        \t<key>documentWidth</key>
        \t<real>\(canvasW)</real>
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
