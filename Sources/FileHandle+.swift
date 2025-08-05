import Foundation

extension FileHandle {
    
    func readDapMessages(label: String, errorHandler: @escaping (String) -> Void, op: @escaping (String) throws -> Void) {
        DispatchQueue(label: label + " read", qos: .userInteractive).async { [weak self] in
            do {
                while let message = try self?.read(until: LengthLineSuffix.data)?.string {
                    guard message.hasPrefix(LengthLinePrefix) else { throw DapError("unexpected: \(message)") }
                    var lenString = message
                    lenString.removeFirst(LengthLinePrefix.count)
                    lenString.removeLast(LengthLineSuffix.count)
                    guard let len = Int(lenString) else { throw DapError("unexpected: \(message)") }
                    
                    guard let contents = try self?.read(exactly: len)?.string else {
                        throw DapError("message truncated")
                    }
                    
                    try op(contents)
                }
            }
            catch {
                errorHandler("\(label): \(error)")
            }
        }
    }
    
    func readLines(label: String, errorHandler: @escaping (String) -> Void, op: @escaping (any StringProtocol) throws -> Void) {
        DispatchQueue(label: label + " read", qos: .userInteractive).async { [weak self] in
            do {
                while let data = try self?.read(until: "\n".data) {
                    try op(data.string.dropLast())
                }
            }
            catch {
                errorHandler("\(label): \(error)")
            }
        }
        
    }
    
    /// returns nil at end of input. This includes the case when there was some data not
    /// terminated as expected.
    func read(until terminal: Data) throws -> Data? {
        var result = Data()
        while result.suffix(terminal.count) != terminal {
            // Blocks until data available. Returns nil when at end of input (docs say returns empty, which
            // implies zero length non-nil value, but this isn't what happens – nor would it be intuitive
            // given the method signature).
            let next = try read(upToCount: 1)
            if let next {
                result.append(next)
            }
            else {
                return nil
            }
        }
        return result
    }
    
    /// returns nil at end of input, including when read some data but less than expected
    func read(exactly: Int) throws -> Data? {
        var result = Data()
        while result.count < exactly {
            let next = try read(upToCount: 1)
            if let next {
                result.append(next)
            }
            else {
                return nil
            }
        }
        return result
    }
}
