import SwiftUI

/// Setup + settings window. Shown on first launch, from the menu's "Setup…",
/// and whenever the app is reopened (the only entry point when the menu bar
/// icon is hidden).
@MainActor
enum OnboardingWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let root = OnboardingView(close: { window?.close() })
                .environmentObject(StatusStore.shared)
                .environmentObject(HelperManager.shared)
            let hosting = NSHostingController(rootView: root)
            // Fixed window size: letting SwiftUI resize the window causes an
            // update-constraints feedback loop on macOS 26. Content scrolls instead.
            hosting.sizingOptions = []
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.setContentSize(NSSize(width: 520, height: 660))
            newWindow.title = "sAlive"
            newWindow.styleMask = [.titled, .closable]
            newWindow.isReleasedWhenClosed = false
            window = newWindow
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

struct OnboardingView: View {
    let close: () -> Void
    @EnvironmentObject private var helper: HelperManager
    @AppStorage(Placement.defaultsKey) private var placement: Placement = .both
    @State private var showUninstallConfirm = false

    private let poll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            content
        }
        .frame(width: 520, height: 660)
        .onReceive(poll) { _ in
            let wasReady = helper.isReady
            helper.refresh()
            if !wasReady && helper.isReady {
                Task { await StatusStore.shared.refresh() }
            }
        }
        .confirmationDialog("Uninstall the sAlive helper?", isPresented: $showUninstallConfirm) {
            Button("Uninstall", role: .destructive) { Task { await helper.unregister() } }
        } message: {
            Text("Keep-awake will be turned off. You can reinstall it any time from this window.")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("sAlive").font(.largeTitle.bold())
                    Text("Keep your Mac awake – even with the lid closed.")
                        .foregroundStyle(.secondary)
                }
            }

            step(1, title: "Install the helper",
                 detail: "sAlive uses a tiny background helper to run `pmset disablesleep` for you, so you never need a password or Terminal. macOS will ask you to allow it once in System Settings › General › Login Items & Extensions.") {
                HStack {
                    Label(helper.statusText,
                          systemImage: helper.isReady ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(helper.isReady ? .green : .secondary)
                    Spacer()
                    if !helper.isReady {
                        Button(helper.status == .requiresApproval ? "Open System Settings" : "Install Helper") {
                            if helper.status == .requiresApproval { helper.openSettings() } else { helper.register() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            step(2, title: "Choose where sAlive appears",
                 detail: "The Control Center button works on its own – the app doesn't even need to be running.") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $placement) {
                        ForEach(Placement.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    if placement.usesControlCenter {
                        ControlCenterInstructions()
                    }

                    Text(placementHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if helper.isReady && !placement.showsMenuBar {
                GroupBox("Controls") {
                    MenuView(showsFooter: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Label("With sleep disabled your Mac stays fully on when the lid is closed. Don't leave it running in a bag – use a timer or the low-battery cutoff.",
                  systemImage: "thermometer.high")
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            if let error = helper.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                if helper.status == .enabled || helper.status == .requiresApproval {
                    Button("Uninstall Helper…", role: .destructive) { showUninstallConfirm = true }
                        .buttonStyle(.borderless)
                }
                Spacer()
                if !placement.showsMenuBar {
                    Button("Quit sAlive") { NSApp.terminate(nil) }
                }
                Button("Done", action: close)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var placementHint: String {
        switch placement {
        case .both:
            return "The menu bar icon is always there; the Control Center button works too once you add it."
        case .controlCenter:
            return "The menu bar icon is hidden – open sAlive again from Applications to get back to these settings."
        case .menuBar:
            return "Use the menu bar icon. If you added the Control Center button before, remove it via Control Center › Edit Controls."
        }
    }

    private func step<Content: View>(_ number: Int, title: String, detail: LocalizedStringKey,
                                     @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                content()
            }
        }
    }
}
