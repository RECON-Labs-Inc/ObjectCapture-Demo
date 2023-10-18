//
//  AppDataModel.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/17.
//

import os
import Combine
import RealityKit
import SwiftUI


@MainActor
@available(iOS 17.0, *)
class AppDataModel: ObservableObject {
    
    static let instance = AppDataModel()
    static let bundleForLocalizedStrings = { return Bundle.main }()
    
    @Published var session: ObjectCaptureSession? {
        willSet {
            
        }
        
        didSet {
            
        }
    }
    
    @Published var state: ModelState = .notSet
    
    private init() {
        
    }
}

extension AppDataModel {
    
    enum Orbit: Int, CaseIterable, Identifiable, Comparable {
        case orbit1, orbit2, orbit3

        var id: Int {
            rawValue
        }

        var image: String {
            let imagesByIndex = ["1.circle", "2.circle", "3.circle"]
            return imagesByIndex[id]
        }

        var imageSelected: String {
            let imagesByIndex = ["1.circle.fill", "2.circle.fill", "3.circle.fill"]
            return imagesByIndex[id]
        }

        func next() -> Self {
            let currentIndex = Self.allCases.firstIndex(of: self)!
            let nextIndex = Self.allCases.index(after: currentIndex)
            return Self.allCases[nextIndex == Self.allCases.endIndex ? Self.allCases.endIndex - 1 : nextIndex]
        }

        func feedbackString(isObjectFlippable: Bool) -> String {
            switch self {
                case .orbit1:
                    return LocString.segment1FeedbackString
                case .orbit2, .orbit3:
                    if isObjectFlippable {
                        return LocString.segment2And3FlippableFeedbackString
                    } else {
                        if case .orbit2 = self {
                            return LocString.segment2UnflippableFeedbackString
                        }
                        return LocString.segment3UnflippableFeedbackString
                    }
            }
        }

        func feedbackVideoName(for interfaceIdiom: UIUserInterfaceIdiom, isObjectFlippable: Bool) -> String {
            switch self {
                case .orbit1:
                    return interfaceIdiom == .pad ? "ScanPasses-iPad-FixedHeight-1" : "ScanPasses-iPhone-FixedHeight-1"
                case .orbit2:
                    let iPhoneVideoName = isObjectFlippable ? "ScanPasses-iPhone-FixedHeight-2" : "ScanPasses-iPhone-FixedHeight-unflippable-low"
                    let iPadVideoName = isObjectFlippable ? "ScanPasses-iPad-FixedHeight-2" : "ScanPasses-iPad-FixedHeight-unflippable-low"
                    return interfaceIdiom == .pad ? iPadVideoName : iPhoneVideoName
                case .orbit3:
                    let iPhoneVideoName = isObjectFlippable ? "ScanPasses-iPhone-FixedHeight-3" : "ScanPasses-iPhone-FixedHeight-unflippable-high"
                    let iPadVideoName = isObjectFlippable ? "ScanPasses-iPad-FixedHeight-3" : "ScanPasses-iPad-FixedHeight-unflippable-high"
                    return interfaceIdiom == .pad ? iPadVideoName : iPhoneVideoName
            }
        }

        static func < (lhs: AppDataModel.Orbit, rhs: AppDataModel.Orbit) -> Bool {
            guard let lhsIndex = Self.allCases.firstIndex(of: lhs),
                  let rhsIndex = Self.allCases.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    enum ModelState: String, CustomStringConvertible {
        var description: String { rawValue }

        case notSet
        case ready
        case capturing
        case prepareToReconstruct
        case reconstructing
        case viewing
        case completed
        case restart
        case failed
    }
    
    enum OrbitState {
        case initial, capturing
    }
    
    enum LocString {
        static let segment1FeedbackString = NSLocalizedString(
            "Move slowly around your object. (Object Capture, Segment, Feedback)",
            bundle: bundleForLocalizedStrings,
            value: "Move slowly around your object.",
            comment: "Guided feedback message to move slowly around object to start capturing."
        )

        static let segment2And3FlippableFeedbackString = NSLocalizedString(
            "Flip object on its side and move around. (Object Capture, Segment, Feedback)",
            bundle: bundleForLocalizedStrings,
            value: "Flip object on its side and move around.",
            comment: "Guided feedback message for user to move around object again after flipping."
        )

        static let segment2UnflippableFeedbackString = NSLocalizedString(
            "Move low and capture again. (Object Capture, Segment, Feedback)",
            bundle: bundleForLocalizedStrings,
            value: "Move low and capture again.",
            comment: "Guided feedback message for user to move around object again from a lower angle without flipping"
        )

        static let segment3UnflippableFeedbackString = NSLocalizedString(
            "Move above your object and capture again. (Object Capture, Segment, Feedback)",
            bundle: bundleForLocalizedStrings,
            value: "Move above your object and capture again.",
            comment: "Guided feedback message for user to move around object again from a higher angle without flipping"
        )
    }
    
    
}
