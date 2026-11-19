import Foundation
import ServiceManagement

/// Registers / unregisters the root helper via SMAppService. The user approves
/// it once in System Settings › General › Login Items & Extensions.
@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    private let daemon = SMAppService.daemon(plistName: SAlive.helperPlistName)

    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var lastError: String?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    var isReady: Bool { status == .enabled }

    var statusText: String {
        switch status {
        case .enabled: return "Helper is running"
        case .requiresApproval: return "Waiting for your approval in System Settings"
        case .notRegistered: return "Helper is not installed"
        case .notFound: return "Helper not found – move sAlive to /Applications"
        @unknown default: return "Unknown helper state"
        }
    }

    func refresh() {
        status = daemon.status
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func register() {
        lastError = nil
        do {
            try daemon.register()
        } catch {
            // Registering while approval is pending throws; that is expected.
            if daemon.status != .requiresApproval {
                lastError = error.localizedDescription
            }
        }
        refresh()
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Turns keep-awake off first so the Mac is never left unable to sleep.
    func unregister() async {
        lastError = nil
        _ = try? await HelperClient.setKeepAwake(false)
        do {
            try await daemon.unregister()
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}
