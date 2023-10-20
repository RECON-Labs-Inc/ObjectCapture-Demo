//
//  OnboardingView.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/19.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appModel:AppDataModel
    @StateObject private var stateMachine:OnboardingStateMachine
    @Environment(\.colorScheme) private var colorScheme
    
    private var isFinishingOrCompleted:Bool {
        guard let session = appModel.session else { return true }
        return session.state == .finishing || session.state == .completed
    }
                         
    init(state: OnboardingState) {
        _stateMachine = StateObject(wrappedValue: OnboardingStateMachine(state))
    }
    
    
    var body: some View {
        ZStack {
            Color(colorScheme == .light ? .white : .black).ignoresSafeArea()
            if let session = appModel.session {
                OnboardingTutorialView(session: session, onboardingStateMachine: stateMachine)
                OnboardingButtonView(session: session, onboardingStateMachine: stateMachine)
            }
        }
        //sheet를 닫게 도와주는 친구
        .interactiveDismissDisabled(appModel.session?.userCompletedScanPass ?? false)
        .allowsHitTesting(!isFinishingOrCompleted)
    }
}
