//
//  AnimatedPreviewView.swift
//  Camlo · 开幕
//
//  Clean-room remote still/animated preview cache and Core Animation discrete keyframe renderer.
//

import SwiftUI
import UIKit
import ImageIO
import CryptoKit
import QuartzCore

// MARK: - Preview Mode

enum CamloPreviewMode: Equatable, Hashable, Sendable {
    case still(maxPixel: Int = 600)
    case motion(maxPixel: Int = 840, maxKeyframes: Int = 64)

    var maxPixelSize: Int {
        switch self {
        case .still(let maxPixel): return maxPixel
        case .motion(let maxPixel, _): return maxPixel
        }
    }
}

// MARK: - Remote Preview Cache Store

private actor CamloPreviewAssetStore {
    static let shared = CamloPreviewAssetStore()

    private let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 96
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 14
        config.timeoutIntervalForResource = 28
        config.httpAdditionalHeaders = ["User-Agent": "Camlo/\(CamloDevice.appVersion)"]
        return URLSession(configuration: config)
    }()

    private var inFlight: [String: Task<Data?, Never>] = [:]

    func fetchPreviewData(cacheKey: String, candidateURLs: [URL]) async -> Data? {
        guard !candidateURLs.isEmpty else { return nil }
        CamloPaths.ensureDirectories()

        let keyHash = digestKey(cacheKey: cacheKey, urls: candidateURLs)
        let nsKey = keyHash as NSString

        if let mem = memoryCache.object(forKey: nsKey) {
            return mem as Data
        }

        let diskURL = CamloPaths.cloudPreviewCacheDir.appendingPathComponent("\(keyHash).dat")
        if let diskData = try? Data(contentsOf: diskURL), diskData.count >= 64 {
            memoryCache.setObject(diskData as NSData, forKey: nsKey, cost: diskData.count)
            return diskData
        }

        if let existingTask = inFlight[keyHash] {
            return await existingTask.value
        }

        let urlsCopy = candidateURLs
        let task = Task<Data?, Never> { [session] in
            for url in urlsCopy {
                if Task.isCancelled { return nil }
                var req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 14)
                req.setValue("Camlo/\(CamloDevice.appVersion)", forHTTPHeaderField: "User-Agent")
                AppSourceManager.applyGitHubAuthIfNeeded(to: &req)
                do {
                    let (data, response) = try await session.data(for: req)
                    guard let http = response as? HTTPURLResponse,
                          (200...299).contains(http.statusCode),
                          data.count >= 64 else {
                        continue
                    }
                    if let mime = http.mimeType?.lowercased(), mime.contains("text/html") {
                        continue
                    }
                    let prefixStr = String(decoding: data.prefix(24), as: UTF8.self).lowercased()
                    if prefixStr.contains("<html") || prefixStr.contains("<!doctype") {
                        continue
                    }
                    return data
                } catch {
                    continue
                }
            }
            return nil
        }

        inFlight[keyHash] = task
        let resolved = await task.value
        inFlight.removeValue(forKey: keyHash)

        if let resolved {
            memoryCache.setObject(resolved as NSData, forKey: nsKey, cost: resolved.count)
            try? resolved.write(to: diskURL, options: .atomic)
        }
        return resolved
    }

    private func digestKey(cacheKey: String, urls: [URL]) -> String {
        let material = "\(cacheKey)|\(urls.first?.absoluteString ?? "")"
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Keyframe Codec & Core Animation Host

private struct CamloDecodedSequence: @unchecked Sendable {
    let frames: [CGImage]
    let keyTimes: [NSNumber]
    let totalDuration: CFTimeInterval
}

private enum CamloKeyframeCodec {
    nonisolated static func decode(data: Data, mode: CamloPreviewMode) -> CamloDecodedSequence? {
        let sourceOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOpts as CFDictionary) else {
            return nil
        }

        let totalFrames = CGImageSourceGetCount(source)
        guard totalFrames > 0 else { return nil }

        let maxPixel = mode.maxPixelSize
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]

        switch mode {
        case .still:
            guard let img = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) else {
                return nil
            }
            return CamloDecodedSequence(frames: [img], keyTimes: [0.0, 1.0], totalDuration: 0)

        case .motion(_, let maxKeyframes):
            if totalFrames == 1 {
                guard let img = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) else {
                    return nil
                }
                return CamloDecodedSequence(frames: [img], keyTimes: [0.0, 1.0], totalDuration: 0)
            }

            let targetCount = max(2, min(totalFrames, maxKeyframes))
            let step = max(1, (totalFrames + targetCount - 1) / targetCount)

            var images: [CGImage] = []
            var durations: [Double] = []
            images.reserveCapacity(targetCount)
            durations.reserveCapacity(targetCount)

            var index = 0
            while index < totalFrames {
                let nextIndex = min(index + step, totalFrames)
                var bucketDelay = 0.0
                for rawIdx in index..<nextIndex {
                    bucketDelay += frameDelaySeconds(source: source, index: rawIdx)
                }
                if let frameImg = CGImageSourceCreateThumbnailAtIndex(source, index, thumbOpts as CFDictionary) {
                    images.append(frameImg)
                    durations.append(max(0.025, bucketDelay))
                }
                index = nextIndex
            }

            guard !images.isEmpty else { return nil }
            if images.count == 1 {
                return CamloDecodedSequence(frames: images, keyTimes: [0.0, 1.0], totalDuration: 0)
            }

            let sumDuration = max(0.25, durations.reduce(0, +))
            var cumulative = 0.0
            var keyTimes: [NSNumber] = [0.0]
            for idx in 0..<(images.count - 1) {
                cumulative += durations[idx]
                keyTimes.append(NSNumber(value: min(1.0, cumulative / sumDuration)))
            }
            keyTimes.append(1.0)

            // Discrete CAKeyframeAnimation requires matching terminal frame when closing interval cleanly.
            var closedFrames = images
            closedFrames.append(images[0])
            return CamloDecodedSequence(
                frames: closedFrames,
                keyTimes: keyTimes,
                totalDuration: sumDuration
            )
        }
    }

    nonisolated private static func frameDelaySeconds(source: CGImageSource, index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return 0.1
        }
        let rawDelay: Double? = {
            if let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
                    return unclamped
                }
                if let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double, clamped > 0 {
                    return clamped
                }
            }
            if let webp = props[kCGImagePropertyWebPDictionary] as? [CFString: Any] {
                if let unclamped = webp[kCGImagePropertyWebPUnclampedDelayTime] as? Double, unclamped > 0 {
                    return unclamped
                }
                if let clamped = webp[kCGImagePropertyWebPDelayTime] as? Double, clamped > 0 {
                    return clamped
                }
            }
            if let png = props[kCGImagePropertyPNGDictionary] as? [CFString: Any],
               let apng = png[kCGImagePropertyAPNGDelayTime] as? Double, apng > 0 {
                return apng
            }
            return nil
        }()
        let resolved = rawDelay ?? 0.1
        return resolved < 0.02 ? 0.1 : resolved
    }
}

private final class CamloLayerHostView: UIView {
    let mediaLayer = CALayer()
    private var appliedSignature: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = true
        mediaLayer.contentsGravity = .resizeAspectFill
        mediaLayer.masksToBounds = true
        layer.addSublayer(mediaLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mediaLayer.frame = bounds
        CATransaction.commit()
    }

    func apply(sequence: CamloDecodedSequence, contentMode: UIView.ContentMode, signature: Int) {
        mediaLayer.contentsGravity = (contentMode == .scaleAspectFit) ? .resizeAspect : .resizeAspectFill
        guard appliedSignature != signature else { return }
        appliedSignature = signature

        mediaLayer.removeAnimation(forKey: "camlo.keyframes")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mediaLayer.contents = sequence.frames.first
        CATransaction.commit()

        if sequence.frames.count > 1 && sequence.totalDuration > 0 {
            let anim = CAKeyframeAnimation(keyPath: "contents")
            anim.values = sequence.frames
            anim.keyTimes = sequence.keyTimes
            anim.calculationMode = .discrete
            anim.duration = sequence.totalDuration
            anim.repeatCount = .infinity
            anim.isRemovedOnCompletion = false
            mediaLayer.add(anim, forKey: "camlo.keyframes")
        }
    }
}

private struct CamloKeyframeLayerView: UIViewRepresentable {
    let sequence: CamloDecodedSequence
    let contentMode: UIView.ContentMode
    let signature: Int

    func makeUIView(context: Context) -> CamloLayerHostView {
        let view = CamloLayerHostView()
        view.apply(sequence: sequence, contentMode: contentMode, signature: signature)
        return view
    }

    func updateUIView(_ uiView: CamloLayerHostView, context: Context) {
        uiView.apply(sequence: sequence, contentMode: contentMode, signature: signature)
    }
}

// MARK: - SwiftUI Remote Preview Component

struct CamloRemotePreview: View {
    let cacheKey: String
    let candidateURLs: [URL]
    let mode: CamloPreviewMode
    let contentMode: UIView.ContentMode
    let placeholderColors: [Color]
    let bundledFileURL: URL?

    @State private var sequence: CamloDecodedSequence? = nil
    @State private var sequenceSignature: Int = 0
    @State private var didFail: Bool = false

    init(
        cacheKey: String,
        candidateURLs: [URL],
        mode: CamloPreviewMode = .still(maxPixel: 600),
        contentMode: UIView.ContentMode = .scaleAspectFill,
        placeholderColors: [Color] = [Color.indigo.opacity(0.28), Color.purple.opacity(0.22)],
        bundledFileURL: URL? = nil
    ) {
        self.cacheKey = cacheKey
        self.candidateURLs = candidateURLs
        self.mode = mode
        self.contentMode = contentMode
        self.placeholderColors = placeholderColors
        self.bundledFileURL = bundledFileURL
    }

    private var taskToken: String {
        "\(cacheKey)|\(mode.hashValue)|\(candidateURLs.first?.absoluteString ?? "")|\(bundledFileURL?.lastPathComponent ?? "")"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: placeholderColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let sequence {
                CamloKeyframeLayerView(
                    sequence: sequence,
                    contentMode: contentMode,
                    signature: sequenceSignature
                )
            } else if didFail {
                Image(systemName: "photo.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ProgressView()
                    .tint(.white.opacity(0.8))
            }
        }
        .task(id: taskToken) {
            didFail = false
            let targetMode = mode
            let localURL = bundledFileURL
            var decoded: CamloDecodedSequence? = nil

            if let localURL {
                decoded = await Task.detached(priority: .utility) {
                    guard let data = try? Data(contentsOf: localURL, options: .mappedIfSafe),
                          data.count >= 64 else {
                        return nil
                    }
                    return CamloKeyframeCodec.decode(data: data, mode: targetMode)
                }.value
            }

            if decoded == nil,
               let rawData = await CamloPreviewAssetStore.shared.fetchPreviewData(
                   cacheKey: cacheKey,
                   candidateURLs: candidateURLs
               ) {
                decoded = await Task.detached(priority: .utility) {
                    CamloKeyframeCodec.decode(data: rawData, mode: targetMode)
                }.value
            }

            guard !Task.isCancelled else { return }
            if let decoded {
                var hasher = Hasher()
                hasher.combine(taskToken)
                hasher.combine(decoded.frames.count)
                sequenceSignature = hasher.finalize()
                sequence = decoded
            } else {
                didFail = true
            }
        }
    }
}
