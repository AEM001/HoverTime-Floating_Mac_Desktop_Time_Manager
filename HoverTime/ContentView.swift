//
//  ContentView.swift
//  HoverTime
//

import SwiftUI
import AppKit

// MARK: - Control Window (NSPanel, decoupled from floating panel)

class ControlPanelWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titlebarAppearsTransparent = true
        title = "HoverTime Desktop Timer Controls"
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        minSize = NSSize(width: 360, height: 360)
    }
}

// MARK: - Main ContentView (floating display only)

struct ContentView: View {
    @ObservedObject var manager: TimerManager

    var body: some View {
        ZStack {
            if manager.showShadow {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .opacity(0.72)
            }

            if manager.reminderIsActive {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(tintColor.opacity(0.58), lineWidth: 1.5)
                    .scaleEffect(1.08)
                    .opacity(0.65)
                    .transition(.opacity.combined(with: .scale))
            }

            VStack(spacing: 2) {
                switch manager.mode {
                case .clock:     clockView
                case .countdown: countdownView
                case .stopwatch: stopwatchView
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .background(Color.black.opacity(0.001))
        .scaleEffect(manager.reminderIsActive ? 1.025 : 1)
        .animation(.easeInOut(duration: 0.65).repeatCount(4, autoreverses: true), value: manager.reminderPulseID)
        .animation(.easeOut(duration: 0.2), value: manager.reminderIsActive)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 160, minHeight: 44)
    }

    // MARK: - Color & Font Helpers

    var tintColor: Color {
        switch manager.displayColor {
        case .porcelain: return Color(red: 0.92, green: 0.90, blue: 0.84)
        case .graphite: return Color(red: 0.70, green: 0.72, blue: 0.70)
        case .sage: return Color(red: 0.66, green: 0.73, blue: 0.66)
        case .copper: return Color(red: 0.76, green: 0.55, blue: 0.41)
        }
    }

    private var glowColor: Color { tintColor.opacity(0.18) }

    func timeFont(size: CGFloat) -> Font {
        switch manager.displayFont {
        case .newYork:   return .system(size: size, weight: .semibold, design: .serif)
        case .sfProHeavy: return .system(size: size, weight: .semibold, design: .default)
        case .impact:    return Font.custom("Impact", size: size)
        case .arialBlack: return Font.custom("Arial-BoldMT", size: size)
        }
    }

    // MARK: - Clock View

    private var clockView: some View {
        VStack(spacing: 2) {
            Text(manager.clockDisplayString)
                .font(timeFont(size: manager.fontSize))
                .foregroundStyle(tintColor)
                .shadow(color: glowColor, radius: manager.reminderIsActive ? 12 : 4, x: 0, y: 0)
                .shadow(color: .black.opacity(0.32), radius: 1.5, x: 0, y: 1)
            if manager.showDate {
                Text(manager.dateDisplayString)
                    .font(timeFont(size: manager.fontSize * 0.3))
                    .foregroundStyle(tintColor.opacity(0.68))
            }
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        Text(TimerManager.formatTime(manager.countdownRemaining, showSeconds: manager.showSeconds))
            .font(timeFont(size: manager.fontSize))
            .foregroundStyle(tintColor)
            .shadow(color: glowColor, radius: manager.reminderIsActive ? 12 : 4, x: 0, y: 0)
            .shadow(color: .black.opacity(0.32), radius: 1.5, x: 0, y: 1)
    }

    // MARK: - Stopwatch View

    private var stopwatchView: some View {
        Text(manager.stopwatchDisplayString)
            .font(timeFont(size: manager.fontSize))
            .foregroundStyle(tintColor)
            .shadow(color: glowColor, radius: manager.reminderIsActive ? 12 : 4, x: 0, y: 0)
            .shadow(color: .black.opacity(0.32), radius: 1.5, x: 0, y: 1)
    }
}

// MARK: - Control Window Manager (singleton, decoupled from floating panel)

class ControlWindowManager: NSObject {
    static let shared = ControlWindowManager()
    private var window: ControlPanelWindow?
    private var hostingController: NSHostingController<ControlPanelView>?

    func toggle(manager: TimerManager) {
        if let w = window, w.isVisible {
            w.orderOut(nil)
            return
        }
        show(manager: manager)
    }

    func show(manager: TimerManager) {
        if window == nil {
            let win = ControlPanelWindow()
            let view = ControlPanelView(manager: manager, onClose: { [weak win] in win?.orderOut(nil) })
            let controller = NSHostingController(rootView: view)
            win.contentViewController = controller
            window = win
            hostingController = controller
        }
        if let screen = NSScreen.main {
            let frame = window?.frame ?? NSRect(x: 0, y: 0, width: 430, height: 560)
            let x = screen.visibleFrame.midX - frame.width / 2
            let y = screen.visibleFrame.midY - frame.height / 2
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Time Picker Field Component

struct TimePickerField: View {
    let label: String
    @Binding var value: Int
    let options: [Int]
    let suffix: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Button(action: { cycleDown() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("\(value)")
                    .frame(width: 42)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                
                Button(action: { cycleUp() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private func cycleUp() {
        guard let currentIndex = options.firstIndex(of: value) else {
            value = options.first ?? 0
            return
        }
        let nextIndex = (currentIndex + 1) % options.count
        value = options[nextIndex]
    }
    
    private func cycleDown() {
        guard let currentIndex = options.firstIndex(of: value) else {
            value = options.last ?? 0
            return
        }
        let prevIndex = currentIndex == 0 ? options.count - 1 : currentIndex - 1
        value = options[prevIndex]
    }
}

// MARK: - Control Panel SwiftUI View

struct ControlPanelView: View {
    @ObservedObject var manager: TimerManager
    var onClose: () -> Void

    private var countdownHours: Binding<Int> {
        Binding(
            get: { Int(manager.countdownTotal / 3600) },
            set: { h in
                let m = Int(manager.countdownTotal.truncatingRemainder(dividingBy: 3600) / 60)
                manager.countdownTotal = TimeInterval(h * 3600 + m * 60)
                if !manager.countdownRunning && !manager.countdownPaused {
                    manager.countdownRemaining = manager.countdownTotal
                }
                manager.saveSettings()
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
                manager.saveSettings()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                modeSection

                if manager.mode != .clock {
                    transportSection
                }

                glassSection(manager.mode.rawValue, systemImage: modeIcon) {
                    modeSpecificControls
                }

                glassSection("Common", systemImage: "slider.horizontal.3", compact: true) {
                    appearanceControls
                }

                Button("Close") { onClose() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ultraThinMaterial)
        .frame(minWidth: 360, minHeight: 360)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $manager.mode) {
                ForEach(TimeMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: manager.mode) { _, _ in manager.saveSettings() }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var transportSection: some View {
        HStack(spacing: 8) {
            Button(action: { manager.toggleStartPause() }) {
                Label(isRunning ? "Pause" : "Start",
                      systemImage: isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)

            Button(action: { manager.resetCurrent() }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(minWidth: 72)
            }
            .controlSize(.regular)
            .buttonStyle(.bordered)
        }
    }

    private var appearanceControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Size", systemImage: "textformat.size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .leading)

                HStack(spacing: 6) {
                    Button {
                        adjustFontSize(by: -5)
                        manager.saveSettings()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Text("\(Int(manager.fontSize))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 44)

                    Button {
                        adjustFontSize(by: 5)
                        manager.saveSettings()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                Label("Font", systemImage: "textformat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .leading)

                Picker("", selection: $manager.displayFont) {
                    ForEach(DisplayFont.allCases, id: \.self) { font in
                        Text(font.rawValue).tag(font)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: manager.displayFont) { _, _ in manager.saveSettings() }
            }

            HStack(spacing: 10) {
                Label("Color", systemImage: "paintpalette")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .leading)

                HStack(spacing: 9) {
                    ForEach(DisplayColor.allCases, id: \.self) { color in
                        Button(action: { manager.displayColor = color; manager.saveSettings() }) {
                            ZStack {
                                Circle().fill(swatchColor(for: color))
                                    .frame(width: 18, height: 18)
                                    .shadow(color: swatchColor(for: color).opacity(0.35), radius: 3)
                                if manager.displayColor == color {
                                    Circle()
                                        .stroke(.primary.opacity(0.72), lineWidth: 1.5)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .frame(width: 28, height: 26)
                        }
                        .buttonStyle(.plain)
                        .help(color.rawValue)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 16) {
                Toggle("Blur", isOn: $manager.showShadow)
                    .onChange(of: manager.showShadow) { _, _ in manager.saveSettings() }
                Toggle("Seconds", isOn: $manager.showSeconds)
                    .onChange(of: manager.showSeconds) { _, _ in manager.saveSettings() }
                Toggle("Click-through", isOn: $manager.clickThrough)
                    .onChange(of: manager.clickThrough) { _, _ in manager.saveSettings() }
            }
            .font(.caption)

            Divider()

            Toggle("Reminder pulse", isOn: $manager.reminderEnabled)
                .onChange(of: manager.reminderEnabled) { _, _ in
                    manager.rescheduleReminder()
                    manager.saveSettings()
                }
            if manager.reminderEnabled {
                Stepper("Every \(manager.reminderIntervalMinutes) min", value: $manager.reminderIntervalMinutes, in: 1...120, step: 1)
                    .onChange(of: manager.reminderIntervalMinutes) { _, _ in
                        manager.rescheduleReminder()
                        manager.saveSettings()
                    }
            }
            Toggle("Show in Dock", isOn: $manager.showDockIcon)
                .onChange(of: manager.showDockIcon) { _, _ in manager.saveSettings() }
        }
    }

    @ViewBuilder
    private var modeSpecificControls: some View {
        switch manager.mode {
        case .clock:
            VStack(alignment: .leading, spacing: 10) {
                Toggle("24-hour format", isOn: $manager.use24Hour)
                Toggle("Show date", isOn: $manager.showDate)
            }
            .onChange(of: manager.use24Hour) { _, _ in manager.saveSettings() }
            .onChange(of: manager.showDate) { _, _ in manager.saveSettings() }

        case .countdown:
            countdownControls

        case .stopwatch:
            Text("Elapsed time follows the global seconds setting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var countdownControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if manager.countdownRunning || manager.countdownPaused {
                HStack {
                    Text("Remaining")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(TimerManager.formatTime(manager.countdownRemaining, showSeconds: manager.showSeconds))
                        .font(.system(.body, design: .monospaced))
                }
            } else {
                HStack(spacing: 18) {
                    TimePickerField(label: "Hours", value: countdownHours, options: Array(0...23), suffix: "h")
                    Text(":").font(.title2).foregroundStyle(.secondary)
                    TimePickerField(label: "Minutes", value: countdownMinutes, options: Array(stride(from: 0, through: 55, by: 5)), suffix: "m")
                    Spacer(minLength: 0)
                }
            }

            ViewThatFits {
                HStack(spacing: 8) { presetButtons }
                VStack(alignment: .leading, spacing: 8) { presetButtons }
            }

            Toggle("Auto-repeat", isOn: $manager.countdownAutoRepeat)
                .onChange(of: manager.countdownAutoRepeat) { _, _ in manager.saveSettings() }
            Toggle("Sound notifications", isOn: $manager.soundEnabled)
                .onChange(of: manager.soundEnabled) { _, _ in manager.saveSettings() }
        }
    }

    private var presetButtons: some View {
        ForEach([5, 15, 25, 45, 60], id: \.self) { mins in
            Button("\(mins)m") {
                manager.setCountdownPreset(mins)
                manager.saveSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(manager.countdownRunning)
        }
    }

    private var modeIcon: String {
        switch manager.mode {
        case .clock: return "clock"
        case .countdown: return "timer"
        case .stopwatch: return "stopwatch"
        }
    }

    private func glassSection<Content: View>(
        _ title: String,
        systemImage: String,
        compact: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Label(title, systemImage: systemImage)
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .foregroundStyle(.primary.opacity(0.82))
            content()
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var isRunning: Bool {
        switch manager.mode {
        case .clock: return false
        case .countdown: return manager.countdownRunning
        case .stopwatch: return manager.stopwatchRunning
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
