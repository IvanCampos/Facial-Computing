//
//  ImmersiveView.swift
//  Faceial Computing
//
//  Created by IVAN CAMPOS on 8/26/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
#if os(visionOS)
import ARKit
#endif

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "SkyDome", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }
            // Attach controls panel as a SwiftUI attachment in space.
            #if os(visionOS)
            let attachmentEntity = Entity()
            let attachment = ViewAttachmentComponent(rootView: ImmersiveControlsView())
            attachmentEntity.components.set(attachment)
            attachmentEntity.position = [0, 1.5, -1]
            content.add(attachmentEntity)
            #endif
        }
        .onAppear {
        }
        .onDisappear {
        }
    }
}

//#Preview(immersionStyle: .full) {
//    ImmersiveView()
//        .environment(AppModel())
//}
