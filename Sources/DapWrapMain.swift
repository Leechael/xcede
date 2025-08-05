import Foundation
import SwiftyJSON
import Combine

@main
class DapWrapMain {
    private let ProgramString = "xcede:"
    private let ParamLinePrefix = "xcede:"
    private let AttachParamsFile = ".xcede/attach-params"

    private let files: OtherFiles
    private let stdoutWriter: DapMessageWriter
    private let stderrWriter: DapMessageWriter
    private let dapWriter: DapMessageWriter
    private let handleError: (String) -> Void

    private var originalLaunchRequestSeq: Int?
    private var ourAttachRequestSeq: Int?
    private var platform: String?
    private var dapHasDisconnected = false

    init() {
        log("🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀🌀 \(Date())")
        log("invoked as \(CommandLine.arguments)")

        let stdoutWriter = DapMessageWriter(.standardOutput, label: "stdoutWriter", logLabel: "🟢")
        self.stdoutWriter = stdoutWriter

        func errorHandler(_ message: String) {
            stdoutWriter.errorHandler = nil
            try? stdoutWriter.writeMessage(encodable: OutputMessage(body: StdoutMessage(output: "xcede-dap failed: \(message)")))
            stdoutWriter.waitFor()

            // todo Really want to send a response here - to the launch command if we've received it and haven't
            // responded yet. And/or does the protocol provide for a generic failure message?

            log(message)
            Logger.instance.close()
            exit(1)
        }
        self.handleError = errorHandler
        stdoutWriter.errorHandler = errorHandler

        do {
            files = try .init()

            let lldbDapProcess = Process()
            lldbDapProcess.executableURL = URL(filePath: "/usr/bin/xcrun")
            lldbDapProcess.arguments = ["lldb-dap"]

            let inPipe = Pipe()
            let outPipe = Pipe()
            let errPipe = Pipe()
            lldbDapProcess.standardInput = inPipe
            lldbDapProcess.standardOutput = outPipe
            lldbDapProcess.standardError = errPipe
            stderrWriter = DapMessageWriter(.standardError, label: "stderrWriter", logLabel: "⚪️", errorHandler: handleError)
            dapWriter = DapMessageWriter(inPipe.fileHandleForWriting, label: "dapWriter", errorHandler: handleError)

            FileHandle.standardInput.readDapMessages(label: "stdinReader", errorHandler: handleError) { [self] jsonString in
                log("🔵 \(jsonString)")
                let data = try jsonString.data

                // Launch command
                if let cmd = try? JSONDecoder().decode(Command<LaunchCommandArgs>.self, from: data),
                    cmd.command == "launch",
                    cmd.arguments.program == ProgramString
                {
                    originalLaunchRequestSeq = cmd.seq
                    launchAndAttach(args: cmd.arguments.args)
                }

                // Some other command. Pass it on to lldb-dap.
                else {
                    try dapWriter.writeMessage(jsonString)
                }
            }

            outPipe.fileHandleForReading.readDapMessages(label: "dapReader", errorHandler: handleError) { [self] jsonString in
                let json = try JSON(jsonString.data)

                // Is it a response to a request we generated in here, as opposed to one sent by zed?
                if let seq = json["request_seq"].int, seq >= FirstSeq {
                    // The client needs a response specifically to its launch request,
                    // so use the response to our attach request for that.
                    if seq == ourAttachRequestSeq, let originalLaunchRequestSeq {
                        var json = json
                        json["request_seq"].int = originalLaunchRequestSeq
                        try stdoutWriter.writeMessage(encodable: json)

                        let ok = json["success"].boolValue
                        try stdoutWriter.writeMessage(encodable: OutputMessage(body: StdoutMessage(output: ok ? "Debugger ready" : "Debugger failed")))
                    }

                    // Drop responses to any other requests we've created - they'll just confuse matters.
                    else {
                        log("🫆 \(jsonString)")
                    }
                }

                // pass it out to zed
                else {
                    // This is what we expect when finished:
                    if json["command"].string == "disconnect" {
                        log("dap has disconnected")
                        dapHasDisconnected = true
                    }

                    try stdoutWriter.writeMessage(jsonString)
                }
            }

            errPipe.fileHandleForReading.readDapMessages(label: "dap stderr", errorHandler: handleError) {
                try self.stderrWriter.writeMessage($0)
            }

            // We're actually being terminated by zed before this happens, at least when the stop button is pressed.
            lldbDapProcess.terminationHandler = { _ in
                if self.dapHasDisconnected {
                    log("exiting normally")
                    self.terminate(exitStatus: 0)
                }
                else {
                    log("dap process finished unexpectedly; exiting")
                    self.terminate(exitStatus: 1)
                }
            }

            try lldbDapProcess.run()

            RunLoop.main.run()
        }
        catch {
            handleError("\(error)")
            // won't get this far, but the compiler doesn't know that:
            fatalError()
        }
    }

    func launchAndAttach(args: [String]?) {
        DispatchQueue(label: "launch", qos: .userInteractive).async { [self] in
            do {
                let launchProcess = Process()
                launchProcess.executableURL = files.buildRunScript
                launchProcess.arguments = ["_debug"] + (args ?? [])
                launchProcess.standardInput = FileHandle.nullDevice

                let errPipe = Pipe()
                launchProcess.standardError = errPipe.fileHandleForWriting

                errPipe.fileHandleForReading.readLines(label: "xc err", errorHandler: handleError) {
                    log("⚪️ \($0)")
                    // Was sending these as output messages but that caused parse errors in zed!
                    // At least when set -x is used in the script.
                    if !$0.hasPrefix("+") {
                        try self.stdoutWriter.writeMessage(encodable: OutputMessage(body: StdoutMessage(output: String($0))))
                    }
                }

                let outPipe = Pipe()
                launchProcess.standardOutput = outPipe.fileHandleForWriting
                let inp = outPipe.fileHandleForReading

                try launchProcess.run()
                var launched = false
                while let data = try inp.read(until: "\n".data) {
                    let line = String(try data.string.dropLast())

                    guard line.hasPrefix(ParamLinePrefix) else {
                        if launched {
                            // This is the launched process's output; don't logg it.
                            stdoutWriter.logNext = false
                        }
                        try stdoutWriter.writeMessage(encodable: OutputMessage(body: StdoutMessage(output: line)))
                        continue
                    }

                    log("*** Attaching...")
                    let bits = line.split(separator: ":")
                    guard bits.count >= 2 else { throw DapError(line) }
                    self.platform = String(bits[1])
                    switch self.platform! {
                        case "device":
                            guard bits.count == 4 else { throw DapError(line) }
                            let deviceId = String(bits[2])
                            let processName = String(bits[3])

                            /*
                            Rather than running a python script, which seems over-complicated, I though we might be able to do this:

                            try dapWriter.evaluate("platform select remote-ios")
                            try dapWriter.evaluate("device select \(deviceId)")
                            try dapWriter.evaluate("device process attach --name \(processName)")

                            but it doesn't find the process and/or message about a process being killed (even though
                            the app has been launched).

                            So the extra timing checks and stuff in the script are necessary. Will stick with the
                            working script rather than trying to replicate all that in here.
                            */

                            // Write params to a file. The python will read the file. There's no conventional way to pass it params.
                            try? FileManager.default.createDirectory(atPath: (AttachParamsFile as NSString).deletingLastPathComponent, withIntermediateDirectories: false)
                            try "\(deviceId)\n\(processName)".write(toFile: AttachParamsFile, atomically: false, encoding: .utf8)

                            ourAttachRequestSeq = takeSeq()
                            try dapWriter.writeCommand("attach", args: ["attachCommands": ["command script import '\(files.deviceAttachScript.pathEscapingSingleQuotes)'"]], seq: ourAttachRequestSeq!)

                        case "sim":
                            guard bits.count == 3, let pid = Int(bits[2]) else { throw DapError(line) }

                            try dapWriter.writeCommand("evaluate", args: EvaluateCommandArgs(expression: "platform select ios-simulator"), seq: takeSeq())

                            ourAttachRequestSeq = takeSeq()
                            try dapWriter.writeCommand("attach", args: ["pid": pid], seq: ourAttachRequestSeq!)

                        case "mac":
                            guard bits.count == 3 else { throw DapError(line) }
                            let path = String(bits[2])

                            try dapWriter.writeCommand("evaluate", args: EvaluateCommandArgs(expression: "platform select host"), seq: takeSeq())

                            ourAttachRequestSeq = takeSeq()
                            try dapWriter.writeCommand("launch", args: ["program": path], seq: ourAttachRequestSeq!)

                        default:
                            throw DapError("bad: \(line)")
                    }
                    launched = true
                }
            }
            catch {
                handleError("launch failed: \(error)")
            }
        }
    }

    var seq = FirstSeq

    func takeSeq() -> Int {
        seq += 1
        return seq - 1
    }

    func terminate(exitStatus: Int32) {
        Logger.instance.close()
        exit(exitStatus)
    }

    static func main() {
        _ = DapWrapMain()
    }
}

fileprivate let FirstSeq = 1_000_000

fileprivate struct OtherFiles {
    var binDir: URL
    var buildRunScript: URL { binDir.appending(component: "xcede") }
    var deviceAttachScript: URL { binDir.appending(component: "xcede_attach_device.py") }

    init() throws {
        // Release-time file structure:
        binDir = URL(filePath: CommandLine.arguments[0]).deletingLastPathComponent()

        // Try build-time structure
        if !buildRunScript.fileExists {
            log("script not in \(binDir)")
            binDir = binDir.deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(component: "bin")
            if !buildRunScript.fileExists {
                log("script not in \(binDir) either")
                throw DapError("I'm being run from an unexpected location. Giving up.")
            }
        }
    }
}
