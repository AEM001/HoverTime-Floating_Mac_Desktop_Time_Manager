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

private struct CompactControlView: View {
    @ObservedObject var manager: TimerManager
    let closeAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Quick Controls", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Close quick controls")
            }

            HStack(spacing: 8) {
                Button(action: manager.cycleMode) {
                    HStack(spacing: 7) {
                        Image(systemName: modeIcon)
                        Text(modeTitle).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Switch timer mode")

                if manager.mode != .clock {
                    Button(action: manager.toggleStartPause) {
                        Label(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill")
                            .frame(width: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button(action: manager.resetCurrent) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Reset")
                }
            }

            if manager.mode == .countdown {
                HStack(spacing: 6) {
                    presetButton(15, title: "15m")
                    adjustButton(direction: -1)
                    presetButton(30, title: "30m")
                    adjustButton(direction: 1)
                    presetButton(60, title: "1h")
                }
            }

            ZStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button("Full Settings…") {
                    openSettingsAction()
                    closeAction()
                }
                .frame(width: 150)
                .buttonStyle(.glass(.regular.tint(Color.accentColor.opacity(0.22))))
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: 300, height: manager.mode == .countdown ? 174 : 132)
        .glassEffect(
            .regular
                .tint(Color.white.opacity(0.035))
                .interactive(),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: .black.opacity(0.20), radius: 22, y: 8)
        .shadow(color: .white.opacity(0.08), radius: 5, y: -1)
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
