//
//  TestDropfromshell.swift
//  TestDropfromshell
//
//  Created by bartvk on 15/04/2020.
//  Copyright © 2020 DutchVirtual. All rights reserved.
//

import XCTest

class TestDropfromshell: XCTestCase {
    private let remoteTestFolder = "/testdropfromshell" + UUID().uuidString

    override func setUpWithError() throws {
        oauthAccessToken = readOauthAccessToken()
    }

    override func tearDownWithError() throws {
    }
    
    func makeLocalTestFile() -> URL {
        let localTempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let localTempFile = localTempDir.appendingPathComponent("TestDropFromShell_" + UUID().uuidString)
        let testfileData = UUID().uuidString.data(using: .utf8)
        try! testfileData?.write(to: localTempFile)
        return localTempFile
    }

    func testMakeAndDeleteDir() throws {
        let isFolderCreated = dbMkdir(path: remoteTestFolder)
        XCTAssert(isFolderCreated)
        
        if let metadata = dbMetadata(path: remoteTestFolder) {
            XCTAssert(metadata == .folder)
        } else {
            XCTAssert(false, "Couldn't find \(remoteTestFolder)")
        }
        
        let isDeleteSuccess = dbDelete(path: remoteTestFolder)
        XCTAssert(isDeleteSuccess, "Test failed, please delete remote folder manually: \(remoteTestFolder)")
    }
    
    func testFileUpload() {
        // Create local file
        let localTestFile = makeLocalTestFile()
        
        let remoteTestFile = "/testdropfromshell" + UUID().uuidString + ".txt"
        dbSimpleUpload(source: localTestFile, destinationPath: remoteTestFile)
        
        let isDeleteSuccess = dbDelete(path: remoteTestFile)
        XCTAssert(isDeleteSuccess, "Test failed, please delete remote folder manually: \(remoteTestFile)")
    }
    
    func testFileMove() {
        // Create local file
        let localTestFile = makeLocalTestFile()
        
        let remoteTestFileA = "/testdropfromshellA_" + UUID().uuidString + ".txt"
        let remoteTestFileB = "/testdropfromshellB_" + UUID().uuidString + ".txt"
        dbSimpleUpload(source: localTestFile, destinationPath: remoteTestFileA)
        dbMove(fromPath: remoteTestFileA, toPath: remoteTestFileB)
        
        let isDeleteASuccess = dbDelete(path: remoteTestFileA)
        XCTAssert(!isDeleteASuccess, "Deleted file \(remoteTestFileA) but this file shouldn't have existed")

        let isDeleteBSuccess = dbDelete(path: remoteTestFileB)
        XCTAssert(isDeleteBSuccess, "Test failed, please delete remote file manually: \(remoteTestFileB)")
    }

}
