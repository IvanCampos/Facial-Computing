//
//  VisionExpressionController.swift
//  Facial Computing
//
//  Created by IVAN CAMPOS on 8/26/25.
//

import Foundation
import CoreGraphics

#if os(visionOS)
import Vision

/// Detects facial expressions from a CVPixelBuffer using Vision face landmarks.
@Observable
final class VisionExpressionController {

    struct Detection: Hashable {
        let name: String
        let emoji: String
        let confidence: Double
    }

    /// Expressions supported and their emoji mapping.
    enum Expression: String, CaseIterable {
        case eyesClosed = "Eyes Closed"
        case leftBlink = "Left Blink"
        case rightBlink = "Right Blink"
        case eyesSquint = "Eyes Squint"
        case leftEyeSquint = "Left Eye Squint"
        case rightEyeSquint = "Right Eye Squint"
        case eyesWiden = "Eyes Widen"
        case gazeLeft = "Gaze Left"
        case gazeRight = "Gaze Right"
        case gazeUp = "Gaze Up"
        case gazeDown = "Gaze Down"
        case bothBrowsRaised = "Both Brows Raised"
        case leftBrowRaise = "Left Brow Raise"
        case rightBrowRaise = "Right Brow Raise"
        case leftBrowLowered = "Left Brow Lowered"
        case rightBrowLowered = "Right Brow Lowered"
        case browFurrow = "Brow Furrow"
        case mouthOpenWide = "Mouth Open (Wide)"
        case lipsParted = "Lips Parted"
        case lipPress = "Lip Press"
        case lipPucker = "Lip Pucker"
        case mouthStretch = "Mouth Stretch"
        case leftSmirk = "Left Smirk"
        case rightSmirk = "Right Smirk"
        case leftCornerDownturn = "Left Corner Downturn"
        case rightCornerDownturn = "Right Corner Downturn"
        case smile = "Smile"
        case frown = "Frown"
        case upperLipRaise = "Upper Lip Raise"
        case nostrilFlare = "Nostril Flare"

        var emoji: String { switch self {
            case .eyesClosed: return "😴"
            case .leftBlink, .rightBlink: return "😉"
            case .eyesSquint: return "😑"
            case .leftEyeSquint, .rightEyeSquint: return "😒"
            case .eyesWiden: return "😮"
            case .gazeLeft: return "👈"
            case .gazeRight: return "👉"
            case .gazeUp: return "👆"
            case .gazeDown: return "👇"
            case .bothBrowsRaised: return "😯"
            case .leftBrowRaise, .rightBrowRaise: return "🤨"
            case .leftBrowLowered, .rightBrowLowered: return "😠"
            case .browFurrow: return "🤔"
            case .mouthOpenWide: return "😲"
            case .lipsParted: return "😗"
            case .lipPress: return "😬"
            case .lipPucker: return "😘"
            case .mouthStretch: return "😦"
            case .leftSmirk, .rightSmirk: return "😏"
            case .leftCornerDownturn, .rightCornerDownturn: return "🙁"
            case .smile: return "😁"
            case .frown: return "☹️"
            case .upperLipRaise: return "😤"
            case .nostrilFlare: return "😤"
        } }
    }

    // Output
    var lastDetections: [Detection] = []

    /// Analyze a frame and return detected expressions.
    func analyze(pixelBuffer: CVPixelBuffer) async -> [Detection] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            await MainActor.run { self.lastDetections = [] }
            return []
        }
        guard let face = (request.results)?.first,
              let landmarks = face.landmarks else {
            await MainActor.run { self.lastDetections = [] }
            return []
        }

        var detections = Set<Expression>()
        var confidence: [Expression: Double] = [:]

        // Eyes open/closed/squint/widen
        if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
            let (lAR, lW) = eyeAspectRatio(leftEye)
            let (rAR, rW) = eyeAspectRatio(rightEye)
            let arAvg = (lAR + rAR) / 2
            if arAvg < CGFloat(0.10) { detections.insert(.eyesClosed); confidence[.eyesClosed] = 1 - (arAvg / CGFloat(0.10)) }
            if lAR < CGFloat(0.10) && rAR >= CGFloat(0.10) { detections.insert(.leftBlink); confidence[.leftBlink] = 1 - (lAR / CGFloat(0.10)) }
            if rAR < CGFloat(0.10) && lAR >= CGFloat(0.10) { detections.insert(.rightBlink); confidence[.rightBlink] = 1 - (rAR / CGFloat(0.10)) }
            if arAvg < CGFloat(0.16) { detections.insert(.eyesSquint); confidence[.eyesSquint] = min(1, (CGFloat(0.16) - arAvg)/CGFloat(0.16)) }
            if lAR < CGFloat(0.16) { detections.insert(.leftEyeSquint); confidence[.leftEyeSquint] = min(1, (CGFloat(0.16) - lAR)/CGFloat(0.16)) }
            if rAR < CGFloat(0.16) { detections.insert(.rightEyeSquint); confidence[.rightEyeSquint] = min(1, (CGFloat(0.16) - rAR)/CGFloat(0.16)) }
            if arAvg > CGFloat(0.32) { detections.insert(.eyesWiden); confidence[.eyesWiden] = min(1, (arAvg - CGFloat(0.32))/CGFloat(0.5)) }

            // Gaze using pupil relative to eye bbox center
            if let lp = landmarks.leftPupil?.normalizedPoints.first, let rp = landmarks.rightPupil?.normalizedPoints.first {
                let lBox = bbox(leftEye)
                let rBox = bbox(rightEye)
                let lCenter = CGPoint(x: (lBox.minX + lBox.maxX)/2, y: (lBox.minY + lBox.maxY)/2)
                let rCenter = CGPoint(x: (rBox.minX + rBox.maxX)/2, y: (rBox.minY + rBox.maxY)/2)
                let lOffX = (lp.x - lCenter.x) / max(CGFloat(0.001), lW)
                let rOffX = (rp.x - rCenter.x) / max(CGFloat(0.001), rW)
                let lOffY = (lp.y - lCenter.y) / max(CGFloat(0.001), (lBox.maxY - lBox.minY))
                let rOffY = (rp.y - rCenter.y) / max(CGFloat(0.001), (rBox.maxY - rBox.minY))
                let offX = (lOffX + rOffX)/2
                let offY = (lOffY + rOffY)/2
                if offX < -CGFloat(0.20) { detections.insert(.gazeLeft); confidence[.gazeLeft] = min(1, abs(offX)/CGFloat(0.4)) }
                if offX > CGFloat(0.20) { detections.insert(.gazeRight); confidence[.gazeRight] = min(1, abs(offX)/CGFloat(0.4)) }
                if offY > CGFloat(0.20) { detections.insert(.gazeUp); confidence[.gazeUp] = min(1, abs(offY)/CGFloat(0.4)) }
                if offY < -CGFloat(0.20) { detections.insert(.gazeDown); confidence[.gazeDown] = min(1, abs(offY)/CGFloat(0.4)) }
            }
        }

        // Brows
        if let lBrow = landmarks.leftEyebrow, let rBrow = landmarks.rightEyebrow,
           let lEye = landmarks.leftEye, let rEye = landmarks.rightEye {
            let lEyeTop = bbox(lEye).maxY
            let rEyeTop = bbox(rEye).maxY
            let lBrowY = avgY(lBrow)
            let rBrowY = avgY(rBrow)
            let lDelta = lBrowY - lEyeTop
            let rDelta = rBrowY - rEyeTop
            if lDelta > 0.12 && rDelta > 0.12 { detections.insert(.bothBrowsRaised); confidence[.bothBrowsRaised] = min(1, max(lDelta, rDelta)) }
            if lDelta > 0.12 { detections.insert(.leftBrowRaise); confidence[.leftBrowRaise] = min(1, lDelta) }
            if rDelta > 0.12 { detections.insert(.rightBrowRaise); confidence[.rightBrowRaise] = min(1, rDelta) }
            if lDelta < 0.04 { detections.insert(.leftBrowLowered); confidence[.leftBrowLowered] = min(1, (0.04 - lDelta)/0.04) }
            if rDelta < 0.04 { detections.insert(.rightBrowLowered); confidence[.rightBrowLowered] = min(1, (0.04 - rDelta)/0.04) }

            // Furrow: inner brow distance small
            let innerGap = max(0.0, bbox(rBrow).minX - bbox(lBrow).maxX)
            if innerGap < 0.06 { detections.insert(.browFurrow); confidence[.browFurrow] = min(1, (0.06 - innerGap)/0.06) }
        }

        // Mouth related
        if let outer = landmarks.outerLips {
            let mbox = bbox(outer)
            let mouthWidth = mbox.maxX - mbox.minX
            let centerY = (mbox.minY + mbox.maxY)/2
            let leftCorner = pointWithMinX(outer)
            let rightCorner = pointWithMaxX(outer)

            if let inner = landmarks.innerLips {
                let ibox = bbox(inner)
                let open = (ibox.maxY - ibox.minY) / max(0.001, mouthWidth)
                if open > 0.45 { detections.insert(.mouthOpenWide); confidence[.mouthOpenWide] = min(1, (open - 0.45)/0.4) }
                if open > 0.12 { detections.insert(.lipsParted); confidence[.lipsParted] = min(1, (open - 0.12)/0.2) }
                if open < 0.03 { detections.insert(.lipPress); confidence[.lipPress] = min(1, (0.03 - open)/0.03) }

                // Upper lip raise: inner top near nose (higher than center significantly)
                let upperLipY = maxYOfUpperLip(inner)
                if (upperLipY - centerY) > 0.10 { detections.insert(.upperLipRaise); confidence[.upperLipRaise] = min(1, ((upperLipY - centerY) - 0.10)/0.2) }
            }

            // Pucker vs stretch via width
            if mouthWidth < 0.28 { detections.insert(.lipPucker); confidence[.lipPucker] = min(1, (0.28 - mouthWidth)/0.2) }
            if mouthWidth > 0.50 { detections.insert(.mouthStretch); confidence[.mouthStretch] = min(1, (mouthWidth - 0.50)/0.3) }

            // Corner deltas (smile/frown/smirk/downturn)
            let leftDy = leftCorner.y - centerY
            let rightDy = rightCorner.y - centerY

            // Heuristics tuned for Vision's normalized face space:
            // Use average corner lift/drop and lower thresholds for better sensitivity.
            let avgDy = (leftDy + rightDy) / 2
            let smileThreshold: CGFloat = 0.03
            let frownThreshold: CGFloat = 0.03

            // Smile: both corners rise relative to mouth center
            if leftDy > smileThreshold && rightDy > smileThreshold {
                detections.insert(.smile)
                // Map avgDy beyond threshold into 0..1
                let score = max(0, avgDy - smileThreshold)
                confidence[.smile] = min(1, Double(score / 0.15))
            }
            // Frown: both corners drop relative to mouth center
            if leftDy < -frownThreshold && rightDy < -frownThreshold {
                detections.insert(.frown)
                let score = max(0, (-avgDy) - frownThreshold)
                confidence[.frown] = min(1, Double(score / 0.15))
            }
            // Smirks: one corner raised notably, other near neutral
            if leftDy > (smileThreshold + 0.05) && rightDy < (smileThreshold * 0.6) {
                detections.insert(.leftSmirk)
                confidence[.leftSmirk] = min(1, Double((leftDy - smileThreshold) / 0.2))
            }
            if rightDy > (smileThreshold + 0.05) && leftDy < (smileThreshold * 0.6) {
                detections.insert(.rightSmirk)
                confidence[.rightSmirk] = min(1, Double((rightDy - smileThreshold) / 0.2))
            }
            // Corner downturns: individual corners pulled down
            if leftDy < -(frownThreshold + 0.05) {
                detections.insert(.leftCornerDownturn)
                confidence[.leftCornerDownturn] = min(1, Double((abs(leftDy) - frownThreshold) / 0.2))
            }
            if rightDy < -(frownThreshold + 0.05) {
                detections.insert(.rightCornerDownturn)
                confidence[.rightCornerDownturn] = min(1, Double((abs(rightDy) - frownThreshold) / 0.2))
            }
        }

        // Nostril flare is difficult without nostril landmarks; not inferred here.

        // Convert to Detection list
        let result = detections.map { expr in
            Detection(name: expr.rawValue, emoji: expr.emoji, confidence: confidence[expr] ?? 0.5)
        }
        .sorted { $0.name < $1.name }
        await MainActor.run {
            self.lastDetections = result
        }
        return result
    }

    // MARK: - Geometry helpers
    private func bbox(_ region: VNFaceLandmarkRegion2D) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        for p in region.normalizedPoints {
            minX = Swift.min(minX, p.x); maxX = Swift.max(maxX, p.x)
            minY = Swift.min(minY, p.y); maxY = Swift.max(maxY, p.y)
        }
        return (minX, maxX, minY, maxY)
    }

    private func avgY(_ region: VNFaceLandmarkRegion2D) -> CGFloat {
        guard region.pointCount > 0 else { return 0 }
        let sum = region.normalizedPoints.reduce(0) { $0 + $1.y }
        return sum / CGFloat(region.pointCount)
    }

    private func pointWithMinX(_ region: VNFaceLandmarkRegion2D) -> CGPoint {
        region.normalizedPoints.min(by: { $0.x < $1.x }) ?? .zero
    }
    private func pointWithMaxX(_ region: VNFaceLandmarkRegion2D) -> CGPoint {
        region.normalizedPoints.max(by: { $0.x < $1.x }) ?? .zero
    }

    private func eyeAspectRatio(_ eye: VNFaceLandmarkRegion2D) -> (CGFloat, CGFloat) {
        // Compute eye bounding box aspect ratio height/width as openness proxy
        let box = bbox(eye)
        let width = max(0.001, box.maxX - box.minX)
        let height = max(0.0, box.maxY - box.minY)
        return (height / width, width)
    }

    private func maxYOfUpperLip(_ innerLips: VNFaceLandmarkRegion2D) -> CGFloat {
        // Approximate: take the max y among upper half points (x between 0.25..0.75 of mouth box)
        let box = bbox(innerLips)
        let left = box.minX + 0.25 * (box.maxX - box.minX)
        let right = box.maxX - 0.25 * (box.maxX - box.minX)
        var maxY: CGFloat = -.greatestFiniteMagnitude
        for p in innerLips.normalizedPoints where p.x >= left && p.x <= right {
            maxY = Swift.max(maxY, p.y)
        }
        return maxY.isFinite ? maxY : (box.maxY)
    }
}
#endif
