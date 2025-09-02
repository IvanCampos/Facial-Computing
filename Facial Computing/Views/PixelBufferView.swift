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
            cgImage = PixelBufferView.makeCGImage(from: newValue)
        }
        .onAppear {
            cgImage = PixelBufferView.makeCGImage(from: pixelBuffer)
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
}
#endif

