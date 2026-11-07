//
//  CompactControlPanel.swift
//  HoverTime
//

import AppKit
import SwiftUI
import Combine

/// A small, temporary control surface independent from the full settings window.
final class CompactControlPanel: NSPanel {
    init(
        manager: TimerManager,
        closeAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) {
        let hostingView = NSHostingView(
            rootView: CompactControlView(
                manager: manager,
                closeAction: closeAction,
                openSettingsAction: openSettingsAction
            )
        )
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 630),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        // AppKit owns the stationary, fully filled backing independently of ticks.
        let surface = ControlPanelSurface(frame: NSRect(x: 0, y: 0, width: 380, height: 630))
        hostingView.frame = surface.bounds
        surface.addSubview(hostingView)
        contentView = surface
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct CompactControlView: View {
    let manager: TimerManager
    @StateObject private var updates: ControlPanelUpdates
    let closeAction: () -> Void
    let openSettingsAction: () -> Void

    init(manager: TimerManager, closeAction: @escaping () -> Void, openSettingsAction: @escaping () -> Void) {
        self.manager = manager
        self.closeAction = closeAction
        self.openSettingsAction = openSettingsAction
        _updates = StateObject(wrappedValue: ControlPanelUpdates(manager: manager))
    }

    var body: some View {
        let _ = updates.configuration
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("HOVERTIME").font(.system(size: 10, weight: .bold)).tracking(2)
                    Text("Make room for focus").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: closeAction) { Image(systemName: "xmark").frame(width: 26, height: 26) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Close controls")
            }
            HStack(spacing: 6) {
                ForEach(TimeMode.allCases, id: \.self) { mode in
                    Button { manager.mode = mode; manager.saveSettings() } label: {
                        VStack(spacing: 5) {
                            Image(systemName: mode == .clock ? "clock" : mode == .countdown ? "timer" : "stopwatch")
                            Text(mode.rawValue).font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(manager.mode == mode ? Color.accentColor : Color.secondary)
                        .background(manager.mode == mode ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                    .accessibilityAddTraits(manager.mode == mode ? .isSelected : [])
                }
            }
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isRunning ? "IN PROGRESS" : modeTitle.uppercased())
                            .font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                        ControlTimeReadout(manager: manager)
                    }
                    Spacer()
                    if manager.mode != .clock {
                        Button(action: manager.toggleStartPause) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill").frame(width: 26, height: 30)
                        }.buttonStyle(.borderedProminent).clipShape(Circle()).help(isRunning ? "Pause" : "Start")
                        Button(action: manager.resetCurrent) { Image(systemName: "arrow.counterclockwise") }
                            .buttonStyle(.plain).help("Reset")
                    }
                }
                if manager.mode == .countdown {
                    HStack(spacing: 8) {
                        presetButton(5, title: "5m")
                        adjustButton(direction: -1)
                        presetButton(25, title: "25m")
                        adjustButton(direction: 1)
                        presetButton(60, title: "1h")
                    }
                }
            }.padding(16).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            AppearanceControls(manager: manager)
            HStack {
                Label("Drag time to move", systemImage: "hand.draw").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("All settings", systemImage: "slider.horizontal.3") {
                    openSettingsAction(); closeAction()
                }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
            }
        }
        .padding(22)
        .frame(width: 380, height: 630, alignment: .top)
        .transaction { $0.animation = nil; $0.disablesAnimations = true }
        .tint(Color(red: 0.30, green: 0.43, blue: 0.68))
        .onDisappear { manager.saveSettings() }
    }

    private var modeTitle: String {
        switch manager.mode {
        case .clock: return "Clock"
        case .countdown: return "Countdown"
        case .stopwatch: return "Stopwatch"
        }
    }

    private var modeIcon: String {
        switch manager.mode {
        case .clock: return "clock"
        case .countdown: return "timer"
        case .stopwatch: return "stopwatch"
        }
    }

    private var isRunning: Bool {
        switch manager.mode {
        case .clock: return false
        case .countdown: return manager.countdownRunning
        case .stopwatch: return manager.stopwatchRunning
        }
    }

    private func adjustCountdown(by minutes: Int) {
        let currentMinutes = Int(manager.countdownTotal / 60)
        manager.setCountdownPreset(max(5, currentMinutes + minutes))
        manager.saveSettings()
    }

    private func presetButton(_ minutes: Int, title: String) -> some View {
        Button(title) {
            manager.setCountdownPreset(minutes)
            manager.saveSettings()
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(manager.countdownRunning)
    }

    private func adjustButton(direction: Int) -> some View {
        Button {
            adjustCountdown(by: direction * 5)
        } label: {
            Image(systemName: direction < 0 ? "minus" : "plus")
                .frame(width: 20)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(manager.countdownRunning || (direction < 0 && manager.countdownTotal <= 5 * 60))
    }
}

/// Shared by the quick panel and full settings so appearance stays in sync.
struct AppearanceControls: View {
    let manager: TimerManager
    @StateObject private var updates: ControlPanelUpdates

    init(manager: TimerManager) {
        self.manager = manager
        _updates = StateObject(wrappedValue: ControlPanelUpdates(manager: manager))
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<TimerManager, Value>) -> Binding<Value> {
        Binding(get: { manager[keyPath: keyPath] }, set: { manager[keyPath: keyPath] = $0 })
    }

    var body: some View {
        let _ = updates.configuration
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("APPEARANCE").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(manager.fontSize)) pt").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Picker("Color tone", selection: binding(\.displayTone)) {
                Text("Deep · light backgrounds").tag(DisplayTone.deep)
                Text("Light · dark backgrounds").tag(DisplayTone.light)
            }.pickerStyle(.segmented).labelsHidden().disabled(manager.adaptiveColor)
                .onChange(of: manager.displayTone) { _, _ in manager.saveSettings() }
            HStack(spacing: 8) {
                ForEach(DisplayColor.allCases, id: \.self) { color in
                    Button { manager.displayColor = color; manager.saveSettings() } label: {
                        VStack(spacing: 5) {
                            Circle().fill(Color(nsColor: color.adaptiveColor(dark: manager.usesLightInk)))
                                .overlay(Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 1)).frame(width: 22, height: 22)
                                .overlay { if manager.displayColor == color { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(manager.usesLightInk ? Color(red: 0.12, green: 0.18, blue: 0.28) : .white) } }
                            Text(color.title).font(.system(size: 9, weight: .medium))
                        }.frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(manager.displayColor == color ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityLabel(color.title)
                    .accessibilityAddTraits(manager.displayColor == color ? .isSelected : [])
                }
            }
            HStack {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
                Slider(value: binding(\.fontSize), in: 40...200, step: 5) { Text("Font size") }
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
            }
            HStack {
                Text("Typeface").font(.system(size: 12))
                Spacer()
                Picker("Typeface", selection: binding(\.displayFont)) {
                    ForEach(DisplayFont.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 165)
            }
            Toggle("Adaptive background", isOn: binding(\.adaptiveColor)).font(.system(size: 12)).toggleStyle(.switch).controlSize(.mini)
                .onChange(of: manager.adaptiveColor) { _, enabled in
                    manager.saveSettings()
                    if enabled && !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
                }
            Text(manager.adaptiveColor ? manager.adaptiveStatus : "Fixed palette · fine edges keep digits defined")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2).frame(height: 28, alignment: .topLeading)
            Toggle("Soft protective backdrop", isOn: binding(\.showBackdrop)).font(.system(size: 12)).toggleStyle(.switch).controlSize(.mini)
        }
    }
}

/// Solid AppKit backing; time changes cannot repaint or relayout this surface.
private final class ControlPanelSurface: NSView {
    override var allowsVibrancy: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 24, yRadius: 24).fill()
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 24, yRadius: 24)
        border.lineWidth = 1
        border.stroke()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// Only this fixed-size leaf observes the ticking clock/countdown/stopwatch.
private struct ControlTimeReadout: View {
    @ObservedObject var manager: TimerManager
    private var text: String {
        switch manager.mode {
        case .clock: return manager.clockDisplayString
        case .countdown: return TimerManager.formatTime(manager.countdownRemaining, showSeconds: manager.showSeconds)
        case .stopwatch: return manager.stopwatchDisplayString
        }
    }
    var body: some View {
        Text(text).font(.system(size: 32, weight: .medium, design: .rounded))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            .frame(width: 215, height: 42, alignment: .leading)
            .transaction { $0.animation = nil; $0.disablesAnimations = true }
    }
}

/// Configuration-only observation prevents 0.5-second time publications from
/// invalidating the controls and the outer panel layout.
private final class ControlPanelUpdates: ObservableObject {
    struct Configuration: Equatable {
        let mode: TimeMode
        let running: Bool
        let duration: TimeInterval
        let size: CGFloat
        let color: DisplayColor
        let tone: DisplayTone
        let font: DisplayFont
        let adaptive: Bool
        let lightInk: Bool
        let status: String
        let backdrop: Bool

        init(_ manager: TimerManager) {
            mode = manager.mode
            running = manager.mode == .countdown ? manager.countdownRunning : manager.stopwatchRunning
            duration = manager.countdownTotal
            size = manager.fontSize
            color = manager.displayColor
            tone = manager.displayTone
            font = manager.displayFont
            adaptive = manager.adaptiveColor
            lightInk = manager.usesLightInk
            status = manager.adaptiveStatus
            backdrop = manager.showBackdrop
        }
    }
    @Published private(set) var configuration: Configuration
    private var subscription: AnyCancellable?

    init(manager: TimerManager) {
        configuration = Configuration(manager)
        subscription = manager.objectWillChange
            .receive(on: DispatchQueue.main)
            .map { [weak manager] _ in manager.map(Configuration.init) }
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self, let value, value != self.configuration else { return }
                self.configuration = value
            }
    }
}
