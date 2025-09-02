//
//  Permissions.swift
//  Facial Computing
//
//  Created by IVAN CAMPOS on 8/26/25.
//

import Foundation

#if os(visionOS)
import AVFoundation

/// Centralized permission requests for camera and microphone.
@MainActor
enum Permissions {
    /// Returns `true` if camera is authorized.
    static func isCameraAuthorized() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Requests camera access if status is `.notDetermined` and returns whether it is authorized.
    static func requestCameraIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            return granted
        default:
            return false
        }
    }

}
#endif
