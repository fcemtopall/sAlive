import SwiftUI

@main
struct SAliveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = StatusStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(StatusStore.shared)
                .environmentObject(HelperManager.shared)
        } label: {
            Image(systemName: store.isOn ? "cup.and.saucer.fill" : "moon.zzz")
                .accessibilityLabel(store.isOn ? Text("sAlive: keeping Mac awake") : Text("sAlive: off"))
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            HelperManager.shared.refresh()
            StatusStore.shared.start()
            if !HelperManager.shared.isReady {
                OnboardingWindow.show()
                // Don't make the user hunt for a button: register right away.
                // macOS then shows its approval prompt / we open System Settings
                // at Login Items, so all that's left is flipping one switch.
                HelperManager.shared.beginSetup()
            }
        }
    }

    /// Opening sAlive again from Finder/Spotlight shows the setup window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { OnboardingWindow.show() }
        return true
    }
}
