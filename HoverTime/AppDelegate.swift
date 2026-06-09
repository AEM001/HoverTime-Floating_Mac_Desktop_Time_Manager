//
//  AppDelegate.swift
//  HoverTime
//

import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?
    var timerManager: TimerManager?
    var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func setupPanel(with manager: TimerManager) {
        guard panel == nil else { return }
        timerManager = manager

        let contentView = ContentView(manager: manager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 120)

        let floatingPanel = FloatingPanel(contentView: hostingView)
        floatingPanel.isClickThrough = manager.clickThrough
        floatingPanel.alphaValue = CGFloat(manager.windowOpacity)
        floatingPanel.orderFrontRegardless()
        panel = floatingPanel

        manager.$clickThrough
            .sink { [weak floatingPanel] value in
                floatingPanel?.isClickThrough = value
            }
            .store(in: &cancellables)

        manager.$windowOpacity
            .sink { [weak floatingPanel] value in
                floatingPanel?.alphaValue = CGFloat(value)
            }
            .store(in: &cancellables)

        manager.$fontSize
            .sink { [weak floatingPanel] size in
                let width = max(200, size * 6)
                let height = max(60, size * 2.5)
                floatingPanel?.setContentSize(NSSize(width: width, height: height))
            }
            .store(in: &cancellables)

        // Save settings periodically without creating unmanaged timers.
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self, weak manager] _ in
            manager?.saveSettings()
            self?.panel?.savePosition()
        }
        saveTimer?.tolerance = 2
    }

    func togglePanel() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    // When user clicks the Dock icon, open Settings
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow()
        return false
    }

    func openSettingsWindow() {
        // Find existing main window or create via SwiftUI
        for window in NSApp.windows {
            if window.title == "HoverTime" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        // Trigger the SwiftUI Window scene by sending the openWindow notification
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveTimer?.invalidate()
        timerManager?.saveSettings()
        panel?.savePosition()
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
