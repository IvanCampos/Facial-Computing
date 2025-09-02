//
//  Facial_ComputingApp.swift
//  Facial Computing
//
//  Created by IVAN CAMPOS on 9/2/25.
//

import SwiftUI

@main
struct Facial_ComputingApp: App {
    
    @State private var appModel = AppModel()
    
    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environment(appModel)
//        }
//        .defaultSize(width: 400, height: 200)
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
