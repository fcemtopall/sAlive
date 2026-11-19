import SwiftUI

/// macOS doesn't let apps add Control Center buttons themselves – the user has
/// to add "Keep Awake" manually. This box explains how.
struct ControlCenterInstructions: View {
    private let steps: [LocalizedStringKey] = [
        "Click the **Control Center** icon in the menu bar (the two switches, top right).",
        "Scroll down and click **Edit Controls**.",
        "Search for **sAlive** and click **Keep Awake** – or drag it into Control Center.",
        "Click **Done**. Optionally drag it into the menu bar for one-click access.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("The button isn't added automatically", systemImage: "info.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.blue)
            Text("macOS only lets you add Control Center buttons yourself:")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                    Text(text).fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.blue.opacity(0.25)))
    }
}
