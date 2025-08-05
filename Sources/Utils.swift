import Foundation

public extension URL {
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    var pathEscapingSingleQuotes: String {
        path(percentEncoded: false).replacing("'", with: "\\'")
    }
}


public struct DapError: LocalizedError {
    public var message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var errorDescription: String? { message }
}

extension Array where Element == UInt8 {
    var string: String {
        get throws {
            try Data(self).string
        }
    }
}

extension Data {
    var string: String {
        get throws {
            guard let s = String(data: self, encoding: .utf8) else {
                throw DapError("bad string data")
            }
            return s
        }
    }
}

extension String {
    var data: Data {
        get throws {
            guard let d = data(using: .utf8) else { throw DapError("bad string") }
            return d
        }
    }
}
