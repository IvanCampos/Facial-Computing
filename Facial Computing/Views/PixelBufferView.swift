//
//  PixelBufferView.swift
//  Facial Computing
//
//  Created by IVAN CAMPOS on 8/26/25.
//

import SwiftUI
import CoreImage
import VideoToolbox

#if os(visionOS)
/// Renders a CVPixelBuffer as an Image.
struct PixelBufferView: View {
    let pixelBuffer: CVPixelBuffer?
    @State private var cgImage: CGImage?
    @State private var lastUpdateTime: TimeInterval = 0

    var body: some View {
        ZStack {
            if let cgImage {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.black.opacity(0.2)
                Text("No Video")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: pixelBuffer) { _, newValue in
            let now = CFAbsoluteTimeGetCurrent()
            // Throttle preview conversions to ~20 fps
            guard (now - lastUpdateTime) >= 0.05 else { return }
            lastUpdateTime = now
            Task {
                let img = await PixelBufferView.makeCGImageAsync(from: newValue)
                await MainActor.run { cgImage = img }
            }
        }
        .onAppear {
            Task {
                let img = await PixelBufferView.makeCGImageAsync(from: pixelBuffer)
                await MainActor.run { cgImage = img }
            }
        }
    }

    private static let ciContext = CIContext(options: nil)

    static func makeCGImage(from pb: CVPixelBuffer?) -> CGImage? {
        guard let pb else { return nil }
        var cg: CGImage?
        // Try VideoToolbox fast path
        let status = VTCreateCGImageFromCVPixelBuffer(pb, options: nil, imageOut: &cg)
        if status == noErr, let cg { return cg }
        // Fallback to CoreImage
        let ci = CIImage(cvPixelBuffer: pb)
        return ciContext.createCGImage(ci, from: ci.extent)
    }

    static func makeCGImageAsync(from pb: CVPixelBuffer?) async -> CGImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let img = makeCGImage(from: pb)
                continuation.resume(returning: img)
            }
        }
    }
}
#endif
