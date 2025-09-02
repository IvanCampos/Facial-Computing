//
//  PersonaCaptureController.swift
//  Facial Computing
//
//  Created by IVAN CAMPOS on 8/26/25.
//

import Foundation

#if os(visionOS)
import AVFoundation

/// Streams frames from the front camera (user-facing) for the user's persona.
/// Provides start/stop control and a live frame stream via callback or AsyncStream.
@MainActor
@Observable
final class PersonaCaptureController: NSObject {
    enum CaptureError: Error, LocalizedError {
        case cameraUnavailable
        case cameraNotAuthorized
        case configurationFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "No front camera available."
            case .cameraNotAuthorized: return "Camera access is not authorized."
            case .configurationFailed: return "Failed to configure capture session."
            }
        }
    }

    // Public state
    var isRunning: Bool = false
    var latestPixelBuffer: CVPixelBuffer?

    // Optional per-frame callback
    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?

    // AsyncStream support
    private var frameContinuation: AsyncStream<CVPixelBuffer>.Continuation?
    func frameStream() -> AsyncStream<CVPixelBuffer> {
        frameContinuation?.finish()
        return AsyncStream<CVPixelBuffer> { continuation in
            self.frameContinuation = continuation
        }
    }

    // Private capture members
    private let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "PersonaCaptureController.VideoOutput")

    /// Starts capture from the front camera. Requests permission if needed.
    func start() async throws {
        // Ensure camera permission
        let granted = await Permissions.requestCameraIfNeeded()
        guard granted else { throw CaptureError.cameraNotAuthorized }

        // Configure only once or reconfigure if needed
        try configureSession()
        if !session.isRunning {
            session.startRunning()
        }
        isRunning = session.isRunning
    }

    /// Stops capture and tears down outputs.
    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
        isRunning = false
    }

    private func configureSession() throws {
        session.beginConfiguration()
        
        // Remove existing input/output
        if let input = videoInput {
            session.removeInput(input)
            videoInput = nil
        }
        if session.outputs.contains(videoOutput) {
            session.removeOutput(videoOutput)
        }

        // Find a front camera
        guard let device = frontCameraDevice() else {
            session.commitConfiguration()
            throw CaptureError.cameraUnavailable
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input); videoInput = input }
            else { throw CaptureError.configurationFailed }
        } catch {
            session.commitConfiguration()
            throw CaptureError.configurationFailed
        }

        // Configure output
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            session.commitConfiguration()
            throw CaptureError.configurationFailed
        }
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        session.commitConfiguration()
    }

    private func frontCameraDevice() -> AVCaptureDevice? {
        // Try TrueDepth first, then wide angle, both front-facing
        let types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .front)
        return discovery.devices.first
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension PersonaCaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        Task { @MainActor in
            self.latestPixelBuffer = pixelBuffer
            self.onFrame?(pixelBuffer, ts)
            self.frameContinuation?.yield(pixelBuffer)
        }
    }
}
#endif
