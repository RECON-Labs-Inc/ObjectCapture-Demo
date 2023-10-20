//
//  OnboardingStateMachine.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/19.
//

import Foundation
import os

class OnboardingStateMachine: ObservableObject {
    
    static let logger = Logger(subsystem: ObjectCaptureProjectApp.subsystem,
                                category: "OnboardingStateMachine")

    let logger = OnboardingStateMachine.logger
    @Published var currentState: OnboardingState

    init(_ state: OnboardingState = .firstSegment) {
        guard initialStates.contains(state) else {
            currentState = .firstSegment
            return
        }
        currentState = state
    }
    
    func enter(_ input: OnboardingUserInput) -> Bool {
        let transitions = transitions(for: currentState)
        if transitions.isEmpty {
            let stateString = "\(currentState)"
            logger.debug("No transitions available for '\(stateString)'")
            return false
        }
        
        guard let destinationState = transitions.first(where: { $0.inputs.contains(where: { $0 == input }) })?.destination else {
            let stateString = "\(currentState)"
            let inputString = "\(input)"
            logger.debug("No transition from '\(stateString)' for: \(inputString)")
            return false
        }
        currentState = destinationState
        return true
    }
    
    func currentStateInputs() -> [OnboardingUserInput] {
        let transitions = transitions(for: currentState)

        return transitions.reduce([], { $0 + $1.inputs })
    }

    func reset(to state: OnboardingState) -> Bool {
        guard initialStates.contains(state) else {
            let stateString = "\(state)"
            logger.debug("Invalid internal state '\(stateString)'.")
            return false
        }

        currentState = state
        return true
    }
    
    // Allowed initial states.
    private let initialStates: [OnboardingState] = [.tooFewImages, .firstSegmentNeedsWork, .firstSegmentComplete,
                                                    .secondSegmentNeedsWork, .secondSegmentComplete,
                                                    .thirdSegmentNeedsWork, .thirdSegmentComplete]
    // State transitions based on the user input.
    typealias Transition = (inputs: [OnboardingUserInput], destination: OnboardingState)
    private let transitions: [OnboardingState: [Transition]] = [
        .tooFewImages: [(inputs: [.continue(isFlippable: true), .continue(isFlippable: false)], destination: .firstSegment)],

        .firstSegmentNeedsWork: [(inputs: [.continue(isFlippable: true), .continue(isFlippable: false)], destination: .firstSegment),
                                 (inputs: [.skip(isFlippable: true), .skip(isFlippable: false)], destination: .flipObject)],

        .firstSegmentComplete: [(inputs: [.finish], destination: .reconstruction),
                                (inputs: [.continue(isFlippable: true)], destination: .flipObject),
                                (inputs: [.continue(isFlippable: false)], destination: .flippingObjectNotRecommended)],

        .flipObject: [(inputs: [.continue(isFlippable: true), .continue(isFlippable: false)], destination: .secondSegment),
                      (inputs: [.objectCannotBeFlipped], destination: .captureFromLowerAngle)],

        .flippingObjectNotRecommended: [(inputs: [.continue(isFlippable: true), .continue(isFlippable: false)], destination: .captureFromLowerAngle),
                                        (inputs: [.flipObjectAnyway], destination: .flipObject)],

        .captureFromLowerAngle: [(inputs: [.finish], destination: .reconstruction),
                                 (inputs: [.continue(isFlippable: true), .continue(isFlippable: false)],
                                  destination: .additionalOrbitOnCurrentSegment)],

        .secondSegmentNeedsWork: [(inputs: [.continue(isFlippable: true), .continue(isFlippable: false)], destination: .dismiss),
                                  (inputs: [.skip(isFlippable: true)], destination: .flipObjectASecondTime),
                                  (inputs: [.skip(isFlippable: false)], destination: .captureFromHigherAngle)],

        .secondSegmentComplete: [(inputs: [.continue(isFlippable: true)], destination: .flipObjectASecondTime),
                                 (inputs: [.continue(isFlippable: false)], destination: .captureFromHigherAngle)],

        .flipObjectASecondTime: [(inputs: [.finish], destination: .reconstruction),
                                 (inputs: [.continue(isFlippable: true), .continue(isFlippable: false)], destination: .thirdSegment)],

        .captureFromHigherAngle: [(inputs: [.finish], destination: .reconstruction),
                                  (inputs: [.continue(isFlippable: true),
                                            .continue(isFlippable: false)],
                                   destination: .additionalOrbitOnCurrentSegment)],

        .thirdSegmentNeedsWork: [(inputs: [.finish], destination: .reconstruction),
                                 (inputs: [.continue(isFlippable: true), .continue(isFlippable: false)], destination: .dismiss)],

        .thirdSegmentComplete: [(inputs: [.finish], destination: .reconstruction)]
    ]

    private func transitions(for state: OnboardingState) -> [(inputs: [OnboardingUserInput], destination: OnboardingState)] {
        guard let transitions = transitions[state] else {
            let stateString = "\(state)"
            logger.debug("No transition exists for '\(stateString)'.")
            return []
        }

        return transitions
    }
    
}

