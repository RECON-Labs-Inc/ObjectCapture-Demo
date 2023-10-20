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
    let logger = Logger(subsystem: ObjectCaptureProjectApp.subsystem,
                                category: "AppDataModel")
    static let instance = AppDataModel()
    static let minNumImages = 10
    static let bundleForLocalizedStrings = { return Bundle.main }()
    
    @Published var session: ObjectCaptureSession? {
        willSet {
            detachListeners()
        }
        didSet {
            guard session != nil else { return }
            attachListeners()
        }
    }
    
    /// The object that manages the reconstruction process of a set of images of an object into a 3D model.
    ///
    /// When the ``ReconstructionPrimaryView`` is active, hold the session here.
    private(set) var photogrammetrySession: PhotogrammetrySession?
    private(set) var scanFolderManager: CaptureFolderManager!
    
    @Published var messageList = TimedMessageList()
    @Published var state: ModelState = .notSet {
        didSet {
            logger.debug("didSet AppDataModel.state to \(self.state)")

            if state != oldValue {
                performStateTransition(from: oldValue, to: state)
            }
        }
    }
    
    @Published var orbitState: OrbitState = .initial
    @Published var orbit: Orbit = .orbit1
    @Published var isObjectFlipped: Bool = false
    
    var hasIndicatedObjectCannotBeFlipped: Bool = false
    var hasIndicatedFlipObjectAnyway: Bool = false
    var isObjectFlippable: Bool {
        // Overrides the `objectNotFlippable` feedback if the user indicates
        // the object can flip or if they want to flip the object anyway.
        guard !hasIndicatedObjectCannotBeFlipped else { return false }
        guard !hasIndicatedFlipObjectAnyway else { return true }
        guard let session = session else { return true }
        return !session.feedback.contains(.objectNotFlippable)
    }
    
    private(set) var error: Swift.Error?
    /// A Boolean value that determines whether the view shows a preview model.
    ///
    /// Default value is `false`.
    ///
    /// Uses ``setPreviewModelState(shown:)`` to properly maintain the pause state of
    /// the ``objectCaptureSession`` while showing the ``CapturePrimaryView``.
    /// Alternatively, hiding the ``CapturePrimaryView`` pauses the
    /// ``objectCaptureSession``.
    @Published private(set) var showPreviewModel = false

    
    private init(session: ObjectCaptureSession) {
        self.session = session
        state = .ready
    }
    
    private init() {
        state = .ready
    }
    
    deinit {
        DispatchQueue.main.async {
            self.detachListeners()
        }
    }
    
    /// Informs your app to rerun to the new capture view after recontruction and viewing.
    ///
    /// After reconstruction and viewing are complete, call `endCapture()` to
    /// inform the app it can go back to the new capture view.
    /// You can also call ``endCapture()`` after a canceled or failed
    /// reconstruction to go back to the start screen.
    func endCapture() {
        state = .completed
    }
    
    // This sample doesn't modify the `showPreviewModel` directly. The `CapturePrimaryView`
    // remains on screen and blurred underneath, it doesn't pause.  So, pause
    // the `objectCaptureSession` after showing the model and start it before
    // dismissing the model.
    func setPreviewModelState(shown: Bool) {
        guard shown != showPreviewModel else { return }
        if shown {
            showPreviewModel = true
            session?.pause()
        } else {
            session?.resume()
            showPreviewModel = false
        }
    }
    
    // - MARK: Private Interface

    private var currentFeedback: Set<Feedback> = []
    private typealias Feedback = ObjectCaptureSession.Feedback
    private typealias Tracking = ObjectCaptureSession.Tracking
    private var tasks: [ Task<Void, Never> ] = []
    
    @MainActor //자동으로 메인스레드에서 실행할 수 있게 도와줌
    private func attachListeners() {
        logger.debug("Attaching listeners...")
        guard let model = session else {
            fatalError("Logic error")
        }
        
        tasks.append(Task<Void, Never> { [weak self] in
                for await newFeedback in model.feedbackUpdates {
                    self?.logger.debug("Task got async feedback change to: \(String(describing: newFeedback))")
                    self?.updateFeedbackMessages(for: newFeedback)
                }
                self?.logger.log("^^^ Got nil from stateUpdates iterator!  Ending observation task...")
        })
        tasks.append(Task<Void, Never> { [weak self] in
            for await newState in model.stateUpdates {
                self?.logger.debug("Task got async state change to: \(String(describing: newState))")
                self?.onStateChanged(newState: newState)
                }
            self?.logger.log("^^^ Got nil from stateUpdates iterator!  Ending observation task...")
        })
    }
    
    private func detachListeners() {
        logger.debug("Detaching listeners...")
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
    
    /// Creates a new object capture session.
    private func startNewCapture() -> Bool {
        logger.log("startNewCapture() called...")
        if !ObjectCaptureSession.isSupported {
            preconditionFailure("ObjectCaptureSession is not supported on this device!")
        }

        guard let folderManager = CaptureFolderManager() else {
            return false
        }

        scanFolderManager = folderManager
        session = ObjectCaptureSession()

        guard let session = session else {
            preconditionFailure("startNewCapture() got unexpectedly nil session!")
        }

        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = scanFolderManager.snapshotsFolder
        configuration.isOverCaptureEnabled = true
        logger.log("Enabling overcapture...")

        // Starts the initial segment and sets the output locations.
        session.start(imagesDirectory: scanFolderManager.imagesFolder,
                      configuration: configuration)

        if case let .failed(error) = session.state {
            logger.error("Got error starting session! \(String(describing: error))")
            switchToErrorState(error: error)
        } else {
            state = .capturing
        }

        return true
    }
    
    private func switchToErrorState(error: Swift.Error) {
        // Sets the error first since the transitions assume it's non-`nil`.
        self.error = error
        state = .failed
    }
    
    private func startReconstruction() throws {
        logger.debug("startReconstruction() called.")

        var configuration = PhotogrammetrySession.Configuration()
        configuration.checkpointDirectory = scanFolderManager.snapshotsFolder
        photogrammetrySession = try PhotogrammetrySession(
            input: scanFolderManager.imagesFolder,
            configuration: configuration)

        state = .reconstructing
    }

    private func reset() {
        logger.info("reset() called...")
        photogrammetrySession = nil
        session = nil
        scanFolderManager = nil
        showPreviewModel = false
        orbit = .orbit1
        orbitState = .initial
        isObjectFlipped = false
        state = .ready
    }
    
    private func onStateChanged(newState: ObjectCaptureSession.CaptureState) {
        logger.info("ObjectCaptureSession switched to state: \(String(describing: newState))")
        if case .completed = newState {
            logger.log("ObjectCaptureSession moved to .completed state.  Switch app model to reconstruction...")
            state = .prepareToReconstruct
        } else if case let .failed(error) = newState {
            logger.error("ObjectCaptureSession moved to error state \(String(describing: error))...")
            if case ObjectCaptureSession.Error.cancelled = error {
                state = .restart
            } else {
                switchToErrorState(error: error)
            }
        }
    }
    
    private func updateFeedbackMessages(for feedback: Set<Feedback>) {
        // Compares the incoming feedback with the previous feedback to find
        // the intersection.
        let persistentFeedback = currentFeedback.intersection(feedback)

        // Finds the feedback that's no longer active.
        let feedbackToRemove = currentFeedback.subtracting(persistentFeedback)
        for thisFeedback in feedbackToRemove {
            if let feedbackString = FeedbackMessages.getFeedbackString(for: thisFeedback) {
                messageList.remove(feedbackString)
            }
        }

        // Finds new feedback.
        let feebackToAdd = feedback.subtracting(persistentFeedback)
        for thisFeedback in feebackToAdd {
            if let feedbackString = FeedbackMessages.getFeedbackString(for: thisFeedback) {
                messageList.add(feedbackString)
            }
        }

        currentFeedback = feedback
    }
    
    private func performStateTransition(from fromState: ModelState, to toState: ModelState) {
        if fromState == .failed {
            error = nil
        }

        switch toState {
            case .ready:
                guard startNewCapture() else {
                    logger.error("Starting new capture failed!")
                    break
                }
            case .capturing:
                orbitState = .initial
            case .prepareToReconstruct:
                // Cleans up the session to free GPU and memory resources.
                session = nil
                do {
                    try startReconstruction()
                } catch {
                    logger.error("Reconstructing failed!")
                }
            case .restart, .completed:
                reset()
            case .viewing:
                photogrammetrySession = nil

                // Removes snapshots folder to free up space after generating the model.
                let snapshotsFolder = scanFolderManager.snapshotsFolder
                DispatchQueue.global(qos: .background).async {
                    try? FileManager.default.removeItem(at: snapshotsFolder)
                }

            case .failed:
                logger.error("App failed state error=\(String(describing: self.error!))")
                // Shows error screen.
            default:
                break
        }
    }

    func determineCurrentOnboardingState() -> OnboardingState? {
        guard let session = session else { return nil }
        let orbitCompleted = session.userCompletedScanPass
        var currentState = OnboardingState.tooFewImages
        if session.numberOfShotsTaken >= AppDataModel.minNumImages {
            switch orbit {
                case .orbit1:
                    currentState = orbitCompleted ? .firstSegmentComplete : .firstSegmentNeedsWork
                case .orbit2:
                    currentState = orbitCompleted ? .secondSegmentComplete : .secondSegmentNeedsWork
                case .orbit3:
                    currentState = orbitCompleted ? .thirdSegmentComplete : .thirdSegmentNeedsWork
            }
        }
        return currentState
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
