import Foundation

let usage = """
usage: salive <command>

  on [DURATION]        Keep the Mac awake (optionally for DURATION, e.g. 30m, 2h, 1h30m)
  on --for DURATION    Same as above
  off                  Restore normal sleep
  toggle               Flip the current state
  status               Show current state (default)
  battery <N|off>      Turn keep-awake off automatically at N% battery
  version              Print version

"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("salive: \(message)\n".utf8))
    exit(1)
}

func show(_ status: KeepAwakeStatus) {
    var line = "Keep awake: " + (status.enabled ? "ON" : "OFF")
    if status.enabled, let remaining = status.remaining {
        line += " (turns off in \(DurationFormat.format(remaining)))"
    } else if status.enabled {
        line += " (until turned off)"
    }
    print(line)
    print("Battery cutoff: " + (status.batteryThreshold.map { "\($0)%" } ?? "off"))
}

var args = Array(CommandLine.arguments.dropFirst())
let command = args.isEmpty ? "status" : args.removeFirst()

do {
    switch command {
    case "on":
        var duration: TimeInterval?
        if args.first == "--for" || args.first == "-f" { args.removeFirst() }
        if let raw = args.first {
            guard let parsed = DurationFormat.parse(raw) else { fail("invalid duration '\(raw)'") }
            duration = parsed
        }
        show(try await HelperClient.setKeepAwake(true, duration: duration))
    case "off":
        show(try await HelperClient.setKeepAwake(false))
    case "toggle":
        let current = try await HelperClient.status()
        show(try await HelperClient.setKeepAwake(!current.enabled))
    case "status":
        show(try await HelperClient.status())
    case "battery":
        guard let raw = args.first else { fail("usage: salive battery <N|off>") }
        if raw == "off" || raw == "0" {
            show(try await HelperClient.setBatteryThreshold(nil))
        } else {
            guard let percent = Int(raw.trimmingCharacters(in: CharacterSet(charactersIn: "%"))),
                  (1...99).contains(percent) else { fail("battery threshold must be 1-99 or 'off'") }
            show(try await HelperClient.setBatteryThreshold(percent))
        }
    case "version", "--version", "-v":
        print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
    case "help", "--help", "-h":
        print(usage, terminator: "")
    default:
        FileHandle.standardError.write(Data(usage.utf8))
        exit(2)
    }
} catch let error as HelperError where error.isUnavailable {
    fail("\(error.localizedDescription)\nOpen sAlive.app once and allow its helper in System Settings › General › Login Items & Extensions.")
} catch {
    fail(error.localizedDescription)
}
