//
//  MotionTiltManager.swift
//  Camlo · 开幕
//
//  120Hz ProMotion CADisplayLink + CoreMotion Gyroscope 3D tilt engine
//  with neutral attitude auto-baseline, manual touch drag, and 1-tap orbital demo.
//

import Foundation
import CoreMotion
import QuartzCore
import UIKit
import Combine

@MainActor
final class MotionTiltManager: ObservableObject {
    static let shared = MotionTiltManager()

    @Published private(set) var tiltX: CGFloat = 0
    @Published private(set) var tiltY: CGFloat = 0
    @Published private(set) var hasHardwareGyro: Bool = false
    @Published var isAutoOrbitDemo: Bool = false {
        didSet {
            if isAutoOrbitDemo {
                orbitPhaseStart = CACurrentMediaTime()
            }
        }
    }
    @Published private(set) var activeRefreshHz: Int = 120

    private let motionManager = CMMotionManager()
    private var displayLink: CADisplayLink?
    private var proxy: DisplayLinkProxy?

    private var activeTokens: Set<UUID> = []
    private var frameObservers: [UUID: @MainActor (CGFloat, CGFloat) -> Void] = [:]

    private var baselineRoll: Double?
    private var baselinePitch: Double?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var orbitPhaseStart: CFTimeInterval = 0

    private var isManualDragging: Bool = false
    private var manualTargetX: CGFloat = 0
    private var manualTargetY: CGFloat = 0

    private var smoothedX: CGFloat = 0
    private var smoothedY: CGFloat = 0

    private final class DisplayLinkProxy: NSObject {
        weak var owner: MotionTiltManager?
        init(owner: MotionTiltManager) {
            self.owner = owner
        }

        @objc func handleTick(_ link: CADisplayLink) {
            MainActor.assumeIsolated {
                owner?.onDisplayTick(link)
            }
        }
    }

    private init() {
        hasHardwareGyro = motionManager.isDeviceMotionAvailable
        activeRefreshHz = Self.detectMaxScreenHz()
    }

    private static func detectMaxScreenHz() -> Int {
        let fps = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
            .maximumFramesPerSecond ?? 120
        return max(60, fps)
    }

    func startSession(token: UUID) {
        let wasEmpty = activeTokens.isEmpty
        activeTokens.insert(token)
        guard wasEmpty else { return }

        hasHardwareGyro = motionManager.isDeviceMotionAvailable
        if hasHardwareGyro {
            motionManager.deviceMotionUpdateInterval = 1.0 / 120.0
            if !motionManager.isDeviceMotionActive {
                motionManager.startDeviceMotionUpdates()
            }
        }
        baselineRoll = nil
        baselinePitch = nil
        lastFrameTimestamp = 0
        orbitPhaseStart = CACurrentMediaTime()
        startDisplayLink()
    }

    func stopSession(token: UUID) {
        activeTokens.remove(token)
        guard activeTokens.isEmpty else { return }

        stopDisplayLink()
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        baselineRoll = nil
        baselinePitch = nil
        isManualDragging = false
        smoothedX = 0
        smoothedY = 0
        tiltX = 0
        tiltY = 0
    }

    func registerFrameObserver(token: UUID, handler: @escaping @MainActor (CGFloat, CGFloat) -> Void) {
        frameObservers[token] = handler
        handler(smoothedX, smoothedY)
    }

    func unregisterFrameObserver(token: UUID) {
        frameObservers.removeValue(forKey: token)
    }

    func recenter() {
        if let attitude = motionManager.deviceMotion?.attitude {
            baselineRoll = attitude.roll
            baselinePitch = attitude.pitch
        } else {
            baselineRoll = nil
            baselinePitch = nil
        }
        manualTargetX = 0
        manualTargetY = 0
    }

    func setManualDragTilt(x: CGFloat, y: CGFloat) {
        isManualDragging = true
        manualTargetX = max(-1.0, min(1.0, x))
        manualTargetY = max(-1.0, min(1.0, y))
    }

    func endManualDragTilt() {
        isManualDragging = false
        manualTargetX = 0
        manualTargetY = 0
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(owner: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.handleTick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.proxy = proxy
        self.displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        proxy = nil
    }

    private func onDisplayTick(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt: Double
        if lastFrameTimestamp > 0 {
            dt = min(0.05, max(0.002, now - lastFrameTimestamp))
        } else {
            dt = 1.0 / 120.0
        }
        lastFrameTimestamp = now

        let interval = link.targetTimestamp - link.timestamp
        if interval > 0.001 && interval < 0.05 {
            let instantHz = Int((1.0 / interval).rounded())
            let snappedHz = instantHz >= 100 ? 120 : (instantHz >= 75 ? 80 : 60)
            if abs(snappedHz - activeRefreshHz) >= 15 {
                activeRefreshHz = snappedHz
            }
        }

        var targetX: CGFloat = 0
        var targetY: CGFloat = 0

        if isManualDragging {
            targetX = manualTargetX
            targetY = manualTargetY
        } else if isAutoOrbitDemo {
            let t = CACurrentMediaTime() - orbitPhaseStart
            targetX = CGFloat(sin(t * 1.65) * 0.88)
            targetY = CGFloat(cos(t * 1.15) * 0.68)
        } else if hasHardwareGyro, let attitude = motionManager.deviceMotion?.attitude {
            if baselineRoll == nil || baselinePitch == nil {
                baselineRoll = attitude.roll
                baselinePitch = attitude.pitch
            }
            let dRoll = Self.wrapDeltaAngle(attitude.roll - (baselineRoll ?? 0))
            let dPitch = attitude.pitch - (baselinePitch ?? 0)
            // Gently pull baseline toward sustained posture shifts so held angles stay comfortable
            baselineRoll = (baselineRoll ?? 0) + dRoll * min(0.08, dt * 0.35)
            baselinePitch = (baselinePitch ?? 0) + dPitch * min(0.08, dt * 0.35)

            let normX = tanh(dRoll / 0.42)
            let normY = tanh(dPitch / 0.42)
            targetX = CGFloat(normX)
            targetY = CGFloat(normY)
        }

        let alpha = CGFloat(min(1.0, dt * 18.0))
        smoothedX += (targetX - smoothedX) * alpha
        smoothedY += (targetY - smoothedY) * alpha

        if abs(smoothedX) < 0.0005 && abs(targetX) < 0.0005 { smoothedX = 0 }
        if abs(smoothedY) < 0.0005 && abs(targetY) < 0.0005 { smoothedY = 0 }

        if abs(smoothedX - tiltX) > 0.0008 || abs(smoothedY - tiltY) > 0.0008 ||
            (smoothedX == 0 && tiltX != 0) || (smoothedY == 0 && tiltY != 0) {
            tiltX = smoothedX
            tiltY = smoothedY
        }

        if !frameObservers.isEmpty {
            for observer in frameObservers.values {
                observer(smoothedX, smoothedY)
            }
        }
    }

    private static func wrapDeltaAngle(_ angle: Double) -> Double {
        var delta = angle
        while delta > .pi { delta -= 2.0 * .pi }
        while delta < -.pi { delta += 2.0 * .pi }
        return delta
    }
}
