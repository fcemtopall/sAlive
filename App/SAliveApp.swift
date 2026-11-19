import SwiftUI

@main
struct SAliveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = StatusStore.shared
    @AppStorage(Placement.defaultsKey) private var placement: Placement = .both

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { placement.showsMenuBar },
            // User Cmd-dragged the icon out of the menu bar.
            set: { if !$0 { placement = .controlCenter } }
        )) {
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
        let launchedAtLogin = Self.launchedAsLoginItem()
        MainActor.assumeIsolated {
            HelperManager.shared.refresh()
            StatusStore.shared.start()
            if !HelperManager.shared.isReady {
                OnboardingWindow.show()
            } else if !Placement.current.showsMenuBar && !launchedAtLogin {
                // No menu bar icon: opening the app is the only way to reach settings.
                OnboardingWindow.show()
            }
        }
    }

    /// Opening sAlive again from Finder/Spotlight shows the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { OnboardingWindow.show() }
        return true
    }

    private static func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
