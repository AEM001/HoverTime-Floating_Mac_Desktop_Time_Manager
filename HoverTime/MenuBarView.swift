//
//  MenuBarView.swift
//  HoverTime
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: TimerManager
    var appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(appDelegate.panel?.isVisible == true ? "Hide Timer" : "Show Timer") {
            appDelegate.togglePanel()
        }
        .keyboardShortcut("h")
        .onAppear {
            appDelegate.setupPanel(with: manager)
        }

        Divider()

        if manager.mode != .clock {
            Button(isRunning ? "Pause" : "Start") {
                manager.toggleStartPause()
            }
            .keyboardShortcut("p")

            Button("Reset") {
                manager.resetCurrent()
            }
            .keyboardShortcut("r")

            Divider()
        }

        Button("Open HoverTime...") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit HoverTime") {
            manager.saveSettings()
            appDelegate.panel?.savePosition()
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var isRunning: Bool {
        switch manager.mode {
        case .clock: return false
        case .countdown: return manager.countdownRunning
        case .stopwatch: return manager.stopwatchRunning
        }
    }
}
