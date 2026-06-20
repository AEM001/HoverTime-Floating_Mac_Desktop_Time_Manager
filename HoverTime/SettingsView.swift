//
//  SettingsView.swift
//  HoverTime
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: TimerManager

    private var countdownHours: Binding<Int> {
        Binding(
            get: { Int(manager.countdownTotal / 3600) },
            set: { h in
                let m = Int(manager.countdownTotal.truncatingRemainder(dividingBy: 3600) / 60)
                manager.countdownTotal = TimeInterval(h * 3600 + m * 60)
                if !manager.countdownRunning && !manager.countdownPaused {
                    manager.countdownRemaining = manager.countdownTotal
                }
            }
        )
    }

    private var countdownMinutes: Binding<Int> {
        Binding(
            get: { Int(manager.countdownTotal.truncatingRemainder(dividingBy: 3600) / 60) },
            set: { m in
                let h = Int(manager.countdownTotal / 3600)
                manager.countdownTotal = TimeInterval(h * 3600 + m * 60)
                if !manager.countdownRunning && !manager.countdownPaused {
                    manager.countdownRemaining = manager.countdownTotal
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                modeSection
                Divider().padding(.vertical, 4)
                appearanceSection
                Divider().padding(.vertical, 4)
                clockSection
                Divider().padding(.vertical, 4)
                countdownSection
                Divider().padding(.vertical, 4)
                stopwatchSection
                Divider().padding(.vertical, 4)
                generalSection
            }
            .padding(20)
        }
        .frame(minWidth: 400, maxWidth: .infinity)
        .onDisappear {
            manager.saveSettings()
        }
    }

    // MARK: - Mode

    private var modeSection: some View {
        settingsSection("Mode") {
            Picker("", selection: $manager.mode) {
                ForEach(TimeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsSection("Appearance") {
            HStack {
                Text("Color")
                    .frame(width: 80, alignment: .leading)
                HStack(spacing: 10) {
                    ForEach(DisplayColor.allCases, id: \.self) { color in
                        Button(action: { manager.displayColor = color }) {
                            Circle()
                                .fill(swatchColor(for: color))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(.primary.opacity(manager.displayColor == color ? 0.9 : 0.0), lineWidth: 2)
                                        .frame(width: 28, height: 28)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(color.rawValue)
                    }
                }
            }

            Picker("Typeface", selection: $manager.displayFont) {
                ForEach(DisplayFont.allCases, id: \.self) { font in
                    Text(font.rawValue).tag(font)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text("Font size")
                Button {
                    adjustFontSize(by: -5)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Text("\(Int(manager.fontSize))")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 46)
                    .foregroundStyle(.secondary)
                Button {
                    adjustFontSize(by: 5)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack {
                Text("Opacity")
                Slider(value: $manager.windowOpacity, in: 0.1...1.0, step: 0.05)
                Text("\(Int(manager.windowOpacity * 100))%")
                    .frame(width: 40)
                    .foregroundStyle(.secondary)
            }

            Toggle("Background blur", isOn: $manager.showShadow)
            Toggle("Show seconds", isOn: $manager.showSeconds)
        }
    }

    // MARK: - Clock

    private var clockSection: some View {
        settingsSection("Clock") {
            Toggle("24-hour format", isOn: $manager.use24Hour)
            Toggle("Show date", isOn: $manager.showDate)
        }
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        settingsSection("Countdown") {
            HStack(spacing: 16) {
                Text("Duration")
                Spacer()
                
                TimePickerField(
                    label: "Hours",
                    value: countdownHours,
                    options: Array(0...23),
                    suffix: "h"
                )
                
                Text(":").font(.title2).foregroundStyle(.secondary)
                
                TimePickerField(
                    label: "Minutes",
                    value: countdownMinutes,
                    options: Array(stride(from: 0, through: 55, by: 5)),
                    suffix: "m"
                )
            }

            HStack(spacing: 8) {
                Text("Presets:")
                    .foregroundStyle(.secondary)
                ForEach([5, 10, 25, 45, 60], id: \.self) { mins in
                    Button("\(mins)m") {
                        manager.setCountdownPreset(mins)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Toggle("Auto-repeat", isOn: $manager.countdownAutoRepeat)
        }
    }

    // MARK: - Stopwatch

    private var stopwatchSection: some View {
        settingsSection("Stopwatch") {
            Text("Stopwatch follows the global seconds setting.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        settingsSection("General") {
            Toggle("Sound notifications", isOn: $manager.soundEnabled)
            Toggle("Click-through mode", isOn: $manager.clickThrough)
            Toggle("Reminder pulse", isOn: $manager.reminderEnabled)
                .onChange(of: manager.reminderEnabled) { _, _ in manager.rescheduleReminder() }
            if manager.reminderEnabled {
                Stepper("Reminder interval: \(manager.reminderIntervalMinutes) min", value: $manager.reminderIntervalMinutes, in: 1...120, step: 1)
                    .onChange(of: manager.reminderIntervalMinutes) { _, _ in manager.rescheduleReminder() }
            }
            Toggle("Show in Dock", isOn: $manager.showDockIcon)

            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcuts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                shortcutRow("Show/Hide", "⌘⇧T")
                shortcutRow("Start/Pause", "⌘⇧S")
                shortcutRow("Cycle Mode", "⌘⇧M")
                shortcutRow("Reset", "⌘⇧R")
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            content()
        }
    }

    private func shortcutRow(_ label: String, _ shortcut: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private func swatchColor(for color: DisplayColor) -> Color {
        switch color {
        case .porcelain: return Color(red: 0.92, green: 0.90, blue: 0.84)
        case .graphite: return Color(red: 0.70, green: 0.72, blue: 0.70)
        case .sage: return Color(red: 0.66, green: 0.73, blue: 0.66)
        case .copper: return Color(red: 0.76, green: 0.55, blue: 0.41)
        }
    }

    private func adjustFontSize(by delta: CGFloat) {
        let rounded = (manager.fontSize / 5).rounded() * 5
        manager.fontSize = min(200, max(40, rounded + delta))
    }
}
