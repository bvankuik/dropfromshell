#!/usr/bin/swift
//
//  main.swift
//  dropfromshell
//
//  Created by bartvk on 02/04/2020.
//  Copyright © 2020 DutchVirtual. All rights reserved.
//

// ---------------------------------------------------------------------
// Used to test the functions in dropfromshell.swift
// ---------------------------------------------------------------------

import Foundation
import Darwin

// Set global access token
oauthAccessToken = readOauthAccessToken()

// Make test directory name
let remoteTestFolder = "/testdropfromshell" + UUID().uuidString

_ = dbMkdir(path: remoteTestFolder)

// Make a local textfile
let remoteTestFile = "testfile.txt"
let remoteTestFilePath = remoteTestFolder + "/" + remoteTestFile
let localTempDir = URL(fileURLWithPath: NSTemporaryDirectory())
let localTempFile = localTempDir.appendingPathComponent(UUID().uuidString)
let testfileData = UUID().uuidString.data(using: .utf8)
try! testfileData?.write(to: localTempFile)

// Try and upload
_ = dbSimpleUpload(source: localTempFile, destinationPath: remoteTestFilePath)

let metadata = dbMetadata(path: remoteTestFilePath)
guard metadata == .file else {
    fputs("Error occurred in dbSimpleUpload\n", stderr)
    exit(1)
}

let remoteTestFileCopy = "testfile(2).txt"
let remoteTestFileCopyPath = remoteTestFolder + "/" + remoteTestFileCopy

dbMove(fromPath: remoteTestFilePath, toPath: remoteTestFileCopyPath)
guard dbMetadata(path: remoteTestFileCopyPath) == .file else {
    fputs("Error occurred while moving file\n", stderr)
    exit(1)
}

let folderListing = dbListFolder(path: remoteTestFolder)
guard let entry = folderListing.first,
    folderListing.count == 1,
    entry.name == remoteTestFileCopy,
    entry.tag == .file else {
        
    fputs("Expected list to return 1 file\n", stderr)
    exit(1)
}

let testfileCopy = localTempDir.appendingPathComponent(UUID().uuidString)
dbDownloadFile(path: remoteTestFileCopyPath, destination: testfileCopy)

// See if contents are equal after uploading and downloading
let contentsEqual = FileManager.default.contentsEqual(atPath: localTempFile.path,
                                                      andPath: testfileCopy.path)
guard contentsEqual else {
    fputs("Downloaded file is not equal to local test file\n", stderr)
    exit(1)
}

let deleteResult = dbDelete(path: remoteTestFolder)
guard deleteResult else {
    fputs("Failed to delete remote test folder\n", stderr)
    exit(1)
}

