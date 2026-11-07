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
                manager.setCountdownPreset(max(5, h * 60 + m))
            }
        )
    }

    private var countdownMinutes: Binding<Int> {
        Binding(
            get: { Int(manager.countdownTotal.truncatingRemainder(dividingBy: 3600) / 60) },
            set: { m in
                let h = Int(manager.countdownTotal / 3600)
                manager.setCountdownPreset(max(5, h * 60 + m))
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HoverTime").font(.largeTitle.weight(.semibold))
                    Text("A little time. A little more focus.").foregroundStyle(.secondary)
                    Text("Drag the floating time to move it. Click it for quick controls.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                modeSection
                appearanceSection
                if manager.mode == .clock { clockSection }
                if manager.mode == .countdown { countdownSection }
                generalSection
            }
            .padding(24)
        }
        .frame(minWidth: 400, maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.blue)
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
            if manager.mode != .clock {
                HStack {
                    Text(manager.mode == .countdown ? TimerManager.formatTime(manager.countdownRemaining) : manager.stopwatchDisplayString)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Button("Reset", action: manager.resetCurrent)
                    Button((manager.mode == .countdown ? manager.countdownRunning : manager.stopwatchRunning) ? "Pause" : "Start", action: manager.toggleStartPause)
                        .buttonStyle(.borderedProminent)
                }
                if manager.mode == .countdown {
                    ProgressView(value: manager.countdownProgress)
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsSection("Appearance") {
            GeometryReader { geometry in
                let size = ContentView(manager: manager).displaySize
                ContentView(manager: manager)
                    .scaleEffect(min(1, min((geometry.size.width - 24) / size.width, 88 / size.height)))
                    .frame(width: geometry.size.width, height: 110)
                    .allowsHitTesting(false)
            }
            .frame(height: 110)
            .background(manager.displayColor == .porcelain ? Color(white: 0.14) : Color(red: 0.96, green: 0.95, blue: 0.92), in: RoundedRectangle(cornerRadius: 12))

            AppearanceControls(manager: manager)

            Picker("Lettering", selection: $manager.displayRendering) {
                ForEach(DisplayRendering.allCases, id: \.self) { rendering in
                    Text(rendering.rawValue).tag(rendering)
                }
            }
            .pickerStyle(.segmented)
            Text("Paired colors adapt gently to the background. Outline keeps the centers of the digits clear.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Opacity")
                Slider(value: $manager.windowOpacity, in: 0.3...1.0, step: 0.05)
                Text("\(Int(manager.windowOpacity * 100))%")
                    .frame(width: 40)
                    .foregroundStyle(.secondary)
            }

            Toggle("Soft text shadow", isOn: $manager.showShadow)
            Toggle("Show seconds", isOn: $manager.showSeconds)
        }
    }

    // MARK: - Clock

    private var clockSection: some View {
        settingsSection("Clock") {
            Picker("Time zone", selection: $manager.utcOffsetMinutes) {
                Text("Local time (automatic)").tag(nil as Int?)
                ForEach(TimerManager.utcOffsets, id: \.self) { offset in
                    Text(TimerManager.utcOffsetTitle(offset)).tag(Optional(offset))
                }
            }
            .pickerStyle(.menu)
            Text("UTC offsets are fixed and do not change for daylight saving time.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            Text("When finished, the timer resets to your duration. Auto-repeat starts the next countdown immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(manager.countdownRunning)
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
            if manager.clickThrough {
                Label("Dragging is off. Turn off click-through here or in the menu bar to move the timer.", systemImage: "cursorarrow")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Visual interval reminder", isOn: $manager.reminderEnabled)
                .onChange(of: manager.reminderEnabled) { _, _ in manager.rescheduleReminder() }
            if manager.reminderEnabled {
                Stepper("Reminder interval: \(manager.reminderIntervalMinutes) min", value: $manager.reminderIntervalMinutes, in: 1...120, step: 1)
                    .onChange(of: manager.reminderIntervalMinutes) { _, _ in manager.rescheduleReminder() }
                Text("Clock: fires on wall-clock marks (:00, :05, :10…). Timer/Stopwatch: counts from the start of the run. The floating timer shows a bright visual banner for 8 seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle("Show in Dock", isOn: $manager.showDockIcon)

            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcuts while the menu is open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                shortcutRow("Show/Hide", "⌘H")
                shortcutRow("Start/Pause", "⌘P")
                shortcutRow("Settings", "⌘,")
                shortcutRow("Reset", "⌘R")
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
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

    private func adjustFontSize(by delta: CGFloat) {
        let rounded = (manager.fontSize / 5).rounded() * 5
        manager.fontSize = min(200, max(40, rounded + delta))
    }
}
