//
//  SubjectCutoutService.swift
//  Camlo · 开幕
//
//  On-device Apple Neural Engine subject segmentation (Vision + CoreImage)
//  for true Lock Screen Clock Depth occlusion in Floating.ca!
//

import UIKit
import Vision
import CoreImage

enum SubjectCutoutError: LocalizedError {
    case invalidImage
    case noSubjectDetected
    case maskRenderFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return Bi("无法解析所选图片像素数据", "Unable to read image pixel buffer")
        case .noSubjectDetected:
            return Bi("未在画面中识别到清晰的前景人物/主体，请尝试主体轮廓更分明的图片", "No distinct foreground subject was detected in this image")
        case .maskRenderFailed:
            return Bi("前景蒙版合成失败", "Failed to composite foreground cutout mask")
        }
    }
}

enum SubjectCutoutService {
    /// Extracts the foreground subject into an alpha-transparent UIImage sized to `targetPixelSize`.
    static func extractForegroundSubject(
        from sourceImage: UIImage,
        targetPixelSize: CGSize = CGSize(width: 1170, height: 2532)
    ) async throws -> UIImage {
        let normalized = sourceImage.aspectFilled(to: targetPixelSize)
        guard let cgImage = normalized.cgImage else {
            throw SubjectCutoutError.invalidImage
        }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                throw SubjectCutoutError.noSubjectDetected
            }

            let maskPixelBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )

            let inputCI = CIImage(cgImage: cgImage)
            let maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)
            let clearBG = CIImage(color: .clear).cropped(to: inputCI.extent)

            guard let blend = CIFilter(name: "CIBlendWithMask") else {
                throw SubjectCutoutError.maskRenderFailed
            }
            blend.setValue(inputCI, forKey: kCIInputImageKey)
            blend.setValue(clearBG, forKey: kCIInputBackgroundImageKey)
            blend.setValue(maskCI, forKey: kCIInputMaskImageKey)

            let ciContext = CIContext(options: [.useSoftwareRenderer: false])
            guard let outputCI = blend.outputImage,
                  let outCG = ciContext.createCGImage(outputCI, from: inputCI.extent) else {
                throw SubjectCutoutError.maskRenderFailed
            }

            return UIImage(cgImage: outCG, scale: 1.0, orientation: .up)
        }.value
    }
}
