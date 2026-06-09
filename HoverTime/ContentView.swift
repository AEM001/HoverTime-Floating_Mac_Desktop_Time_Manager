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
        title = "HoverTime Controls"
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
            }

            VStack(spacing: 2) {
                switch manager.mode {
                case .clock:     clockView
                case .countdown: countdownView
                case .stopwatch: stopwatchView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                ControlWindowManager.shared.toggle(manager: manager)
            }
        }
        .frame(minWidth: 150, minHeight: 50)
        .fixedSize()
    }

    // MARK: - Color & Font Helpers

    var tintColor: Color {
        switch manager.displayColor {
        case .white: return Color(white: 1.0)
        case .amber: return Color(red: 1.0, green: 0.78, blue: 0.1)
        case .cyan:  return Color(red: 0.1, green: 0.9, blue: 1.0)
        case .rose:  return Color(red: 1.0, green: 0.35, blue: 0.45)
        }
    }

    private var glowColor: Color { tintColor.opacity(0.45) }

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
                .shadow(color: glowColor, radius: 8, x: 0, y: 0)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            if manager.showDate {
                Text(manager.dateDisplayString)
                    .font(timeFont(size: manager.fontSize * 0.3))
                    .foregroundStyle(tintColor.opacity(0.7))
            }
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        Text(TimerManager.formatTime(manager.countdownRemaining))
            .font(timeFont(size: manager.fontSize))
            .foregroundStyle(tintColor)
            .shadow(color: glowColor, radius: 8, x: 0, y: 0)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }

    // MARK: - Stopwatch View

    private var stopwatchView: some View {
        Text(manager.stopwatchDisplayString)
            .font(timeFont(size: manager.fontSize))
            .foregroundStyle(tintColor)
            .shadow(color: glowColor, radius: 8, x: 0, y: 0)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
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
                TextField("", value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                
                VStack(spacing: 2) {
                    Button(action: { cycleUp() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 20, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    
                    Button(action: { cycleDown() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 20, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
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
            VStack(alignment: .leading, spacing: 16) {
                modeSection

                if manager.mode != .clock {
                    transportSection
                }

                glassSection("Common", systemImage: "slider.horizontal.3") {
                    appearanceControls
                }

                glassSection(manager.mode.rawValue, systemImage: modeIcon) {
                    modeSpecificControls
                }

                Button("Close") { onClose() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ultraThinMaterial)
        .frame(minWidth: 360, minHeight: 360)
    }

    private var modeSection: some View {
        glassSection("Mode", systemImage: "timer") {
            Picker("", selection: $manager.mode) {
                ForEach(TimeMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: manager.mode) { _, _ in manager.saveSettings() }
        }
    }

    private var transportSection: some View {
        HStack(spacing: 12) {
            Button(action: { manager.toggleStartPause() }) {
                Label(isRunning ? "Pause" : "Start",
                      systemImage: isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? .orange : .green)

            Button(action: { manager.resetCurrent() }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(minWidth: 72)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
        }
    }

    private var appearanceControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Font Size  \(Int(manager.fontSize))", systemImage: "textformat.size")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button {
                        manager.fontSize = max(40, manager.fontSize - 4)
                        manager.saveSettings()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)

                    Slider(value: $manager.fontSize, in: 40...200, step: 2)
                        .onChange(of: manager.fontSize) { _, _ in manager.saveSettings() }

                    Button {
                        manager.fontSize = min(200, manager.fontSize + 4)
                        manager.saveSettings()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Picker("Typeface", selection: $manager.displayFont) {
                ForEach(DisplayFont.allCases, id: \.self) { font in
                    Text(font.rawValue).tag(font)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: manager.displayFont) { _, _ in manager.saveSettings() }

            VStack(alignment: .leading, spacing: 8) {
                Label("Color", systemImage: "paintpalette")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    ForEach(DisplayColor.allCases, id: \.self) { color in
                        Button(action: { manager.displayColor = color; manager.saveSettings() }) {
                            ZStack {
                                Circle().fill(swatchColor(for: color))
                                    .frame(width: 32, height: 32)
                                    .shadow(color: swatchColor(for: color).opacity(0.45), radius: 5)
                                if manager.displayColor == color {
                                    Circle()
                                        .stroke(Color.primary.opacity(0.8), lineWidth: 2.5)
                                        .frame(width: 38, height: 38)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(color.rawValue)
                    }
                }
            }

            Toggle("Background blur", isOn: $manager.showShadow)
                .onChange(of: manager.showShadow) { _, _ in manager.saveSettings() }
            Toggle("Click-through mode", isOn: $manager.clickThrough)
                .onChange(of: manager.clickThrough) { _, _ in manager.saveSettings() }
        }
    }

    @ViewBuilder
    private var modeSpecificControls: some View {
        switch manager.mode {
        case .clock:
            VStack(alignment: .leading, spacing: 10) {
                Toggle("24-hour format", isOn: $manager.use24Hour)
                Toggle("Show seconds", isOn: $manager.showSeconds)
                Toggle("Show date", isOn: $manager.showDate)
            }
            .onChange(of: manager.use24Hour) { _, _ in manager.saveSettings() }
            .onChange(of: manager.showSeconds) { _, _ in manager.saveSettings() }
            .onChange(of: manager.showDate) { _, _ in manager.saveSettings() }

        case .countdown:
            countdownControls

        case .stopwatch:
            Toggle("Show seconds", isOn: $manager.stopwatchShowSeconds)
                .onChange(of: manager.stopwatchShowSeconds) { _, _ in manager.saveSettings() }
        }
    }

    private var countdownControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if manager.countdownRunning || manager.countdownPaused {
                HStack {
                    Text("Remaining")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(TimerManager.formatTime(manager.countdownRemaining))
                        .font(.system(.body, design: .monospaced))
                }
            } else {
                HStack(spacing: 18) {
                    TimePickerField(label: "Hours", value: countdownHours, options: Array(0...23), suffix: "h")
                    Text(":").font(.title2).foregroundStyle(.secondary)
                    TimePickerField(label: "Minutes", value: countdownMinutes, options: Array(0...59), suffix: "m")
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.86))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
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
        case .white: return Color(white: 0.95)
        case .amber: return Color(red: 1.0, green: 0.78, blue: 0.1)
        case .cyan:  return Color(red: 0.1, green: 0.9, blue: 1.0)
        case .rose:  return Color(red: 1.0, green: 0.35, blue: 0.45)
        }
    }
}
