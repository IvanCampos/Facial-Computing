//
//  ImmersiveControlsView.swift
//  Facial Computing
//
//  Created by IVAN CAMPOS on 8/26/25.
//

import SwiftUI

#if os(visionOS)
import RealityKit

/// Floating controls panel shown inside the ImmersiveSpace via a ViewAttachmentComponent.
struct ImmersiveControlsView: View {
    enum Demo: String, CaseIterable, Identifiable {
        case persona = "Persona"
        case vision = "Vision"
        case frame = "Frame"
        var id: String { rawValue }
    }

    @State private var selected: Demo = .persona

    // Controllers
    @State private var persona = PersonaCaptureController()
    @State private var vision = VisionExpressionController()
    @State private var isAnalyzing = false
    @State private var lastAnalysisTime: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Buttons row (scrollable for many demos)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Demo.allCases) { demo in
                        Button(action: {
                            Task { @MainActor in
                                await stopCurrentDemo()
                                selected = demo
                                await startSelectedDemo()
                            }
                        }) {
                            Text(demo.rawValue)
                                .font(.headline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selected == demo ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Demo content
            Group {
                switch selected {
                case .persona:
                    personaDemo
                case .vision:
                    visionDemo
                case .frame:
                    frameDemo
                }
            }
            .frame(minWidth: 560, minHeight: 420, alignment: .topLeading)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))

        }
        .padding(12)
        .onAppear {
            Task { @MainActor in
                await startSelectedDemo()
            }
        }
        .onDisappear {
            Task { @MainActor in
                await stopAll()
            }
        }
    }

    // MARK: - Individual demos

    private var personaDemo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(persona.isRunning ? "Stop Camera" : "Start Camera") {
                    Task { @MainActor in
                        if persona.isRunning {
                            persona.stop()
                        } else {
                            do { try await persona.start() } catch { }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                Text(persona.isRunning ? "Streaming…" : "Idle")
                    .foregroundStyle(persona.isRunning ? .green : .secondary)
            }
            PixelBufferView(pixelBuffer: persona.latestPixelBuffer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
        }
        .padding(12)
    }
    
    private var visionDemo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(persona.isRunning ? "Stop" : "Start") {
                    Task { @MainActor in
                        if persona.isRunning {
                            persona.stop()
                            vision.lastDetections = []
                        } else {
                            do { try await persona.start() } catch { }
                            persona.onFrame = { pixelBuffer, _ in
                                // Throttle to ~10 fps and prevent overlap
                                let now = CFAbsoluteTimeGetCurrent()
                                if isAnalyzing || (now - lastAnalysisTime) < 0.1 { return }
                                isAnalyzing = true
                                lastAnalysisTime = now
                                Task {
                                    _ = await vision.analyze(pixelBuffer: pixelBuffer)
                                    await MainActor.run { isAnalyzing = false }
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                Text(persona.isRunning ? (isAnalyzing ? "Analyzing…" : "Ready") : "Idle")
                    .foregroundStyle(persona.isRunning ? (isAnalyzing ? .yellow : .green) : .secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                PixelBufferView(pixelBuffer: persona.latestPixelBuffer)
                    .frame(width: 720, height: 405)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                if vision.lastDetections.isEmpty {
                    Text("Expressions will appear here.")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(vision.lastDetections, id: \.self) { d in
                                HStack {
                                    Text(d.emoji)
                                    Text(d.name)
                                    Spacer()
                                    Text(String(format: "%.0f%%", d.confidence * 100))
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    private var frameDemo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(persona.isRunning ? "Stop" : "Start") {
                    Task { @MainActor in
                        if persona.isRunning {
                            persona.onFrame = nil
                            persona.stop()
                            vision.lastDetections = []
                        } else {
                            do { try await persona.start() } catch { }
                            persona.onFrame = nil // ensure not analyzing continuously
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Analyze") {
                    Task {
                        if let pb = persona.latestPixelBuffer {
                            _ = await vision.analyze(pixelBuffer: pb)
                        }
                    }
                }
                .disabled(!(persona.isRunning && persona.latestPixelBuffer != nil))

                Text(persona.isRunning ? "Ready to analyze" : "Idle")
                    .foregroundStyle(persona.isRunning ? .green : .secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                PixelBufferView(pixelBuffer: persona.latestPixelBuffer)
                    .frame(width: 720, height: 405)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)

                if vision.lastDetections.isEmpty {
                    Text("Press Analyze to classify the current frame.")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(vision.lastDetections, id: \.self) { d in
                                HStack {
                                    Text(d.emoji)
                                    Text(d.name)
                                    Spacer()
                                    Text(String(format: "%.0f%%", d.confidence * 100))
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    // MARK: - Lifecycle helpers
    private func stopCurrentDemo() async {
        switch selected {
        case .persona:
            persona.stop()
        case .vision:
            persona.stop()
            vision.lastDetections = []
        case .frame:
            persona.stop()
            vision.lastDetections = []
        }
    }

    private func startSelectedDemo() async {
        switch selected {
        case .persona:
            try? await persona.start()
        case .vision:
            try? await persona.start()
            lastAnalysisTime = 0
            isAnalyzing = false
            persona.onFrame = { pixelBuffer, _ in
                let now = CFAbsoluteTimeGetCurrent()
                if isAnalyzing || (now - lastAnalysisTime) < 0.1 { return }
                isAnalyzing = true
                lastAnalysisTime = now
                Task {
                    _ = await vision.analyze(pixelBuffer: pixelBuffer)
                    await MainActor.run { isAnalyzing = false }
                }
            }
        case .frame:
            try? await persona.start()
            persona.onFrame = nil
        }
    }

    private func stopAll() async {
        persona.stop()
        vision.lastDetections = []
    }
}

#endif
