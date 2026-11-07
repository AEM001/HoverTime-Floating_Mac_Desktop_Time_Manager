//
//  CompactControlPanel.swift
//  HoverTime
//

import AppKit
import SwiftUI

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
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 178),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        contentView = hostingView
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct CompactControlView: View {
    @ObservedObject var manager: TimerManager
    let closeAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
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
                        Text(statusText).font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
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
        .frame(width: 380, height: manager.mode == .countdown ? 590 : 550)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
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

    private var statusText: String {
        switch manager.mode {
        case .clock: return manager.clockDisplayString
        case .countdown: return TimerManager.formatTime(manager.countdownRemaining, showSeconds: manager.showSeconds)
        case .stopwatch: return manager.stopwatchDisplayString
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
    @ObservedObject var manager: TimerManager
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("APPEARANCE").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(manager.fontSize)) pt").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(DisplayColor.allCases, id: \.self) { color in
                    Button { manager.displayColor = color; manager.saveSettings() } label: {
                        VStack(spacing: 5) {
                            Circle().fill(color.color).frame(width: 22, height: 22)
                                .overlay { if manager.displayColor == color { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
                            Text(color.title).font(.system(size: 9, weight: .medium))
                        }.frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(manager.displayColor == color ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityLabel(color.title)
                    .accessibilityAddTraits(manager.displayColor == color ? .isSelected : [])
                }
            }
            HStack {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
                Slider(value: $manager.fontSize, in: 40...200, step: 5) { Text("Font size") }
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
            }
            HStack {
                Text("Typeface").font(.system(size: 12))
                Spacer()
                Picker("Typeface", selection: $manager.displayFont) {
                    ForEach(DisplayFont.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 165)
            }
            Toggle("Adaptive background", isOn: $manager.adaptiveColor).font(.system(size: 12)).toggleStyle(.switch).controlSize(.mini)
                .onChange(of: manager.adaptiveColor) { _, enabled in
                    manager.saveSettings()
                    if enabled && !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
                }
            Text(manager.adaptiveColor ? manager.adaptiveStatus : "Fixed palette · fine edges keep digits defined")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
            Toggle("Soft protective backdrop", isOn: $manager.showBackdrop).font(.system(size: 12)).toggleStyle(.switch).controlSize(.mini)
        }
    }
}
