//
//  ContentView.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/17.
//

import Combine
import SwiftUI
import RealityKit
import os


@available(iOS 17.0, *)
struct ContentView: View {
    static let logger = Logger(subsystem: ObjectCaptureProjectApp.subsystem,
                                category: "ContentView")
    @StateObject var appModel: AppDataModel = AppDataModel.instance
    
    @State private var showReconstructionView: Bool = false
    @State private var showErrorAlert: Bool = false
    private var showProgressView: Bool {
        appModel.state == .completed || appModel.state == .restart || appModel.state == .ready
    }
    
    var body: some View {
        
        VStack {
            if appModel.state == .capturing {
                if let session = appModel.session {
                    CapturePrimaryView(session: session)
                }
            } else if showProgressView {
                CircularProgressView()
            }
        }
        .onChange(of: appModel.state) { _, newValue in
            if newValue == .failed {
                showErrorAlert = true
                showReconstructionView = false
            } else {
                showErrorAlert = false
                showReconstructionView = newValue == .reconstructing || newValue == .viewing
            }
        }
        .sheet(isPresented: $showReconstructionView) {
            if let folderManager = appModel.scanFolderManager {
                
            }
        }
        .alert(
            "Failed:  " + (appModel.error != nil  ? "\(String(describing: appModel.error!))" : ""),
            isPresented: $showErrorAlert,
            actions: {
                Button("OK") {
                    ContentView.logger.log("Calling restart...")
                    appModel.state = .restart
                }
            },
            message: {}
        )
        .environmentObject(appModel)
        
        
    }
}

