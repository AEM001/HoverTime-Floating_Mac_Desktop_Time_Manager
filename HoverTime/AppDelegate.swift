//
//  AppDelegate.swift
//  HoverTime
//

import AppKit
import SwiftUI
import Combine
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: FloatingPanel?
    var compactControlPanel: CompactControlPanel?
    var timerManager: TimerManager?
    var cancellables = Set<AnyCancellable>()
    private let backdropSampler = BackdropSampler()
    private var saveTimer: Timer?
    private var compactControlMouseMonitor: Any?
    private var globalControlMouseMonitor: Any?
    private var managedSettingsWindow: NSWindow?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyApplicationIcon()
        menuBarController = MenuBarController(manager: TimerManager.shared, appDelegate: self)
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
        hostingView.sizingOptions = []

        let floatingPanel = FloatingPanel(contentView: hostingView)
        floatingPanel.isClickThrough = manager.clickThrough
        floatingPanel.alphaValue = CGFloat(manager.windowOpacity)
        floatingPanel.clickAction = { [weak self] in
            self?.toggleCompactControls()
        }
        floatingPanel.orderFrontRegardless()
        panel = floatingPanel
        floatingPanel.delegate = self
        backdropSampler.start(panel: floatingPanel, manager: manager)
        manager.$adaptiveColor.removeDuplicates().dropFirst().sink { [weak self, weak floatingPanel, weak manager] _ in
            DispatchQueue.main.async {
                guard let self, let floatingPanel, let manager else { return }
                self.backdropSampler.start(panel: floatingPanel, manager: manager)
            }
        }.store(in: &cancellables)
        applyDockIconVisibility(manager.showDockIcon)
        resizePanel(floatingPanel, for: manager)
        floatingPanel.constrainToScreen()

        manager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak floatingPanel, weak manager] in
                guard let self, let floatingPanel, let manager else { return }
                self.resizePanel(floatingPanel, for: manager)
                if let controls = self.compactControlPanel, controls.isVisible {
                    self.resizeCompactControls(controls, for: manager)
                    self.positionCompactControls(controls)
                }
            }
            .store(in: &cancellables)

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
            panel.constrainToScreen()
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
        y = max(visible.minY + 8, min(y, visible.maxY - size.height - 8))
        controls.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func resizeCompactControls(_ controls: CompactControlPanel, for manager: TimerManager) {
        let height: CGFloat = manager.mode == .countdown ? 590 : 550
        controls.setContentSize(NSSize(width: 380, height: height))
    }

    private func installCompactControlMouseMonitor() {
        guard compactControlMouseMonitor == nil else { return }
        compactControlMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let controls = self.compactControlPanel, controls.isVisible else { return event }
            if event.window !== controls && event.window !== self.panel {
                self.hideCompactControls()
            }
            return event
        }
        globalControlMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hideCompactControls()
        }
    }

    private func removeCompactControlMouseMonitor() {
        if let monitor = globalControlMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalControlMouseMonitor = nil
        }
        if let monitor = compactControlMouseMonitor {
            NSEvent.removeMonitor(monitor)
            compactControlMouseMonitor = nil
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel else { return }
        hideCompactControls()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        panel?.constrainToScreen()
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
        if panel.contentView is NSHostingView<ContentView> {
            let size = ContentView(manager: manager).displaySize
            if size.width > 0, size.height > 0, size != panel.frame.size {
                let top = panel.frame.maxY
                panel.setContentSize(size)
                panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - size.height))
                panel.constrainToScreen()
            }
            return
        }
    }
}

// One tiny region every 30 seconds; no stream, no images retained or written.
@MainActor
final class BackdropSampler {
    private var timer: Timer?
    private var busy = false
    private var samples: [(Date, Double)] = []
    private var lastOrigin: NSPoint?
    private var lastSwitch = Date.distantPast

    func start(panel: FloatingPanel, manager: TimerManager) {
        timer?.invalidate()
        samples.removeAll()
        lastSwitch = .distantPast
        guard manager.adaptiveColor else { manager.adaptiveStatus = "Off"; return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self, weak panel, weak manager] _ in
            Task { @MainActor in
                guard let self, let panel, let manager else { return }
                await self.sample(panel: panel, manager: manager)
            }
        }
        timer?.tolerance = 5
        Task { await sample(panel: panel, manager: manager) }
    }

    private func sample(panel: FloatingPanel, manager: TimerManager) async {
        guard manager.adaptiveColor, panel.isVisible, !busy else { return }
        guard CGPreflightScreenCaptureAccess() else {
            manager.adaptiveStatus = "Enable Screen Recording in System Settings, then relaunch"
            return
        }
        busy = true
        defer { busy = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let screen = panel.screen,
                  let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32,
                  let display = content.displays.first(where: { $0.displayID == id }) else { return }
            let excluded = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingWindows: excluded)
            let config = SCStreamConfiguration()
            config.width = 16
            config.height = 16
            config.showsCursor = false
            let sampledFrame = panel.frame
            let frame = sampledFrame.intersection(screen.frame)
            guard !frame.isEmpty else { return }
            config.sourceRect = CGRect(x: frame.minX - screen.frame.minX,
                                       y: screen.frame.maxY - frame.maxY,
                                       width: frame.width, height: frame.height)
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            guard manager.adaptiveColor, panel.isVisible, panel.frame == sampledFrame else { return }
            var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
            let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let ctx = CGContext(data: buffer.baseAddress, width: 16, height: 16, bitsPerComponent: 8,
                                          bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16))
                return true
            }
            guard rendered else { return }
            let now = Date()
            if lastOrigin != panel.frame.origin {
                samples.removeAll()
                lastSwitch = .distantPast
                lastOrigin = panel.frame.origin
            }
            let luminance = stride(from: 0, to: pixels.count, by: 4).reduce(0.0) { sum, i in
                func linear(_ v: UInt8) -> Double {
                    let c = Double(v) / 255
                    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
                }
                return sum + 0.2126 * linear(pixels[i]) + 0.7152 * linear(pixels[i+1]) + 0.0722 * linear(pixels[i+2])
            } / 256
            samples.append((now, luminance))
            samples.removeAll { now.timeIntervalSince($0.0) > 300 }
            let sorted = samples.map { $0.1 }.sorted()
            let median = sorted[sorted.count / 2]
            if now.timeIntervalSince(lastSwitch) >= 120 {
                let dark = manager.adaptiveDarkBackground ? median < 0.40 : median < 0.20
                if dark != manager.adaptiveDarkBackground {
                    manager.adaptiveDarkBackground = dark
                    lastSwitch = now
                }
            }
            manager.adaptiveStatus = "Learning · 5 minute history"
        } catch {
            manager.adaptiveStatus = "Sampling unavailable · using protected palette"
        }
    }
}
