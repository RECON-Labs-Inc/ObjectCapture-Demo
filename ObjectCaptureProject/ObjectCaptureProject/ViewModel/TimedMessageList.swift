//
//  TimedMessageList.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/19.
//

import Foundation
import Combine
import Dispatch
import SwiftUI

class TimedMessageList: ObservableObject {
    
    struct Message: Identifiable {
        let id = UUID()
        let message:String
        let startTime = Date()
        
        fileprivate(set) var endTime:Date?
        
        init(_ string: String) {
            message = string
        }
        
        func hasExpired() -> Bool {
            guard let endTime else { return false }
            return Date() >= endTime
        }
    }
    
    @Published var activeMessage:Message? = nil
    
    private var messages = [Message]() {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            
            if activeMessage?.message != messages.first?.message {
                withAnimation {
                    activeMessage = messages.first
                }
            }
        }
    }
    private var timer: Timer?
    private let feedbackMessageMinimumDurationSecs: Double = 2.0
    
    func add(_ msg: String) {
        dispatchPrecondition(condition: .onQueue(.main))

        if let index = messages.lastIndex(where: { $0.message == msg }) {
            messages[index].endTime = nil
        } else {
            messages.append(Message(msg))
        }
        setTimer()
    }
    
    func remove(_ msg: String) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let index = messages.lastIndex(where: { $0.message == msg }) else { return }
        var endTime = Date()
        let earliestAcceptableEndTime = messages[index].startTime + feedbackMessageMinimumDurationSecs
        if endTime < earliestAcceptableEndTime {
            endTime = earliestAcceptableEndTime
        }
        messages[index].endTime = endTime
        setTimer()
    }
    
    private func setTimer() {
        dispatchPrecondition(condition: .onQueue(.main))
        
        timer?.invalidate()
        timer = nil
        
        cullExpired()
        
        if let nearestEndTime = (messages.compactMap { $0.endTime }).min() {
            let duration = nearestEndTime.timeIntervalSinceNow
            timer = Timer.scheduledTimer(timeInterval: duration,
                                         target: self,
                                         selector: #selector(onTimer),
                                         userInfo: nil,
                                         repeats: false)
        }
    }
    
    private func cullExpired() {
        dispatchPrecondition(condition: .onQueue(.main))

        withAnimation {
            messages.removeAll(where: { $0.hasExpired() })
        }
    }

    @objc
    private func onTimer() {
        dispatchPrecondition(condition: .onQueue(.main))
        timer?.invalidate()
        cullExpired()
        setTimer()
    }
    
}
