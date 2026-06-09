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
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titlebarAppearsTransparent = true
        title = "HoverTime Controls"
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
            let x = screen.visibleFrame.midX - 160
            let y = screen.visibleFrame.midY - 200
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
                manager.countdownRemaining = manager.countdownTotal
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
                manager.countdownRemaining = manager.countdownTotal
                manager.saveSettings()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Mode
            VStack(alignment: .leading, spacing: 6) {
                Label("Mode", systemImage: "timer").font(.subheadline).foregroundStyle(.secondary)
                Picker("", selection: $manager.mode) {
                    ForEach(TimeMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Start / Pause / Reset
            if manager.mode != .clock {
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
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }
            }

            // Countdown time input (idle only)
            if manager.mode == .countdown && !manager.countdownRunning && !manager.countdownPaused {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Set Time", systemImage: "clock").font(.subheadline).foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        TimePickerField(
                            label: "Hours",
                            value: countdownHours,
                            options: Array(0...23),
                            suffix: "h"
                        )
                        
                        Text(":").font(.title).foregroundStyle(.secondary)
                        
                        TimePickerField(
                            label: "Minutes",
                            value: countdownMinutes,
                            options: [0, 15, 30, 45],
                            suffix: "m"
                        )
                    }
                    
                    Text("Presets").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach([5, 15, 25, 45, 60], id: \.self) { mins in
                            Button("\(mins)m") {
                                manager.setCountdownPreset(mins)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Divider()

            // Font size
            VStack(alignment: .leading, spacing: 8) {
                Label("Font Size  \(Int(manager.fontSize))", systemImage: "textformat.size")
                    .font(.subheadline).foregroundStyle(.secondary)
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

            // Color
            VStack(alignment: .leading, spacing: 8) {
                Label("Color", systemImage: "paintpalette").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    ForEach(DisplayColor.allCases, id: \.self) { color in
                        Button(action: { manager.displayColor = color; manager.saveSettings() }) {
                            ZStack {
                                Circle().fill(swatchColor(for: color))
                                    .frame(width: 32, height: 32)
                                    .shadow(color: swatchColor(for: color).opacity(0.6), radius: 4)
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

            Spacer()

            Button("Close") { onClose() }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .padding(20)
        .frame(width: 340, height: 460)
        .fixedSize()
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
