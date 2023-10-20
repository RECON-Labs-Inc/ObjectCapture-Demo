//
//  OnboardingState.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/19.
//

import Foundation

// States for transitioning the review screens.
enum OnboardingState: Equatable, Hashable {
    case dismiss
    case tooFewImages
    case firstSegment
    case firstSegmentNeedsWork
    case firstSegmentComplete
    case secondSegment
    case secondSegmentNeedsWork
    case secondSegmentComplete
    case thirdSegment
    case thirdSegmentNeedsWork
    case thirdSegmentComplete
    case flipObject
    case flipObjectASecondTime
    case flippingObjectNotRecommended
    case captureFromLowerAngle
    case captureFromHigherAngle
    case reconstruction
    case additionalOrbitOnCurrentSegment
}

// User input on the review screens.
enum OnboardingUserInput: Equatable {
    case `continue`(isFlippable: Bool)
    case skip(isFlippable: Bool)
    case finish
    case objectCannotBeFlipped
    case flipObjectAnyway
}
