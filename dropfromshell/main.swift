#!/usr/bin/swift
//
//  main.swift
//  dropfromshell
//
//  Created by bartvk on 02/04/2020.
//  Copyright © 2020 DutchVirtual. All rights reserved.
//

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
    fputs("Error occurred in dbSimpleUpload", stderr)
    exit(1)
}

let folderListing = dbListFolder(path: remoteTestFolder)
guard let entry = folderListing.first,
    folderListing.count == 1,
    entry.name == remoteTestFile,
    entry.tag == .file else {
        
    fputs("Expected list to return 1 file", stderr)
    exit(1)
}

let testfileCopy = localTempDir.appendingPathComponent(UUID().uuidString)
dbDownloadFile(path: remoteTestFilePath, destination: testfileCopy)

// See if contents are equal after uploading and downloading
let contentsEqual = FileManager.default.contentsEqual(atPath: localTempFile.path,
                                                      andPath: testfileCopy.path)
guard contentsEqual else {
    fputs("Downloaded file is not equal to local test file", stderr)
    exit(1)
}

let deleteResult = dbDelete(path: remoteTestFolder)
guard deleteResult else {
    fputs("Failed to delete remote test folder", stderr)
    exit(1)
}
