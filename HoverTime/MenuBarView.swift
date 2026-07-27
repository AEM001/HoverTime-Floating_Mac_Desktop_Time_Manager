//
//  MenuBarView.swift
//  HoverTime
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: TimerManager
    var appDelegate: AppDelegate

    var body: some View {
        Button(appDelegate.panel?.isVisible == true ? "Hide Timer" : "Show Timer") {
            appDelegate.togglePanel()
        }
        .keyboardShortcut("h")
        .onAppear {
            appDelegate.setupPanel(with: manager)
        }

        // Snap the floating timer to top-center, just below the menu bar,
        // whether it's currently hidden or just off-screen.
        Button("Recenter at Top") {
            appDelegate.showPanelAtTopCenter(manager: manager)
        }
        .keyboardShortcut("c")

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

        Button("Open HoverTime Desktop Timer...") {
            appDelegate.openSettingsWindow()
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
