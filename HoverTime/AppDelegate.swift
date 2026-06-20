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
        applyApplicationIcon()
    }

    func setupPanel(with manager: TimerManager) {
        guard panel == nil else { return }
        timerManager = manager

        let contentView = ContentView(manager: manager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 84)
        hostingView.autoresizingMask = [.width, .height]

        let floatingPanel = FloatingPanel(contentView: hostingView)
        floatingPanel.isClickThrough = manager.clickThrough
        floatingPanel.alphaValue = CGFloat(manager.windowOpacity)
        floatingPanel.clickAction = { [weak manager] in
            guard let manager else { return }
            ControlWindowManager.shared.toggle(manager: manager)
        }
        floatingPanel.orderFrontRegardless()
        panel = floatingPanel
        applyDockIconVisibility(manager.showDockIcon)
        resizePanel(floatingPanel, for: manager)

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
            .sink { [weak self, weak floatingPanel, weak manager] _ in
                guard let floatingPanel, let manager else { return }
                self?.resizePanel(floatingPanel, for: manager)
            }
            .store(in: &cancellables)

        manager.$showDate
            .sink { [weak self, weak floatingPanel, weak manager] _ in
                guard let floatingPanel, let manager else { return }
                self?.resizePanel(floatingPanel, for: manager)
            }
            .store(in: &cancellables)

        manager.$showSeconds
            .sink { [weak self, weak floatingPanel, weak manager] _ in
                guard let floatingPanel, let manager else { return }
                self?.resizePanel(floatingPanel, for: manager)
            }
            .store(in: &cancellables)

        manager.$mode
            .sink { [weak self, weak floatingPanel, weak manager] _ in
                guard let floatingPanel, let manager else { return }
                self?.resizePanel(floatingPanel, for: manager)
            }
            .store(in: &cancellables)

        manager.$reminderActiveUntil
            .sink { [weak self, weak floatingPanel, weak manager] _ in
                guard let floatingPanel, let manager else { return }
                self?.resizePanel(floatingPanel, for: manager)
            }
            .store(in: &cancellables)

        manager.$showDockIcon
            .removeDuplicates()
            .sink { [weak self] value in
                self?.applyDockIconVisibility(value)
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
            if window.title == "HoverTime Desktop Timer" {
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

    private func applyDockIconVisibility(_ visible: Bool) {
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }

    private func applyApplicationIcon() {
        guard let path = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
              let image = NSImage(contentsOfFile: path) else {
            return
        }
        NSApp.applicationIconImage = image
    }

    private func resizePanel(_ panel: FloatingPanel, for manager: TimerManager) {
        let size = manager.fontSize
        let dateExtra: CGFloat = manager.mode == .clock && manager.showDate ? size * 0.34 : 0
        let reminderExtra: CGFloat = manager.reminderIsActive ? 34 : 0
        let horizontalPadding: CGFloat = manager.reminderIsActive ? 36 : 24
        let measuredWidth = measuredDisplayWidth(for: manager)
        let reminderWidth: CGFloat = manager.reminderIsActive ? 98 : 0
        let width = ceil(max(measuredWidth, reminderWidth) + horizontalPadding)
        let height = max(52, size * 1.18 + dateExtra + reminderExtra)
        panel.setContentSize(NSSize(width: width, height: height))
    }

    private func measuredDisplayWidth(for manager: TimerManager) -> CGFloat {
        let text: String
        switch manager.mode {
        case .clock:
            text = manager.clockDisplayString
        case .countdown:
            text = TimerManager.formatTime(manager.countdownRemaining, showSeconds: manager.showSeconds)
        case .stopwatch:
            text = manager.stopwatchDisplayString
        }

        let font = displayNSFont(for: manager)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    private func displayNSFont(for manager: TimerManager) -> NSFont {
        let size = manager.fontSize
        switch manager.displayFont {
        case .newYork:
            return NSFont.systemFont(ofSize: size, weight: .semibold)
        case .sfProHeavy:
            return NSFont.systemFont(ofSize: size, weight: .semibold)
        case .impact:
            return NSFont(name: "Impact", size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        case .arialBlack:
            return NSFont(name: "Arial-BoldMT", size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
