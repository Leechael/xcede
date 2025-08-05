import Foundation

func log(_ s: String) {
    Logger.instance.logg(s)
}

class Logger {
    static let instance = Logger()
    let q = DispatchQueue(label: "logger", qos: .userInitiated)
    let fh: FileHandle?

    init() {
        do {
            // args not being passed through from zed settings file, so let's use an env var instead.
            // if let i = CommandLine.arguments.firstIndex(of: "--logFile"), CommandLine.arguments.count > i + 1 {
            // let url = URL(filePath: CommandLine.arguments[i + 1])
            if let file = ProcessInfo.processInfo.environment["XCEDE_DAP_LOG_FILE"] {
                let url = URL(filePath: file)
                try? FileManager.default.removeItem(at: url)
                try Data().write(to: url)
                try fh = FileHandle(forWritingTo: url)
            }
            else {
                // fh = nil
                let url = URL(filePath: "/tmp/fallback")
                try? FileManager.default.removeItem(at: url)
                try Data().write(to: url)
                try fh = FileHandle(forWritingTo: url)
            }
        }
        catch {
            print("can't open log file: \(error)")
            fh = nil
        }
    }

    func logg(_ s: String) {
        if let fh {
            q.async {
                try? fh.write(contentsOf: (s + "\n").data)
                try? fh.synchronize()
            }
        }
        else {
            print(s)
        }
    }

    /// synchronous, so the caller doesn't terminate the process before messages are written
    func close() {
        q.sync {
            try? fh?.close()
        }
    }
}
