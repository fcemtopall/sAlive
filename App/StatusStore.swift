import Foundation
import notify
import WidgetKit

/// Mirrors the helper's state for the UI and keeps the Control Center
/// toggle in sync whenever anything (app, control, CLI, timer, battery)
/// changes it.
@MainActor
final class StatusStore: ObservableObject {
    static let shared = StatusStore()

    @Published private(set) var status: KeepAwakeStatus?
    @Published private(set) var lastError: String?
    @Published private(set) var busy = false

    var isOn: Bool { status?.enabled ?? false }

    private var notifyToken: Int32 = 0
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        notify_register_dispatch(SAlive.changedNotification, &notifyToken, .main) { _ in
            Task { @MainActor in
                await StatusStore.shared.refresh()
                ControlCenter.shared.reloadControls(ofKind: SAlive.controlKind)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        do {
            status = try await HelperClient.status()
            lastError = nil
        } catch {
            status = nil
            // Missing helper is shown separately by HelperManager.
            if let e = error as? HelperError, e.isUnavailable {
                lastError = nil
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func setOn(_ on: Bool, duration: TimeInterval? = nil) async {
        await perform { try await HelperClient.setKeepAwake(on, duration: duration) }
    }

    func setBatteryThreshold(_ percent: Int?) async {
        await perform { try await HelperClient.setBatteryThreshold(percent) }
    }

    private func perform(_ action: () async throws -> KeepAwakeStatus) async {
        busy = true
        defer { busy = false }
        do {
            status = try await action()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
