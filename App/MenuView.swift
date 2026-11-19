import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var store: StatusStore
    @EnvironmentObject private var helper: HelperManager
    @AppStorage(Placement.defaultsKey) private var placement: Placement = .both

    /// The setup window embeds this view without the Setup/Quit footer.
    var showsFooter = true

    private let presets: [(String, TimeInterval?)] = [
        ("30m", 1800), ("1h", 3600), ("3h", 10800), ("8h", 28800), ("∞", nil),
    ]
    private let thresholds: [Int] = [0, 10, 20, 30, 50]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !helper.isReady {
                helperWarning
            } else {
                Divider()
                durationSection
                Divider()
                settingsSection
            }

            if let error = store.lastError ?? helper.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsFooter {
                Divider()
                HStack {
                    Button("Setup…") { OnboardingWindow.show() }
                    Spacer()
                    Button("Quit sAlive") { NSApp.terminate(nil) }
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 300)
        .task {
            helper.refresh()
            await store.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: store.isOn ? "cup.and.saucer.fill" : "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(store.isOn ? Color.orange : Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep Awake").font(.headline)
                subtitle.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.isOn },
                set: { on in Task { await store.setOn(on) } }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(!helper.isReady || store.busy)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let until = store.status?.until, store.isOn {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text("Turns off in \(DurationFormat.format(max(0, until.timeIntervalSinceNow)))")
            }
        } else if store.isOn {
            Text("Mac will not sleep, even with the lid closed")
        } else {
            Text("Normal sleep behavior")
        }
    }

    private var helperWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(helper.statusText, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
            Button(helper.status == .requiresApproval ? "Open System Settings" : "Install Helper") {
                if helper.status == .requiresApproval { helper.openSettings() } else { helper.register() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Keep awake for").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(presets, id: \.0) { preset in
                    Button(preset.0) { Task { await store.setOn(true, duration: preset.1) } }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(store.busy)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Turn off when battery ≤", selection: Binding(
                get: { store.status?.batteryThreshold ?? 0 },
                set: { value in Task { await store.setBatteryThreshold(value == 0 ? nil : value) } }
            )) {
                ForEach(thresholds, id: \.self) { value in
                    Text(value == 0 ? "Never" : "\(value)%").tag(value)
                }
            }
            .controlSize(.small)

            Picker("Show in", selection: $placement) {
                ForEach(Placement.allCases) { Text($0.title).tag($0) }
            }
            .controlSize(.small)

            if placement.usesControlCenter {
                Button {
                    OnboardingWindow.show()
                } label: {
                    Label("Add the button: Control Center › Edit Controls › sAlive",
                          systemImage: "info.circle")
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.link)
                .help("Show step-by-step instructions")
            }

            Toggle("Launch at login", isOn: Binding(
                get: { helper.launchAtLogin },
                set: { helper.setLaunchAtLogin($0) }
            ))
            .controlSize(.small)
        }
    }
}
