# Facial Computing

Concise overview of the repository, with each project file and its responsibility.

## File Overview

- `README.md`: Project overview and file responsibilities (this document).
- `.gitignore`: Standard Swift/Xcode ignores (DerivedData, .build, etc.).
- `.DS_Store`: macOS Finder metadata (ignored by Git).
- `.git/`: Git metadata for version control.
- `Facial Computing.xcodeproj/`: Xcode project for building and running the app.
- `Packages/`: Swift Package Manager dependencies and resources.
  - `RealityKitContent/`: Local SPM package that provides RealityKit assets and a convenience bundle constant.
    - `Package.swift`: SPM manifest for the `RealityKitContent` package.
    - `Sources/RealityKitContent/RealityKitContent.swift`: Exposes `realityKitContentBundle` for loading assets.
    - `Sources/RealityKitContent/RealityKitContent.rkassets/SkyDome.usdz`: Sky dome model used by the immersive scene.
    - `Sources/RealityKitContent/RealityKitContent.rkassets/Immersive.usda`: Scene description used by Reality Composer Pro.
    - `Package.realitycomposerpro/`: Reality Composer Pro project data.

### App Target: Facial Computing

- `Facial Computing/Info.plist`: App configuration; declares immersive space scene role and camera usage descriptions.
- `Facial Computing/Facial_ComputingApp.swift`: App entry point. Creates the `ImmersiveSpace` scene and manages its lifecycle and immersion style.
- `Facial Computing/AppModel.swift`: App-wide observable state, including the immersive space identifier and open/closed state machine.
- `Facial Computing/ToggleImmersiveSpaceButton.swift`: SwiftUI button to open/dismiss the immersive space via environment actions.
- `Facial Computing/Permissions.swift`: Centralized camera permission helpers using AVFoundation.

#### Controllers

- `Facial Computing/Controllers/PersonaCaptureController.swift`: Manages AVFoundation capture from the front camera; exposes latest `CVPixelBuffer`, start/stop, per-frame callbacks, and an `AsyncStream` of frames.
- `Facial Computing/Controllers/VisionExpressionController.swift`: Uses Vision face landmarks to infer facial expressions (e.g., blinks, smiles); provides a simple detection model with confidence scores.

#### Views

- `Facial Computing/Views/ContentView.swift`: Primary window UI; currently hosts the immersive space toggle button.
- `Facial Computing/Views/ImmersiveView.swift`: RealityKit `RealityView` for the immersive experience; loads `SkyDome` from `RealityKitContent` and attaches a floating controls panel.
- `Facial Computing/Views/ImmersiveControlsView.swift`: Floating SwiftUI controls surface shown inside space via `ViewAttachmentComponent`; starts/stops camera capture and runs live/frame-by-frame expression analysis.
- `Facial Computing/Views/PixelBufferView.swift`: Efficiently converts and previews `CVPixelBuffer` frames as images with throttling.

#### Assets

- `Facial Computing/Assets.xcassets/`: App image and color assets managed by Xcode.

## Build & Run

Open `Facial Computing.xcodeproj` in Xcode (visionOS 26 SDK). Select the Apple Vision Pro simulator or device and run.

## Notes

- The immersive scene uses `RealityView` (visionOS-appropriate) and loads assets from the local `RealityKitContent` package.
- Camera access is requested at runtime; see `Info.plist` usage descriptions and `Permissions.swift` for logic.
