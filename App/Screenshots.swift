#if DEBUG
import AppKit

/// Debug-only helpers for capturing README screenshots without needing
/// Accessibility permission to click the menu bar:
///
///     sAlive.app/Contents/MacOS/sAlive -SAliveShowMenu YES
///     sAlive.app/Contents/MacOS/sAlive -SAliveShowSetup YES
@MainActor
enum Screenshots {
    static func runIfRequested() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "SAliveShowSetup") {
            OnboardingWindow.show()
        }
        if defaults.bool(forKey: "SAliveShowMenu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { openMenu() }
        }
    }

    /// Clicks the MenuBarExtra's status item from inside the process.
    private static func openMenu() {
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBarWindow") {
            if let button = findButton(in: window.contentView) {
                button.performClick(nil)
                return
            }
        }
    }

    private static func findButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for sub in view.subviews {
            if let found = findButton(in: sub) { return found }
        }
        return nil
    }
}
#endif
