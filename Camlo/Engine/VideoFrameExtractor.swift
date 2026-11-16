//
//  VideoFrameExtractor.swift
//  Camlo · 开幕
//
//  Converts short videos (.mp4/.mov) and Live Photos into PosterBoard Jetsam-safe
//  9:16 aspect-filled JPEG frame sequences for CAKeyframeAnimation CAML wallpapers.
//

import Foundation
import AVFoundation
import CoreTransferable
import Photos
import UIKit
import UniformTypeIdentifiers

struct CamloPickedMovieFile: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try copyReceivedVideo(received.file, defaultExt: "mov")
        }
        FileRepresentation(importedContentType: .mpeg4Movie) { received in
            try copyReceivedVideo(received.file, defaultExt: "mp4")
        }
        FileRepresentation(importedContentType: .quickTimeMovie) { received in
            try copyReceivedVideo(received.file, defaultExt: "mov")
        }
        FileRepresentation(importedContentType: .video) { received in
            try copyReceivedVideo(received.file, defaultExt: "mov")
        }
        FileRepresentation(importedContentType: .audiovisualContent) { received in
            try copyReceivedVideo(received.file, defaultExt: "mov")
        }
    }

    private static func copyReceivedVideo(_ file: URL, defaultExt: String) throws -> CamloPickedMovieFile {
        let scoped = file.startAccessingSecurityScopedResource()
        defer {
            if scoped { file.stopAccessingSecurityScopedResource() }
        }
        let ext = file.pathExtension.isEmpty ? defaultExt : file.pathExtension
        let dst = URL.temporaryDirectory.appendingPathComponent("camlo_pick_\(UUID().uuidString).\(ext)")
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.copyItem(at: file, to: dst)
        return CamloPickedMovieFile(url: dst)
    }
}

struct ExtractedVideoSequence: Sendable {
    let frameJPEGs: [Data]
    let previewImages: [UIImage]
    let fps: Int
    let durationSeconds: Double
    let pixelWidth: Int
    let pixelHeight: Int
}

enum VideoExtractorError: LocalizedError {
    case unreadableVideoTrack
    case livePhotoNoPairedVideo
    case zeroFramesExtracted

    var errorDescription: String? {
        switch self {
        case .unreadableVideoTrack:
            return Bi("无法读取视频画面轨道，请更换为常见 MP4 / MOV 视频重试", "Unable to read video track; please try a standard MP4 or MOV clip")
        case .livePhotoNoPairedVideo:
            return Bi("该实况照片不包含动态视频轨道", "This Live Photo does not contain a paired video resource")
        case .zeroFramesExtracted:
            return Bi("未能提取到有效视频帧", "No valid frames could be extracted from the video")
        }
    }
}

enum VideoFrameExtractor {
    /// Extracts the paired `.mov` file from a `PHLivePhoto` into a temporary file URL.
    static func extractPairedVideoURL(from livePhoto: PHLivePhoto) async throws -> URL {
        let resources = PHAssetResource.assetResources(for: livePhoto)
        guard let videoRes = resources.first(where: { $0.type == .pairedVideo || $0.type == .fullSizePairedVideo }) else {
            throw VideoExtractorError.livePhotoNoPairedVideo
        }

        let outURL = URL.temporaryDirectory.appendingPathComponent("camlo_live_\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: outURL)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let opts = PHAssetResourceRequestOptions()
            opts.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: videoRes, toFile: outURL, options: opts) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
        return outURL
    }

    /// Extracts a single preview poster frame for interactive cropping before frame-sequence encoding.
    static func extractPosterFrame(from videoURL: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            throw VideoExtractorError.unreadableVideoTrack
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        generator.maximumSize = CGSize(width: 1600, height: 1600)
        let (cgImg, _) = try await generator.image(at: .zero)
        return UIImage(cgImage: cgImg, scale: 1.0, orientation: .up)
    }

    /// Extracts aspect-filled 9:16 JPEG frames within PosterBoard's safe memory envelope.
    static func extractSequence(
        from videoURL: URL,
        targetFPS: Int = 18,
        maxDurationSeconds: Double = 5.0,
        highQuality: Bool = true,
        framing: CropFraming = .identity,
        targetCanvasSize: CGSize? = nil,
        overrideMaxFrames: Int? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ExtractedVideoSequence {
        let (asset, rawDuration) = try await loadValidatedVideoAsset(from: videoURL)

        let clippedDuration = min(rawDuration, maxDurationSeconds)
        let clampedFPS = max(10, min(targetFPS, 30))
        // Cap total frames at 40 (or custom budget for dual-screen) and adapt pixel dimensions for PosterBoard Jetsam safety.
        let maxFramesBudget = max(6, overrideMaxFrames ?? 40)
        let desiredFrames = max(6, min(maxFramesBudget, Int((clippedDuration * Double(clampedFPS)).rounded())))

        let targetSize: CGSize
        if let customSize = targetCanvasSize {
            if !highQuality {
                let scale: CGFloat = 0.76
                targetSize = CGSize(
                    width: CGFloat((Int((customSize.width * scale).rounded()) / 2) * 2),
                    height: CGFloat((Int((customSize.height * scale).rounded()) / 2) * 2)
                )
            } else {
                targetSize = customSize
            }
        } else if !highQuality {
            targetSize = CGSize(width: 360, height: 780)
        } else if desiredFrames <= 18 {
            targetSize = CGSize(width: 540, height: 1170)
        } else if desiredFrames <= 26 {
            targetSize = CGSize(width: 468, height: 1014)
        } else if desiredFrames <= 32 {
            targetSize = CGSize(width: 432, height: 936)
        } else {
            targetSize = CGSize(width: 390, height: 844)
        }

        return try await decodeFrames(
            from: asset,
            clippedDuration: clippedDuration,
            rawDuration: rawDuration,
            desiredFrames: desiredFrames,
            clampedFPS: clampedFPS,
            targetSize: targetSize,
            jpegQuality: highQuality ? 0.80 : 0.74,
            toleranceSeconds: 0.08,
            framing: framing,
            onProgress: onProgress
        )
    }

    /// Extracts a Jetsam-budgeted Live Photo / video sequence for Hybrid Live + Slide-to-Morph slots.
    static func extractMorphLiveSequence(
        from videoURL: URL,
        framing: CropFraming = .identity,
        compactResolution: Bool = false,
        targetCanvasSize: CGSize? = nil
    ) async throws -> ExtractedVideoSequence {
        let (asset, rawDuration) = try await loadValidatedVideoAsset(from: videoURL)

        let clampedFPS = 14
        let clippedDuration: Double
        let desiredFrames: Int
        let targetSize: CGSize

        if let customSize = targetCanvasSize {
            if compactResolution {
                clippedDuration = min(rawDuration, 2.4)
                desiredFrames = max(6, min(14, Int((clippedDuration * Double(clampedFPS)).rounded())))
                let scale: CGFloat = 0.80
                targetSize = CGSize(
                    width: CGFloat((Int((customSize.width * scale).rounded()) / 2) * 2),
                    height: CGFloat((Int((customSize.height * scale).rounded()) / 2) * 2)
                )
            } else {
                clippedDuration = min(rawDuration, 2.8)
                desiredFrames = max(6, min(18, Int((clippedDuration * Double(clampedFPS)).rounded())))
                targetSize = customSize
            }
        } else if compactResolution {
            clippedDuration = min(rawDuration, 2.6)
            desiredFrames = max(6, min(18, Int((clippedDuration * Double(clampedFPS)).rounded())))
            targetSize = CGSize(width: 390, height: 844)
        } else {
            clippedDuration = min(rawDuration, 3.0)
            desiredFrames = max(6, min(22, Int((clippedDuration * Double(clampedFPS)).rounded())))
            targetSize = desiredFrames <= 15
                ? CGSize(width: 468, height: 1014)
                : CGSize(width: 432, height: 936)
        }

        return try await decodeFrames(
            from: asset,
            clippedDuration: clippedDuration,
            rawDuration: rawDuration,
            desiredFrames: desiredFrames,
            clampedFPS: clampedFPS,
            targetSize: targetSize,
            jpegQuality: 0.78,
            toleranceSeconds: 0.07,
            framing: framing
        )
    }

    // MARK: - Shared Frame Decoding

    private static func loadValidatedVideoAsset(from videoURL: URL) async throws -> (AVURLAsset, Double) {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            throw VideoExtractorError.unreadableVideoTrack
        }
        let rawDuration = try await asset.load(.duration).seconds
        guard rawDuration.isFinite && rawDuration > 0.08 else {
            throw VideoExtractorError.unreadableVideoTrack
        }
        return (asset, rawDuration)
    }

    private static func decodeFrames(
        from asset: AVURLAsset,
        clippedDuration: Double,
        rawDuration: Double,
        desiredFrames: Int,
        clampedFPS: Int,
        targetSize: CGSize,
        jpegQuality: CGFloat,
        toleranceSeconds: Double,
        framing: CropFraming,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ExtractedVideoSequence {
        let actualDuration = Double(desiredFrames) / Double(clampedFPS)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let tol = CMTime(seconds: toleranceSeconds, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tol
        generator.requestedTimeToleranceAfter = tol
        let maxDim = min(2560, targetSize.height * max(1.6, min(framing.zoom, 2.6) * 1.25))
        generator.maximumSize = CGSize(width: maxDim, height: maxDim)

        var jpegFrames: [Data] = []
        var previewFrames: [UIImage] = []
        jpegFrames.reserveCapacity(desiredFrames)

        let previewStep = max(1, desiredFrames / 36)

        for idx in 0..<desiredFrames {
            if Task.isCancelled { break }
            let tSec = min(rawDuration - 0.001, (Double(idx) / Double(desiredFrames)) * clippedDuration)
            let cmTime = CMTime(seconds: max(0, tSec), preferredTimescale: 600)
            if let (cgImg, _) = try? await generator.image(at: cmTime) {
                autoreleasepool {
                    let uiImg = UIImage(cgImage: cgImg)
                    let cropped = uiImg.aspectFilled(to: targetSize, framing: framing)
                    if let jpg = cropped.jpegData(compressionQuality: jpegQuality) {
                        jpegFrames.append(jpg)
                        if idx % previewStep == 0 || previewFrames.isEmpty {
                            previewFrames.append(cropped)
                        }
                    }
                }
            }
            onProgress?(Double(idx + 1) / Double(desiredFrames))
        }

        if jpegFrames.isEmpty && !Task.isCancelled {
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .positiveInfinity
            if let (cgImg, _) = try? await generator.image(at: .zero) {
                autoreleasepool {
                    let uiImg = UIImage(cgImage: cgImg)
                    let cropped = uiImg.aspectFilled(to: targetSize, framing: framing)
                    if let jpg = cropped.jpegData(compressionQuality: jpegQuality) {
                        jpegFrames.append(jpg)
                        previewFrames.append(cropped)
                    }
                }
            }
        }

        guard !jpegFrames.isEmpty else {
            throw VideoExtractorError.zeroFramesExtracted
        }

        return ExtractedVideoSequence(
            frameJPEGs: jpegFrames,
            previewImages: previewFrames,
            fps: clampedFPS,
            durationSeconds: actualDuration,
            pixelWidth: Int(targetSize.width),
            pixelHeight: Int(targetSize.height)
        )
    }
}
