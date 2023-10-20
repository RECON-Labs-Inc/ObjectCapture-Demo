//
//  CapturePrimaryView.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/19.
//

import Foundation
import RealityKit
import SwiftUI

struct CapturePrimaryView: View {
    @EnvironmentObject var appModel: AppDataModel
    var session:ObjectCaptureSession
    
    @State var showInfo: Bool = false
    @State private var showOnboardingView:Bool = false
    private var shouldShowOverlayView: Bool {
        !appModel.showPreviewModel && !session.isPaused && session.cameraTracking == .normal
    }
    
    var body: some View {
        ZStack {
            ObjectCaptureView(session: session,
                              cameraFeedOverlay: { GradientBackground() })
            .blur(radius: appModel.showPreviewModel ? 45 : 0)
            .transition(.opacity)
            if shouldShowOverlayView {
                CaptureOverlayView(session: session)
            }
        }
        .sheet(isPresented: $showOnboardingView,
               onDismiss: { [weak appModel] in appModel?.setPreviewModelState(shown: false) }) { [weak appModel] in
            if let appModel = appModel, let onboardingState = appModel.determineCurrentOnboardingState() {
                OnboardingView(state: onboardingState)
            }
        }
        .task {
            for await userCompletedScanPass in session.userCompletedScanPassUpdates where userCompletedScanPass {
                appModel.setPreviewModelState(shown: true)
            }
        }
        .onChange(of: appModel.showPreviewModel, { _, showPreviewModel in
            if !showInfo {
                showOnboardingView = showPreviewModel
            }
        })
        .onChange(of: showInfo) {
            appModel.setPreviewModelState(shown: showInfo)
        }
        .onAppear(perform: {
            UIApplication.shared.isIdleTimerDisabled = true
        })
        .onDisappear(perform: {
            UIApplication.shared.isIdleTimerDisabled = false
        })
        .id(session.id)
    }
    
    
}

private struct GradientBackground: View {
    private let gradient = LinearGradient(
        colors: [.black.opacity(0.4), .clear],
        startPoint: .top,
        endPoint: .bottom
    )
    private let frameHeight: CGFloat = 300

    var body: some View {
        VStack {
            gradient
                .frame(height: frameHeight)

            Spacer()

            gradient
                .rotation3DEffect(Angle(degrees: 180), axis: (x: 1, y: 0, z: 0))
                .frame(height: frameHeight)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
