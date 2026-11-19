import Foundation
import notify
import os

private let log = Logger(subsystem: SAlive.helperMachService, category: "helper")

/// State that must survive helper restarts and reboots.
private struct PersistedState: Codable {
    var until: Date?
    var batteryThreshold: Int?

    static let directory = URL(fileURLWithPath: "/Library/Application Support/sAlive", isDirectory: true)
    static let file = directory.appendingPathComponent("state.json")

    static func load() -> PersistedState {
        guard let data = try? Data(contentsOf: file),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return PersistedState() }
        return state
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(self).write(to: Self.file, options: .atomic)
        } catch {
            log.error("Could not save state: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Runs as root (launchd daemon registered via SMAppService). All state is
/// confined to a single serial queue.
final class HelperService: NSObject, HelperProtocol {
    private let queue = DispatchQueue(label: "io.github.fcemtopall.salive.helper.state")
    private var state = PersistedState.load()
    private var timer: DispatchSourceTimer?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    func start() {
        queue.async { self.reconcile() }
        Battery.observe { [weak self] in
            self?.queue.async { self?.enforceBatteryThreshold() }
        }
    }

    // MARK: HelperProtocol

    func getStatus(reply: @escaping (Data?, String?) -> Void) {
        queue.async { reply(self.encodedStatus(), nil) }
    }

    func setKeepAwake(_ enabled: Bool, durationSeconds: Double, reply: @escaping (Data?, String?) -> Void) {
        queue.async {
            do {
                if enabled {
                    if let message = self.batteryBlockReason() {
                        reply(nil, message)
                        return
                    }
                    try Pmset.setSleepDisabled(true)
                    if durationSeconds.isFinite, durationSeconds > 0 {
                        let until = Date().addingTimeInterval(min(durationSeconds, SAlive.maxDuration))
                        self.state.until = until
                        self.schedule(until)
                    } else {
                        self.state.until = nil
                        self.cancelTimer()
                    }
                    log.info("Keep awake ON, until: \(String(describing: self.state.until), privacy: .public)")
                } else {
                    try Pmset.setSleepDisabled(false)
                    self.state.until = nil
                    self.cancelTimer()
                    log.info("Keep awake OFF")
                }
                self.state.save()
                self.postChanged()
                reply(self.encodedStatus(), nil)
            } catch {
                log.error("pmset error: \(error.localizedDescription, privacy: .public)")
                reply(nil, error.localizedDescription)
            }
        }
    }

    func setBatteryThreshold(_ percent: Int, reply: @escaping (Data?, String?) -> Void) {
        queue.async {
            self.state.batteryThreshold = (1...99).contains(percent) ? percent : nil
            self.state.save()
            self.enforceBatteryThreshold()
            self.postChanged()
            reply(self.encodedStatus(), nil)
        }
    }

    // MARK: Internals (call on `queue` only)

    private func currentStatus() -> KeepAwakeStatus {
        let enabled = Pmset.isSleepDisabled()
        return KeepAwakeStatus(
            enabled: enabled,
            until: enabled ? state.until : nil,
            batteryThreshold: state.batteryThreshold,
            helperVersion: version
        )
    }

    private func encodedStatus() -> Data? {
        try? JSONEncoder().encode(currentStatus())
    }

    /// Brings the timer in line with the persisted state after launch/reboot.
    private func reconcile() {
        if let until = state.until {
            if !Pmset.isSleepDisabled() {
                state.until = nil          // turned off from outside
                state.save()
            } else if until <= Date() {
                turnOff(reason: "timer expired while helper was not running")
            } else {
                schedule(until)
            }
        }
        enforceBatteryThreshold()
    }

    private func batteryBlockReason() -> String? {
        guard let threshold = state.batteryThreshold else { return nil }
        let battery = Battery.current()
        guard battery.onBattery, let percent = battery.percent, percent <= threshold else { return nil }
        return "Battery is at \(percent)%, at or below your \(threshold)% cutoff. Plug in or lower the cutoff."
    }

    private func enforceBatteryThreshold() {
        guard batteryBlockReason() != nil, Pmset.isSleepDisabled() else { return }
        turnOff(reason: "battery below threshold")
    }

    private func turnOff(reason: String) {
        log.info("Turning keep awake off: \(reason, privacy: .public)")
        do {
            try Pmset.setSleepDisabled(false)
        } catch {
            log.error("pmset error: \(error.localizedDescription, privacy: .public)")
        }
        state.until = nil
        cancelTimer()
        state.save()
        postChanged()
    }

    private func schedule(_ date: Date) {
        cancelTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(wallDeadline: .now() + max(0, date.timeIntervalSinceNow))
        timer.setEventHandler { [weak self] in self?.turnOff(reason: "timer expired") }
        timer.resume()
        self.timer = timer
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    private func postChanged() {
        notify_post(SAlive.changedNotification)
    }
}
