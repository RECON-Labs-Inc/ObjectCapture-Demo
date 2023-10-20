//
//  ShotFileInfo.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/17.
//

import Foundation

struct ShotFileInfo:Identifiable {
    let fileURL: URL
    let id:UInt32
    
    init?(url:URL) {
        fileURL = url
        
        guard let shotID = CaptureFolderManager.parseShotId(url: url) else {
            return nil
        }

        id = shotID
        
    }
}

