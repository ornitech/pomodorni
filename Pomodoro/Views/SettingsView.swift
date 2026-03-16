import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                durationSection
                Divider()
                behaviorSection
                Divider()
                appearanceSection
                Divider()
                shortcutsSection
            }
            .padding()
        }
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Settings")
                .font(.headline)
            Spacer()
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Durations")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            durationRow(label: "Work", value: $settings.workDuration, range: 1...60, unit: "min")
            durationRow(label: "Short Break", value: $settings.shortBreakDuration, range: 1...30, unit: "min")
            durationRow(label: "Long Break", value: $settings.longBreakDuration, range: 1...60, unit: "min")

            HStack {
                Text("Long break every")
                Stepper("\(settings.longBreakInterval) sessions", value: $settings.longBreakInterval, in: 1...10)
            }
            .font(.callout)
        }
    }

    private func durationRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.callout.monospacedDigit())
                .frame(width: 50, alignment: .trailing)
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            .frame(width: 100)
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Behavior")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Toggle("Auto-start next session", isOn: $settings.autoStartEnabled)
                .font(.callout)
            Toggle("Play sounds", isOn: $settings.soundEnabled)
                .font(.callout)
            Toggle("Show time in menu bar", isOn: $settings.showTimeInMenuBar)
                .font(.callout)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Picker("Theme", selection: $settings.selectedTheme) {
                ForEach(ThemeIdentifier.allCases, id: \.self) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            shortcutRow(label: "Start / Pause", shortcut: "\u{2303}\u{2325}P")
            shortcutRow(label: "Skip", shortcut: "\u{2303}\u{2325}S")
            shortcutRow(label: "Reset", shortcut: "\u{2303}\u{2325}R")
        }
    }

    private func shortcutRow(label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Text(shortcut)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
        }
    }
}
