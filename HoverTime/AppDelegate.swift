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
        floatingPanel.dragAction = { [weak self] in self?.hideCompactControls() }
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
            .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main)
            .sink { [weak self, weak floatingPanel, weak manager] in
                guard let self, let floatingPanel, let manager else { return }
                self.resizePanel(floatingPanel, for: manager)
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
        compactControlPanel.makeKeyAndOrderFront(nil)
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
        let size = NSSize(width: 380, height: 630)
        if controls.frame.size != size { controls.setContentSize(size) }
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
                // One atomic update with a fixed top-left anchor. Programmatic
                // movement must not dismiss or chase the slider's control panel.
                let target = NSRect(x: panel.frame.minX, y: panel.frame.maxY - size.height,
                                    width: size.width, height: size.height)
                panel.setFrame(target, display: true, animate: false)
                panel.constrainToScreen()
            }
            return
        }
    }
}

// Event-driven one-shot scheduling: 45 s while learning, 120 s when stable.
// Only scalar history is retained. No stream or on-disk screenshots.
@MainActor
final class BackdropSampler {
    private var timer: Timer?
    private var generation = 0
    private var policy = BackdropPolicy()
    private var anchor: NSPoint?
    private var failureDelay: TimeInterval = 150
    private var cachedFilter: SCContentFilter?
    private var cachedDisplay: UInt32?
    private var filterDate = Date.distantPast

    func start(panel: FloatingPanel, manager: TimerManager) {
        timer?.invalidate()
        generation += 1
        policy.reset()
        cachedFilter = nil
        guard manager.adaptiveColor else { manager.adaptiveStatus = "Off"; return }
        let token = generation
        Task { await tick(panel: panel, manager: manager, token: token) }
    }

    private func schedule(panel: FloatingPanel, manager: TimerManager, token: Int, after delay: TimeInterval) {
        guard token == generation, manager.adaptiveColor else { return }
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self, weak panel, weak manager] _ in
            Task { @MainActor in
                guard let self, let panel, let manager else { return }
                await self.tick(panel: panel, manager: manager, token: token)
            }
        }
        timer?.tolerance = delay * 0.15
    }

    private func tick(panel: FloatingPanel, manager: TimerManager, token: Int) async {
        guard token == generation, manager.adaptiveColor else { return }
        var next: TimeInterval = 120
        defer { schedule(panel: panel, manager: manager, token: token, after: next) }
        // Never capture while the user is editing or moving the widget.
        guard panel.isVisible,
              NSEvent.pressedMouseButtons == 0,
              (NSApp.delegate as? AppDelegate)?.compactControlPanel?.isVisible != true else { return }
        guard CGPreflightScreenCaptureAccess() else {
            setStatus("Enable Screen Recording in System Settings, then relaunch", manager: manager)
            next = 300
            return
        }
        do {
            guard let screen = panel.screen,
                  let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return }
            if cachedFilter == nil || cachedDisplay != id || Date().timeIntervalSince(filterDate) > 300 {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard token == generation, manager.adaptiveColor,
                      let display = content.displays.first(where: { $0.displayID == id }) else { return }
                let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
                cachedFilter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
                cachedDisplay = id
                filterDate = Date()
            }
            guard let filter = cachedFilter else { return }
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
            guard token == generation, manager.adaptiveColor, panel.isVisible, panel.frame == sampledFrame else { return }
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
            let currentAnchor = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
            if anchor != currentAnchor {
                policy.reset()
                anchor = currentAnchor
            }
            let luminance = stride(from: 0, to: pixels.count, by: 4).reduce(0.0) { sum, i in
                func linear(_ v: UInt8) -> Double {
                    let c = Double(v) / 255
                    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
                }
                return sum + 0.2126 * linear(pixels[i]) + 0.7152 * linear(pixels[i+1]) + 0.0722 * linear(pixels[i+2])
            } / 256
            let decision = policy.observe(luminance: luminance, now: now, currentDark: manager.adaptiveDarkBackground)
            if decision.dark != manager.adaptiveDarkBackground { manager.adaptiveDarkBackground = decision.dark }
            failureDelay = 150
            next = decision.interval
            if ProcessInfo.processInfo.isLowPowerModeEnabled { next = max(next, 120) }
            setStatus(next >= 120 ? "Stable · checking every 2 minutes" : "Learning · 5 minute history", manager: manager)
        } catch {
            guard token == generation else { return }
            cachedFilter = nil
            failureDelay = min(900, failureDelay * 2)
            next = failureDelay
            setStatus("Sampling paused · using last palette", manager: manager)
        }
    }

    private func setStatus(_ status: String, manager: TimerManager) {
        if manager.adaptiveStatus != status { manager.adaptiveStatus = status }
    }
}

// BEGIN BACKDROP POLICY — pure scalar logic, independently verifiable.
struct BackdropPolicy {
    private var samples: [(Date, Double)] = []
    private var lastSwitch = Date.distantPast
    private var candidate: Bool?
    private var candidateSince = Date.distantPast
    private var stableCount = 0

    mutating func reset() {
        samples.removeAll()
        candidate = nil
        stableCount = 0
        // Preserve dwell time even when the user moves the widget.
    }

    mutating func observe(luminance: Double, now: Date, currentDark: Bool) -> (dark: Bool, interval: TimeInterval) {
        if let previous = samples.last, now.timeIntervalSince(previous.0) > 300 { reset() }
        stableCount = abs((samples.last?.1 ?? luminance) - luminance) < 0.035 ? stableCount + 1 : 0
        samples.append((now, luminance))
        samples.removeAll { now.timeIntervalSince($0.0) > 300 }
        let sorted = samples.map { $0.1 }.sorted()
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        // Schmitt trigger + persistence + dwell time. Neither isolated samples
        // nor threshold noise can immediately change the output.
        var output = currentDark
        let desired = currentDark ? median < 0.32 : median < 0.18
        if desired != currentDark {
            if candidate != desired { candidate = desired; candidateSince = now }
            if now.timeIntervalSince(candidateSince) >= 60, now.timeIntervalSince(lastSwitch) >= 180 {
                output = desired
                lastSwitch = now
                candidate = nil
            }
        } else {
            candidate = nil
        }
        return (output, stableCount >= 3 && candidate == nil ? 120 : 45)
    }
}
// END BACKDROP POLICY
