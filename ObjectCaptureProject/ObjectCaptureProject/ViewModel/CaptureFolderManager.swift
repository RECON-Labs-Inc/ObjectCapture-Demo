//
//  CaptureFolderManager.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/17.
//

import Foundation
import Dispatch
import os

class CaptureFolderManager: ObservableObject {
    static let logger = Logger(subsystem: ObjectCaptureProjectApp.subsystem,
                                category: "AppDataModel")
    
    private let logger = CaptureFolderManager.logger
    
    // The top-level capture directory that contains Images and Snapshots subdirectories.
    // This sample automatically creates this directory at `init()` with timestamp.
    let rootScanFolder: URL

    // Subdirectory of `rootScanFolder` for images
    let imagesFolder: URL

    // Subdirectory of `rootScanFolder` for snapshots
    let snapshotsFolder: URL

    // Subdirectory to output model files.
    let modelsFolder: URL

    @Published var shots: [ShotFileInfo] = []
    
    init?() {
        guard let newFolder = CaptureFolderManager.createNewScanDirectory() else {
            logger.error("Unable to create a new scan directory.")
            return nil
        }
        rootScanFolder = newFolder

        // Creates the subdirectories.
        imagesFolder = newFolder.appendingPathComponent("Images/")
        guard CaptureFolderManager.createDirectoryRecursively(imagesFolder) else {
            return nil
        }

        snapshotsFolder = newFolder.appendingPathComponent("Snapshots/")
        guard CaptureFolderManager.createDirectoryRecursively(snapshotsFolder) else {
            return nil
        }

        modelsFolder = newFolder.appendingPathComponent("Models/")
        guard CaptureFolderManager.createDirectoryRecursively(modelsFolder) else {
            return nil
        }
    }
    
    
    // Constants this sample appends in front of the capture id to get a file basename.
    private static let imageStringPrefix = "IMG_"
    private static let heicImageExtension = "HEIC"
    
    /// 새롭게 스캔할 데이터를 저장할 폴더 생성 및 URL 제공
    /// - Returns: The new Scans folder's file URL, or `nil` on error.
    static func createNewScanDirectory() -> URL? {
        guard let capturesFolder = rootScansFolder() else {
            logger.error("Can't get user document dir!")
            return nil
        }

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let newCaptureDir = capturesFolder
            .appendingPathComponent(timestamp, isDirectory: true)

        logger.log("Creating capture path: \"\(String(describing: newCaptureDir))\"")
        let capturePath = newCaptureDir.path
        do {
            try FileManager.default.createDirectory(atPath: capturePath,
                                                    withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create capturepath=\"\(capturePath)\" error=\(String(describing: error))")
            return nil
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: capturePath, isDirectory: &isDir)
        guard exists && isDir.boolValue else {
            return nil
        }

        return newCaptureDir
    }
    
    /// Retrieves the image id from of an existing file at a URL.\
    ///
    /// - Parameter url: URL of the photo for which this method returns the image id.
    /// - Returns: The image ID if `url` is valid; otherwise `nil`.
    static func parseShotId(url: URL) -> UInt32? {
        let photoBasename = url.deletingPathExtension().lastPathComponent
        logger.debug("photoBasename = \(photoBasename)")

        guard let endOfPrefix = photoBasename.lastIndex(of: "_") else {
            logger.warning("Can't get endOfPrefix!")
            return nil
        }

        let imgPrefix = photoBasename[...endOfPrefix]
        guard imgPrefix == imageStringPrefix else {
            logger.warning("Prefix doesn't match!")
            return nil
        }

        let idString = photoBasename[photoBasename.index(after: endOfPrefix)...]
        guard let id = UInt32(idString) else {
            logger.warning("Can't convert idString=\"\(idString)\" to uint32!")
            return nil
        }

        return id
    }
    
    // - MARK: Private interface below.

    /// Creates all path components for the output directory.
    /// - Parameter outputDir: A URL for the new output directory.
    /// - Returns: A Boolean value that indicates whether the method succeeds,
    /// otherwise `false` if it encounters an error, such as if the file already
    /// exists or the method couldn't create the file.
    private static func createDirectoryRecursively(_ outputDir: URL) -> Bool {
        guard outputDir.isFileURL else {
            return false
        }
        let expandedPath = outputDir.path
        var isDirectory: ObjCBool = false
        let fileManager = FileManager()
        guard !fileManager.fileExists(atPath: outputDir.path, isDirectory: &isDirectory) else {
            logger.error("File already exists at \(expandedPath, privacy: .private)")
            return false
        }

        logger.log("Creating dir recursively: \"\(expandedPath, privacy: .private)\"")

        let result: ()? = try? fileManager.createDirectory(atPath: expandedPath,
                                                           withIntermediateDirectories: true)

        guard result != nil else {
            return false
        }

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDir) && isDir.boolValue else {
            logger.error("Dir \"\(expandedPath, privacy: .private)\" doesn't exist after creation!")
            return false
        }

        logger.log("... success creating dir.")
        return true
    }
    
    /// 캡쳐한 사진을 저장해 놓을 루트 경로
    private static func rootScansFolder() -> URL? {
        guard let documentsFolder =
                try? FileManager.default.url(for: .documentDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil, create: false) else {
            return nil
        }
        return documentsFolder.appendingPathComponent("Scans/", isDirectory: true)
    }
    
}
