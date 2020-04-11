// #!/usr/bin/swift

// Uncomment the line above if you wish to chmod and run this file as a script

// ---------------------------------------------------------------------
//      Configurable section follows
// ---------------------------------------------------------------------

// You can set this directly, or fill it with the readOauthAccessToken() function
// at the bottom of this script

var oauthAccessToken: String = ""

// ---------------------------------------------------------------------
//      No need to edit anything below this line
// ---------------------------------------------------------------------

import Foundation
import Darwin

// Used to parse ~/.config/dropfromshell/dropfromshell.json
// Only contains the OAuth access token. To create it, see also:
// https://www.dropbox.com/developers/reference/oauth-guide
fileprivate struct Configuration: Decodable {
    let oauthAccessToken: String
}

// List of all URLs used in this script to operate on Dropbox
fileprivate struct API {
    static let listFolder = URL(string: "https://api.dropboxapi.com/2/files/list_folder")!
    static let delete = URL(string: "https://api.dropboxapi.com/2/files/delete")!
    static let mkdir = URL(string: "https://api.dropboxapi.com/2/files/create_folder")!
    static let upload = URL(string: "https://content.dropboxapi.com/2/files/upload")!
    static let metadata = URL(string: "https://api.dropboxapi.com/2/files/get_metadata")!
    static let download = URL(string: "https://content.dropboxapi.com/2/files/download")!
}

// Almost all requests include a path to a file or directory
fileprivate struct BaseRequestBody: Encodable {
    let path: String
}

// Used to configure options when you do the listFolder operation
fileprivate struct ListRequestBody: Encodable {
    let path: String
    let includeMediaInfo = false
    let includeDeleted = false
    let includeHasExplicitSharedMembers = false
}

// Used to parse the reply to the listFolder operation
struct ListResponseBody: Decodable {
    struct Entry: Decodable {
        enum Tag: String, Decodable {
            case folder
            case file
            case deleted
            case other

            init(from decoder: Decoder) throws {
                let label = try decoder.singleValueContainer().decode(String.self)

                switch label {
                case "folder":
                    self = .folder
                case "file":
                    self = .file
                case "deleted":
                    self = .deleted
                default:
                    self = .other
                }
            }
        }

        enum CodingKeys: String, CodingKey {
            case tag = ".tag", name, id
        }

        let tag: Tag
        let name: String
        let id: String? // If file and deleted, this is nil
    }

    let entries: [Entry]
    let cursor: String
    let hasMore: Bool
}

// Used to configure options when you upload a file
fileprivate struct UploadHeader: Encodable {
    let path: String
    let mode = "overwrite"
    let autorename = true
    let mute = false
}

// Used to parse the reply to the upload operation
fileprivate struct UploadResponse: Decodable {
    let errorSummary: String
}

// You can use this to read the contents from the configuration file, which is by default
// ~/.config/dropfromshell/dropfromshell.json
// For example, put on top of your script:
// oauthAccessToken = readOauthAccessToken()
func readOauthAccessToken() -> String {
    let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config")
        .appendingPathComponent("dropfromshell")
        .appendingPathComponent("dropfromshell.json")
    
    guard let configContents = try? Data(contentsOf: fileURL) else {
        fatalError("Couldn't read contents of configuration file \(fileURL.path)")
    }

    guard let config = try? JSONDecoder().decode(Configuration.self, from: configContents) else {
        fatalError("Couldn't read configuration with OAuth access token from configuration file")
    }
    
    return config.oauthAccessToken
}

// Builds a basic request, used to run any operation
fileprivate func makeRequest(with url: URL) -> URLRequest {
    guard !oauthAccessToken.isEmpty else {
        fputs("oauthAccessToken empty", stderr)
        exit(1)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + oauthAccessToken, forHTTPHeaderField: "Authorization")
    return request
}

// Make a folder on dropbox. Example:
// let result = dbMkdir(path: "/newdir")
// print("mkdir " + (result ? "successful" : "already exists"))
func dbMkdir(path: String) -> Bool {
    var request = makeRequest(with: API.mkdir)

    let mkdirRequestBody = BaseRequestBody(path: path)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    guard let body = try? encoder.encode(mkdirRequestBody) else {
        fatalError("Error encoding JSON to request directory list")
    }
    request.httpBody = body

    let semaphore = DispatchSemaphore(value: 0)
    var isDirectoryCreated = false
    URLSession.shared.dataTask(with: request) { data, response, _ in
        guard let response = response as? HTTPURLResponse else {
            fatalError("Expected HTTPURLResponse")
        }

        if response.statusCode == 200 {
            isDirectoryCreated = true
        } else if response.statusCode == 403 {
            // Already exists
            isDirectoryCreated = false
        } else {
            var msg = "Received \(response.statusCode), expected 200 or 403."
            if let data = data, let string = String(data: data, encoding: .utf8) {
                msg += " Server response:\n" + string
            }
            fatalError(msg)
        }
        semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .distantFuture)
    return isDirectoryCreated
}

// Delete a file or folder on dropbox. Example:
// _ = dbDelete(path: "/test/blah2.png")
// Returns true if successful false if it didn't work out for some reason.
func dbDelete(path: String) -> Bool {
    var request = makeRequest(with: API.delete)

    let deleteRequestBody = BaseRequestBody(path: path)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    guard let body = try? encoder.encode(deleteRequestBody) else {
        fatalError("Error encoding JSON to request directory list")
    }
    request.httpBody = body

    let semaphore = DispatchSemaphore(value: 0)
    var isFileDeleted = false
    URLSession.shared.dataTask(with: request) { data, response, _ in
        guard let response = response as? HTTPURLResponse else {
            fatalError("Expected HTTPURLResponse")
        }

        if response.statusCode == 200 {
            isFileDeleted = true
        } else if response.statusCode == 409 {
            isFileDeleted = false
        } else {
            var msg = "Received \(response.statusCode), expected 200 or 409."
            if let data = data, let string = String(data: data, encoding: .utf8) {
                msg += " Server response:\n" + string
            }
            fatalError(msg)
        }
        semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .distantFuture)
    return isFileDeleted
}

// List contents of folder. Example:
// let entries: [ListResponseBody.Entry] = dbListFolder(path: "/test")
func dbListFolder(path: String) -> [ListResponseBody.Entry] {
    var request = makeRequest(with: API.listFolder)

    let dbListRequestBody = ListRequestBody(path: path)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    guard let body = try? encoder.encode(dbListRequestBody) else {
        fatalError("Error encoding JSON to request directory list")
    }
    request.httpBody = body

    let semaphore = DispatchSemaphore(value: 0)
    var entries: [ListResponseBody.Entry] = []
    URLSession.shared.dataTask(with: request) { data, response, _ in
        defer {
            semaphore.signal()
        }

        if let response = response as? HTTPURLResponse {
            guard response.statusCode == 200 else {
                var msg = "Received \(response.statusCode), expected 200."
                if let data = data, let string = String(data: data, encoding: .utf8) {
                    msg += " Server response:\n" + string
                }
                fatalError(msg)
            }
        }
        guard let data = data else {
            return
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let dirListResponse = try? decoder.decode(ListResponseBody.self, from: data) else {
            var msg = "Couldn't decode JSON response to request directory list."
            if let string = String(data: data, encoding: .utf8) {
                msg += " Raw JSON:\n" + string
            }
            fatalError(msg)
        }

        guard !dirListResponse.hasMore else {
            fatalError("API indicates there's more results, this is not supported")
        }

        entries = dirListResponse.entries
    }.resume()
    _ = semaphore.wait(timeout: .distantFuture)
    return entries
}

// Upload a file. Example:
// guard let dir = try? FileManager.default.url(for: .desktopDirectory,
//                                              in: .userDomainMask, appropriateFor: nil, create: false) else {
//     fatalError("Couldn't find Documents directory")
// }
// let fileURL = dir.appendingPathComponent("screenshot.png")
// let result = simpleUpload(source: fileURL, destinationPath: "/test/screenshot.png")
// print("Upload " + (result ? "successful" : "failed"))
func dbSimpleUpload(source: URL, destinationPath: String) -> Bool {
    let uploadHeader = UploadHeader(path: destinationPath)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    guard
        let uploadHeaderJSON = try? encoder.encode(uploadHeader),
        let uploadHeaderJSONString = String(data: uploadHeaderJSON, encoding: .utf8)
    else {
        fatalError("Error encoding UploadHeader to JSON")
    }

    var request = makeRequest(with: API.upload)
    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
    request.setValue(uploadHeaderJSONString, forHTTPHeaderField: "Dropbox-API-Arg")

    var success = false
    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.uploadTask(with: request, fromFile: source) { data, response, _ in
        defer {
            semaphore.signal()
        }

        guard let response = response as? HTTPURLResponse else {
            fatalError("Expected HTTPURLResponse")
        }
        if response.statusCode == 200 {
            success = true
        } else {
            var msg = "Received \(response.statusCode), expected 200."
            if let data = data, let string = String(data: data, encoding: .utf8) {
                msg += " Server response:\n" + string
            }
            print(msg)
            success = false
        }
    }.resume()
    _ = semaphore.wait(timeout: .distantFuture)
    return success
}

// Lists a single file.
// Example:
// let metadata = dbMetadata(path: remoteTestFilePath)
// guard metadata == .file else { fatalError("File expected!") }
func dbMetadata(path: String) -> ListResponseBody.Entry.Tag? {
    var request = makeRequest(with: API.metadata)

    let metadataRequestBody = BaseRequestBody(path: path)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    var retval: ListResponseBody.Entry.Tag?

    guard let body = try? encoder.encode(metadataRequestBody) else {
        fatalError("Error encoding JSON to request directory list")
    }
    request.httpBody = body

    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, _ in
        defer {
            semaphore.signal()
        }

        guard let response = response as? HTTPURLResponse else {
            fatalError("Expected HTTPURLResponse")
        }
        
        if response.statusCode == 409 {
            // File doesn't exist
            retval = nil
            return
        }

        guard response.statusCode == 200 else {
            var msg = "Received \(response.statusCode), expected 200 or 409."
            if let data = data, let string = String(data: data, encoding: .utf8) {
                msg += " Server response:\n" + string
            }
            fatalError(msg)
        }

        guard let data = data else {
            fatalError("Received 0 bytes data, expected response to metadata request")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let metadata = try? decoder.decode(ListResponseBody.Entry.self, from: data) else {
            var msg = "Couldn't decode JSON response to request metadata."
            if let string = String(data: data, encoding: .utf8) {
                msg += " Raw JSON:\n" + string
            }
            fatalError(msg)
        }

        retval = metadata.tag
    }.resume()
    _ = semaphore.wait(timeout: .distantFuture)

    return retval
}

// Download a single file.
// Example:
// dbDownloadFile(path: remoteFilePath, destination: localDestinationFileURL)
func dbDownloadFile(path: String, destination: URL) {
    if let metadata = dbMetadata(path: path) {
        if metadata != .file {
            fatalError("Tried to download something other than file: \(metadata.rawValue)")
        }
    } else {
        fatalError("Tried to download path that doesn't exist, path: [\(path)]")
    }

    let downloadHeader = BaseRequestBody(path: path)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    guard
        let downloadHeaderJSON = try? encoder.encode(downloadHeader),
        let downloadHeaderJSONString = String(data: downloadHeaderJSON, encoding: .utf8)
    else {
        fatalError("Error encoding DownloadHeader to JSON")
    }

    var request = makeRequest(with: API.download)
    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
    request.setValue(downloadHeaderJSONString, forHTTPHeaderField: "Dropbox-API-Arg")

    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, _ in
        guard let response = response as? HTTPURLResponse else {
            fatalError("Expected HTTPURLResponse")
        }

        if response.statusCode == 200, let data = data {
            do {
                try data.write(to: destination)
            } catch {
                fatalError(error.localizedDescription)
            }
        } else {
            var msg = "Received \(response.statusCode), expected 200"
            if let data = data, let string = String(data: data, encoding: .utf8) {
                msg += " Server response:\n" + string
            }
            fatalError(msg)
        }
        semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .distantFuture)
    return
}

// ---------------------------------------------------------------------
//      No need to edit anything above this line
// ---------------------------------------------------------------------

// Start your script here
