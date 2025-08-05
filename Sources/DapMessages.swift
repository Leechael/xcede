let LengthLinePrefix = "Content-Length: "
/// I hate you, Microsoft:
let LengthLineSuffix = "\r\n\r\n"

enum MsgType: String, Codable {
    case request, response, event
}

struct Command<T: Codable>: Codable {
    let command: String
    let arguments: T
    let type: MsgType
    let seq: Int
}

struct LaunchCommandArgs: Codable {
    let program: String
    let args: [String]?
}

struct EvaluateCommandArgs: Codable {
    let expression: String
    var context = "repl"
}

struct OutputMessage<B: Encodable>: Encodable {
    let body: B
    let event = "output"
    let seq = 0
    let type = "event"
}

struct StdoutMessage: Encodable {
    let category = "stdout"
    let output: String
}

struct StderrMessage: Encodable {
    let category = "stderr"
    let output: String
}
