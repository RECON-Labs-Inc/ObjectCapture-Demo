//
//  CaptureOverlayView.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/19.
//

import Foundation
import RealityKit
import SwiftUI

struct CaptureOverlayView: View {
    
    @EnvironmentObject var appModel: AppDataModel
    var session: ObjectCaptureSession
    
    @State private var hasDetectionFailed = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CancelButton()
                    .disabled(shouldDisableCancelButton ? true : false)
                Spacer()
                NextButton()
                    .opacity(shouldShowNextButton ? 1 : 0)
                    .disabled(!shouldShowNextButton)
            }
            .foregroundColor(.white)
            
            Spacer()
            
            if !capturingStarted {
                BoundingBoxGuidanceView(session: session, hasDetectionFailed: hasDetectionFailed)
            }
            
            HStack(alignment: .bottom, spacing: 0) {
                HStack(spacing: 0) {
                    if case .capturing = session.state {
                        NumOfImagesButton(session: session)
                            .rotationEffect(rotationAngle)
                            .transition(.opacity)
                    } else if case .detecting = session.state {
                        ResetBoundingBoxButton(session: session)
                            .transition(.opacity)
                    } else if case .ready = session.state {
                        FilesButton()
                            .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                if !capturingStarted {
                    CaptureButton(session: session, isObjectFlipped: appModel.isObjectFlipped, hasDetectionFailed: $hasDetectionFailed)
                        .layoutPriority(1)
                }
                
                HStack {
                    Spacer()
                    
                    if case .capturing = session.state {
                        ManualShotButton(session: session)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                
                
            }
            
        }
        .padding()
        .padding(.horizontal, 15)
        .background(.clear)
        
    }
    
    private var capturingStarted: Bool {
        switch session.state {
            case .initializing, .ready, .detecting:
                return false
            default:
                return true
        }
    }
    
    private var shouldShowNextButton: Bool {
        capturingStarted
    }

    private var shouldDisableCancelButton: Bool {
       session.state == .ready || session.state == .initializing
    }

    private var rotationAngle: Angle {
        switch deviceOrientation {
            case .landscapeLeft:
                return Angle(degrees: 90)
            case .landscapeRight:
                return Angle(degrees: -90)
            case .portraitUpsideDown:
                return Angle(degrees: 180)
            default:
                return Angle(degrees: 0)
        }
    }
    
}

@MainActor
private struct BoundingBoxGuidanceView: View {
    var session: ObjectCaptureSession
    var hasDetectionFailed: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack {
            if let guidanceText = guidanceText {
                Text(guidanceText)
                    .font(.callout)
                    .bold()
                    .foregroundColor(.white)
                    .transition(.opacity)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 400 : 360)
            }
        }
    }

    private var guidanceText: String? {
        if case .ready = session.state {
            if hasDetectionFailed {
                return NSLocalizedString(
                    "Can‘t find your object. It should be larger than 3in (8cm) in each dimension.",
                    bundle: AppDataModel.bundleForLocalizedStrings,
                    value: "Can‘t find your object. It should be larger than 3in (8cm) in each dimension.",
                    comment: "Feedback message when detection has failed.")
            } else {
                return NSLocalizedString(
                    "Move close and center the dot on your object, then tap Continue. (Object Capture, State)",
                    bundle: AppDataModel.bundleForLocalizedStrings,
                    value: "Move close and center the dot on your object, then tap Continue.",
                    comment: "Feedback message to fill camera feed with object.")
            }
        } else if case .detecting = session.state {
            return NSLocalizedString(
                "Move around to ensure that the whole object is inside the box. Drag handles to manually resize. (Object Capture, State)",
                bundle: AppDataModel.bundleForLocalizedStrings,
                value: "Move around to ensure that the whole object is inside the box. Drag handles to manually resize.",
                comment: "Feedback message to size box to object.")
        } else {
            return nil
        }
    }
}
