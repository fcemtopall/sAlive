import AppIntents
import SwiftUI
import WidgetKit

@main
struct SAliveControlBundle: WidgetBundle {
    var body: some Widget {
        KeepAwakeControl()
    }
}

struct KeepAwakeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SAlive.controlKind, provider: KeepAwakeValueProvider()) { isOn in
            ControlWidgetToggle("Keep Awake", isOn: isOn, action: SetKeepAwakeIntent()) { on in
                Label(on ? "On" : "Off", systemImage: on ? "cup.and.saucer.fill" : "moon.zzz")
            }
            .tint(.orange)
        }
        .displayName("Keep Awake")
        .description("Prevent your Mac from sleeping, even with the lid closed.")
    }
}

struct KeepAwakeValueProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        (try? await HelperClient.status().enabled) ?? false
    }
}

struct SetKeepAwakeIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Keep Mac Awake"
    static let description = IntentDescription("Turns sAlive's keep-awake mode on or off.")

    @Parameter(title: "Keep Awake")
    var value: Bool

    func perform() async throws -> some IntentResult {
        _ = try await HelperClient.setKeepAwake(value)
        return .result()
    }
}
