import Foundation

/// XPC interface exposed by the privileged helper.
/// Every reply carries either a JSON-encoded `KeepAwakeStatus` or an error message.
@objc protocol HelperProtocol {
    func getStatus(reply: @escaping (Data?, String?) -> Void)

    /// `durationSeconds <= 0` means "until turned off".
    func setKeepAwake(_ enabled: Bool, durationSeconds: Double, reply: @escaping (Data?, String?) -> Void)

    /// `percent` in 1...99 enables the low-battery cutoff, anything else disables it.
    func setBatteryThreshold(_ percent: Int, reply: @escaping (Data?, String?) -> Void)
}

struct KeepAwakeStatus: Codable, Equatable {
    /// Real system state, read from `pmset -g` (SleepDisabled).
    var enabled: Bool
    /// When a timed session ends, nil = indefinite.
    var until: Date?
    /// Low-battery cutoff in percent, nil = off.
    var batteryThreshold: Int?
    var helperVersion: String

    var remaining: TimeInterval? {
        until.map { max(0, $0.timeIntervalSinceNow) }
    }
}
