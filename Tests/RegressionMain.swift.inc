import AppKit
import SwiftUI

@MainActor enum NotificationSpy {
    static var permissionRequests = 0
    static var completions = 0
}

@main struct RegressionMain {
    @MainActor static func main() {
        _ = NSApplication.shared
        let manager = TimerManager.runCountdownRegressions()
        MenuBarController.runMenuRegressions(manager: manager)
        let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/private/tmp"
        manager.mode = .countdown
        manager.clickThrough = false
        manager.displayColor = .ink
        manager.displayFont = .sfProRounded
        verifyPanelResizing(manager)
        snapshot(ContentView(manager: manager), size: ContentView(manager: manager).displaySize, to: output + "/floating.png")
        manager.displayRendering = .outline
        snapshot(ContentView(manager: manager), size: ContentView(manager: manager).displaySize, to: output + "/outline.png")
        manager.displayRendering = .solid
        snapshot(preview(manager), size: NSSize(width: 480, height: 220), to: output + "/light-background.png")
        snapshot(CompactControlView(manager: manager, closeAction: {}, openSettingsAction: {}), size: NSSize(width: 340, height: 204), to: output + "/controls.png")
        snapshot(SettingsView(manager: manager), size: NSSize(width: 580, height: 900), to: output + "/settings.png")
        print("PASS: SwiftUI floating display, controls, and settings render")
        print("All regressions passed")
    }

    @MainActor static func verifyPanelResizing(_ manager: TimerManager) {
        let delegate = AppDelegate()
        delegate.setupPanel(with: manager)
        let panel = delegate.panel!
        manager.fontSize = 100
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let large = panel.frame.size
        manager.fontSize = 40
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let small = panel.frame.size
        precondition(small.width < large.width * 0.5 && small.height < large.height * 0.6)
        precondition(small == ContentView(manager: manager).displaySize)
        manager.mode = .clock
        manager.showSeconds = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let withSeconds = panel.frame.width
        manager.showSeconds = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        precondition(panel.frame.width < withSeconds)
        manager.showDate = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        precondition(panel.frame.size == ContentView(manager: manager).displaySize)
        manager.showDate = false
        manager.mode = .countdown
        manager.showSeconds = true
        manager.fontSize = 65
        panel.orderOut(nil)
        print("PASS: actual NSPanel shrinks in width and height with font and seconds; date fits")
    }

    @MainActor static func preview(_ manager: TimerManager) -> some View {
        ZStack {
            Color(red: 0.96, green: 0.95, blue: 0.92)
            ContentView(manager: manager)
        }
    }

    @MainActor static func snapshot<V: View>(_ view: V, size: NSSize, to path: String) {
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { fatalError("No snapshot bitmap") }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    }
}
