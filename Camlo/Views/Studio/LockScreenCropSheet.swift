//
//  LockScreenCropSheet.swift
//  Camlo · 开幕
//
//  Interactive 9:16 Lock Screen photo/Live Photo/video framing editor with
//  drag-to-pan, pinch/slider zoom, 09:41 clock & bottom control guides,
//  and optional free-move blurred edge extension for bottom-edge subjects.
//

import SwiftUI
import UIKit

struct LockScreenCropSheet: View {
    let title: String
    let image: UIImage
    let initialFraming: CropFraming
    var canvasSize: CGSize = CGSize(width: 390, height: 844)
    var pairedSlotSyncLabel: String? = nil
    let onApply: (CropFraming, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var committed: CropFraming
    @State private var dragDelta: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @State private var isPinching: Bool = false
    @State private var isInteracting: Bool = false
    @State private var showLockGuides: Bool = true
    @State private var syncToPaired: Bool = false

    private var canvasAspect: CGFloat {
        canvasSize.width / max(canvasSize.height, 1)
    }

    private var isLandscapeCanvas: Bool {
        canvasAspect > 1.05
    }

    init(
        title: String,
        image: UIImage,
        initialFraming: CropFraming,
        canvasSize: CGSize = CGSize(width: 390, height: 844),
        pairedSlotSyncLabel: String? = nil,
        onApply: @escaping (CropFraming, Bool) -> Void
    ) {
        self.title = title
        self.image = image
        self.initialFraming = initialFraming
        self.canvasSize = canvasSize
        self.pairedSlotSyncLabel = pairedSlotSyncLabel
        self.onApply = onApply
        let aspect = canvasSize.width / max(canvasSize.height, 1)
        _committed = State(initialValue: initialFraming.clamped(for: image.size, canvasAspect: aspect))
    }

    private func liveFraming(frameW: CGFloat, frameH: CGFloat) -> CropFraming {
        let minZoom: CGFloat = committed.allowEdgeExtend ? 0.70 : 1.0
        let rawZoom = min(max(committed.zoom * pinchScale, minZoom), 4.0)
        let scaleRatio = rawZoom / max(committed.zoom, 0.01)
        let raw = CropFraming(
            zoom: rawZoom,
            offsetX: committed.offsetX * scaleRatio + (dragDelta.width / max(frameW, 1)),
            offsetY: committed.offsetY * scaleRatio + (dragDelta.height / max(frameH, 1)),
            allowEdgeExtend: committed.allowEdgeExtend
        )
        return raw.clamped(for: image.size, canvasAspect: canvasAspect)
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                GeometryReader { geo in
                    let maxW = max(180, geo.size.width - 36)
                    let maxH = max(180, geo.size.height - 24)
                    let candidateW = maxH * canvasAspect
                    let frameW = candidateW <= maxW ? candidateW : maxW
                    let frameH = frameW / max(canvasAspect, 0.2)
                    let guideCorner = min(frameW, frameH) * (isLandscapeCanvas ? 0.075 : 0.145)
                    let live = liveFraming(frameW: frameW, frameH: frameH)
                    let baseScale = max(frameW / max(image.size.width, 1), frameH / max(image.size.height, 1))
                    let drawW = max(image.size.width, 1) * baseScale * live.zoom
                    let drawH = max(image.size.height, 1) * baseScale * live.zoom

                    ZStack {
                        // Dimmed outside-the-frame overflow preview so user sees full source boundaries
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: drawW, height: drawH)
                            .offset(x: live.offsetX * frameW, y: live.offsetY * frameH)
                            .opacity(0.28)
                            .allowsHitTesting(false)

                        // Clipped Lock Screen Viewport
                        ZStack {
                            if live.allowEdgeExtend {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: frameW, height: frameH)
                                    .blur(radius: 22)
                                    .overlay(Color.black.opacity(0.20))
                            } else {
                                Color.black
                            }

                            Image(uiImage: image)
                                .resizable()
                                .frame(width: drawW, height: drawH)
                                .offset(x: live.offsetX * frameW, y: live.offsetY * frameH)

                            // 3x3 Rule-of-Thirds hairline grid
                            ruleOfThirdsGrid(frameW: frameW, frameH: frameH)
                                .allowsHitTesting(false)

                            if showLockGuides {
                                lockScreenGuides(frameW: frameW, frameH: frameH)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(width: frameW, height: frameH)
                        .clipShape(RoundedRectangle(cornerRadius: guideCorner, style: .continuous))
                        .allowsHitTesting(false)

                        // Sharp viewport frame border
                        RoundedRectangle(cornerRadius: guideCorner, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                            .frame(width: frameW, height: frameH)
                            .allowsHitTesting(false)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { val in
                                guard !isPinching else { return }
                                isInteracting = true
                                dragDelta = val.translation
                            }
                            .onEnded { val in
                                guard !isPinching else {
                                    dragDelta = .zero
                                    return
                                }
                                dragDelta = val.translation
                                committed = liveFraming(frameW: frameW, frameH: frameH)
                                dragDelta = .zero
                                isInteracting = false
                            }
                    )
                    .simultaneousGesture(
                        MagnifyGesture(minimumScaleDelta: 0)
                            .onChanged { val in
                                if !isPinching {
                                    if dragDelta != .zero {
                                        committed = liveFraming(frameW: frameW, frameH: frameH)
                                        dragDelta = .zero
                                    }
                                    isPinching = true
                                    isInteracting = true
                                }
                                pinchScale = val.magnification
                            }
                            .onEnded { val in
                                pinchScale = val.magnification
                                committed = liveFraming(frameW: frameW, frameH: frameH)
                                pinchScale = 1.0
                                isPinching = false
                                isInteracting = false
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.26)) {
                            if !committed.isIdentity {
                                committed = .identity
                            } else {
                                committed = CropFraming(
                                    zoom: 1.55,
                                    offsetX: 0,
                                    offsetY: 0,
                                    allowEdgeExtend: committed.allowEdgeExtend
                                ).clamped(for: image.size, canvasAspect: canvasAspect)
                            }
                            dragDelta = .zero
                            pinchScale = 1.0
                            CamloHaptics.selection()
                        }
                    }
                }

                bottomControlDeck
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button(Bi("取消", "Cancel")) {
                dismiss()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .frame(minWidth: 56, alignment: .leading)

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(Bi("单指拖动挪位 · 双指捏合缩放", "Drag to move · Pinch to zoom"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button {
                showLockGuides.toggle()
                CamloHaptics.selection()
            } label: {
                Image(systemName: showLockGuides ? "eye.fill" : "eye.slash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 56, alignment: .trailing)
            }
            .accessibilityLabel(Bi("切换锁屏时间参考线", "Toggle Lock Screen guides"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func ruleOfThirdsGrid(frameW: CGFloat, frameH: CGFloat) -> some View {
        Path { path in
            for i in 1...2 {
                let x = frameW * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: frameH))

                let y = frameH * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: frameW, y: y))
            }
        }
        .stroke(Color.white.opacity(isInteracting ? 0.45 : 0.14), lineWidth: 0.75)
    }

    private func lockScreenGuides(frameW: CGFloat, frameH: CGFloat) -> some View {
        let guideRef = min(frameW, frameH)
        return VStack(spacing: 0) {
            // Dynamic Island
            Capsule(style: .continuous)
                .fill(Color.black)
                .frame(width: guideRef * (isLandscapeCanvas ? 0.22 : 0.30), height: guideRef * (isLandscapeCanvas ? 0.065 : 0.085))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                )
                .padding(.top, frameH * (isLandscapeCanvas ? 0.032 : 0.022))

            // Date & 09:41 Clock Reference
            VStack(spacing: 2) {
                Text(CamloDevice.formattedLockScreenDate())
                    .font(.system(size: guideRef * (isLandscapeCanvas ? 0.042 : 0.052), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)

                Text("09:41")
                    .font(.system(size: guideRef * (isLandscapeCanvas ? 0.195 : 0.255), weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .padding(.top, frameH * (isLandscapeCanvas ? 0.045 : 0.055))

            Spacer()

            // Bottom Flashlight / Camera Reference Zone
            VStack(spacing: 8) {
                HStack {
                    guideCircleIcon("flashlight.off.fill", frameW: guideRef)
                    Spacer()
                    Text(Bi("锁屏按钮参考区", "Lock Controls Area"))
                        .font(.system(size: max(9, guideRef * 0.038), weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.38), in: Capsule())
                    Spacer()
                    guideCircleIcon("camera.fill", frameW: guideRef)
                }
                .padding(.horizontal, frameW * (isLandscapeCanvas ? 0.06 : 0.09))

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.80))
                    .frame(width: guideRef * 0.36, height: max(3, guideRef * 0.014))
                    .padding(.bottom, frameH * 0.012)
            }
        }
    }

    private func guideCircleIcon(_ symbol: String, frameW: CGFloat) -> some View {
        Circle()
            .fill(Color.black.opacity(0.40))
            .frame(width: frameW * 0.125, height: frameW * 0.125)
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: frameW * 0.052, weight: .medium))
                    .foregroundStyle(.white.opacity(0.90))
            )
    }

    private var bottomControlDeck: some View {
        let minZoom: CGFloat = committed.allowEdgeExtend ? 0.70 : 1.00
        let zoomBinding = Binding<CGFloat>(
            get: { committed.zoom },
            set: { newZoom in
                let clampedZoom = min(max(newZoom, minZoom), 4.0)
                let ratio = clampedZoom / max(committed.zoom, 0.01)
                committed = CropFraming(
                    zoom: clampedZoom,
                    offsetX: committed.offsetX * ratio,
                    offsetY: committed.offsetY * ratio,
                    allowEdgeExtend: committed.allowEdgeExtend
                ).clamped(for: image.size, canvasAspect: canvasAspect)
            }
        )

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        committed = CropFraming(allowEdgeExtend: false)
                        dragDelta = .zero
                        pinchScale = 1.0
                    }
                    CamloHaptics.selection()
                } label: {
                    Label(Bi("重置居中", "Reset"), systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        committed.allowEdgeExtend.toggle()
                        committed = committed.clamped(for: image.size, canvasAspect: canvasAspect)
                    }
                    CamloHaptics.selection()
                } label: {
                    Label(Bi("超界自由挪动", "Free Move / Blur Fill"), systemImage: "arrow.up.and.down.and.sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(
                            (committed.allowEdgeExtend ? Color.accentColor : Color.white.opacity(0.12)),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    showLockGuides.toggle()
                    CamloHaptics.selection()
                } label: {
                    Label(Bi("时间参考", "Clock Guide"), systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(
                            (showLockGuides ? Color.white.opacity(0.24) : Color.white.opacity(0.10)),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            if committed.allowEdgeExtend {
                Text(Bi("开启后可将贴底人物继续往上提，边缘自动柔焦延展", "Lift bottom-edge subjects higher with seamless blurred edge fill"))
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
                Slider(value: zoomBinding, in: minZoom...3.00)
                    .tint(Color.accentColor)
                Text(String(format: "%.2f×", min(max(committed.zoom * pinchScale, minZoom), 4.0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 46, alignment: .trailing)
            }

            if let syncLabel = pairedSlotSyncLabel {
                Toggle(isOn: $syncToPaired) {
                    Text(syncLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .tint(Color.accentColor)
            }

            Button {
                let finalFraming = committed.clamped(for: image.size, canvasAspect: canvasAspect)
                CamloHaptics.impact(.medium)
                onApply(finalFraming, syncToPaired)
                dismiss()
            } label: {
                Text(Bi("完成裁剪", "Apply Crop"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color(red: 0.44, green: 0.32, blue: 0.96)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.black.opacity(0.45))
    }
}
