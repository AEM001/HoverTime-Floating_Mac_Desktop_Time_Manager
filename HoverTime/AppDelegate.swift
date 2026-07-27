//
//  AppDelegate.swift
//  HoverTime
//

import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: FloatingPanel?
    var compactControlPanel: CompactControlPanel?
    var timerManager: TimerManager?
    var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?
    private var compactControlMouseMonitor: Any?
    private var managedSettingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyApplicationIcon()
        // The shared manager is a singleton — it always exists now.
        if panel == nil {
            setupPanel(with: TimerManager.shared)
        }
    }

    /// Public entry point: create the panel (if needed) and reposition it to the
    /// top-center of the main screen, just under the menu bar. Called from the
    /// menu bar "Show Timer" action.
    func showPanelAtTopCenter(manager: TimerManager) {
        if panel == nil {
            setupPanel(with: manager)
        }
        guard let panel = panel else { return }
        positionPanelTopCenter(panel)
        panel.orderFrontRegardless()
    }

    /// Places the panel horizontally centered, just below the menu bar.
    private func positionPanelTopCenter(_ panel: FloatingPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        // Snug under the menu bar: 8pt gap from the top of visibleFrame.
        let y = visible.maxY - size.height - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.savePosition()
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
        // NSPanel reliably receives mouseUp even when SwiftUI's tap gesture does
        // not make it through the borderless hosting view. FloatingPanel filters
        // out drags, so this restores the reliable quick-controls entry point.
        floatingPanel.clickAction = { [weak self] in
            self?.toggleCompactControls()
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
                if let compactControlPanel = self?.compactControlPanel {
                    self?.resizeCompactControls(compactControlPanel, for: manager)
                }
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
            hideCompactControls()
            panel.orderOut(nil)
        } else {
            // "Show" snaps to top-center, just under the menu bar.
            positionPanelTopCenter(panel)
            panel.orderFrontRegardless()
        }
    }

    /// Toggles the temporary controls anchored to the floating timer.
    /// This is independent from the full settings window.
    func toggleCompactControls() {
        guard let timerManager else { return }
        if let compactControlPanel, compactControlPanel.isVisible {
            hideCompactControls()
            return
        }

        if compactControlPanel == nil {
            compactControlPanel = CompactControlPanel(
                manager: timerManager,
                closeAction: { [weak self] in
                    self?.hideCompactControls()
                },
                openSettingsAction: { [weak self] in
                    self?.openSettingsWindow()
                }
            )
        }

        guard let compactControlPanel else { return }
        resizeCompactControls(compactControlPanel, for: timerManager)
        positionCompactControls(compactControlPanel)
        compactControlPanel.orderFrontRegardless()
        installCompactControlMouseMonitor()
    }

    func hideCompactControls() {
        compactControlPanel?.orderOut(nil)
        removeCompactControlMouseMonitor()
    }

    private func positionCompactControls(_ controls: CompactControlPanel) {
        guard let timerPanel = panel, let screen = timerPanel.screen ?? NSScreen.main else { return }
        let size = controls.frame.size
        let visible = screen.visibleFrame
        var x = timerPanel.frame.midX - size.width / 2
        var y = timerPanel.frame.minY - size.height - 10

        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        if y < visible.minY + 8 {
            y = timerPanel.frame.maxY + 10
        }
        controls.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func resizeCompactControls(_ controls: CompactControlPanel, for manager: TimerManager) {
        let height: CGFloat = manager.mode == .countdown ? 174 : 132
        controls.setContentSize(NSSize(width: 300, height: height))
    }

    private func installCompactControlMouseMonitor() {
        guard compactControlMouseMonitor == nil else { return }
        compactControlMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let controls = self.compactControlPanel, controls.isVisible else { return event }
            if event.window !== controls {
                self.hideCompactControls()
            }
            return event
        }
    }

    private func removeCompactControlMouseMonitor() {
        if let monitor = compactControlMouseMonitor {
            NSEvent.removeMonitor(monitor)
            compactControlMouseMonitor = nil
        }
    }

    // When user clicks the Dock icon, open Settings
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func openSettingsWindow() {
        if let window = settingsWindow {
            bringSettingsWindowToFront(window)
            return
        }

        // Do not depend on a SwiftUI Window scene being alive. This is called by
        // both the menu bar and the non-activating quick-controls panel, so it
        // must also work after the user has closed Settings.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HoverTime Desktop Timer"
        window.contentMinSize = NSSize(width: 560, height: 620)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainView(manager: TimerManager.shared))
        window.delegate = self
        window.center()
        managedSettingsWindow = window
        bringSettingsWindowToFront(window)
    }

    private var settingsWindow: NSWindow? {
        managedSettingsWindow ?? NSApp.windows.first { $0.title == "HoverTime Desktop Timer" }
    }

    private func bringSettingsWindowToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === managedSettingsWindow else { return true }

        // HoverTime is a menu-bar app. Keep the AppKit/SwiftUI hosting hierarchy
        // alive and treat the red close button as Hide. Releasing this window
        // from inside AppKit's close transaction can cause an over-release.
        DispatchQueue.main.async { [weak sender] in
            sender?.orderOut(nil)
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveTimer?.invalidate()
        removeCompactControlMouseMonitor()
        timerManager?.saveSettings()
        panel?.savePosition()
    }

    private func applyDockIconVisibility(_ visible: Bool) {
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }

    private func applyApplicationIcon() {
        // Prefer the icns from the built bundle; fall back to png assets.
        for ext in ["icns", "png"] {
            if let path = Bundle.main.path(forResource: "AppIcon", ofType: ext),
               let image = NSImage(contentsOfFile: path) {
                NSApp.applicationIconImage = image
                return
            }
        }
        if let named = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = named
        }
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
