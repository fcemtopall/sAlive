import Foundation

/// Wrapper around /usr/bin/pmset. Arguments are fixed – no user input is ever
/// passed to a shell.
enum Pmset {
    static let path = "/usr/bin/pmset"

    struct Failure: LocalizedError {
        let status: Int32
        let output: String
        var errorDescription: String? { "pmset failed (\(status)): \(output)" }
    }

    /// Looks for the `SleepDisabled  1` line in `pmset -g` output.
    static func parseSleepDisabled(_ output: String) -> Bool {
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.first == "SleepDisabled" {
                return parts.dropFirst().first == "1"
            }
        }
        return false
    }

    @discardableResult
    static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw Failure(status: process.terminationStatus, output: output)
        }
        return output
    }

    static func isSleepDisabled() -> Bool {
        (try? run(["-g"])).map(parseSleepDisabled) ?? false
    }

    static func setSleepDisabled(_ disabled: Bool) throws {
        try run(["-a", "disablesleep", disabled ? "1" : "0"])
    }
}
