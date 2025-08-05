import Foundation

class DapMessageWriter {
    private let fh: FileHandle
    private let label: String
    private let writeQueue: DispatchQueue
    private let logLabel: String?
    var errorHandler: ((String) -> Void)?
    var logNext = true
    
    init(_ fh: FileHandle, label: String, logLabel: String? = nil, errorHandler: ((String) -> Void)? = nil) {
        self.label = label
        self.fh = fh
        self.logLabel = logLabel
        self.errorHandler = errorHandler
        writeQueue = DispatchQueue(label: label + " write", qos: .userInteractive)
    }
    
    func writeCommand<T: Codable>(_ command: String, args: T, seq: Int) throws {
        try writeMessage(encodable: Command(command: command, arguments: args, type: .request, seq: seq))
    }
    
    func writeMessage(encodable: Encodable) throws {
        try writeMessage(JSONEncoder().encode(encodable))
    }
    
    func writeMessage(encodable: Any) throws {
        try writeMessage(JSONSerialization.data(withJSONObject: encodable))
    }
    
    func writeMessage(_ s: String) throws {
        try writeMessage(s.data)
    }
    
    func writeMessage(_ data: Data) throws {
        if let logLabel {
            if logNext {
                let s = try? data.string
                log("\(logLabel) \(s ?? "<BAD STRING DATA>")")
            }
            else {
                logNext = true
            }
        }
        try write("\(LengthLinePrefix)\(data.count)\(LengthLineSuffix)".data)
        write(data)
    }
    
    func waitFor() {
        writeQueue.sync {
            print("write queue clear")
        }
    }
    
    private func write(_ data: Data) {
        writeQueue.async { [self] in
            do {
                try fh.write(contentsOf: data)
            }
            catch {
                errorHandler?("\(label) write failed: \(error)")
            }
        }
    }
}
