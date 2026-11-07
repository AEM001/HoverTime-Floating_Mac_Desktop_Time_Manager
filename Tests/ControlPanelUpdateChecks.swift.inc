// Minimal input model for exercising the production subscription without windows.
enum TimeMode { case clock, countdown, stopwatch }
enum DisplayColor { case ink, sage }
enum DisplayTone { case deep, light }
enum DisplayFont { case sfProRounded, newYork }
final class TimerManager: ObservableObject {
    @Published var currentTime = Date()
    @Published var countdownRemaining: TimeInterval = 1500
    @Published var stopwatchElapsed: TimeInterval = 0
    @Published var mode = TimeMode.clock
    @Published var countdownRunning = false
    @Published var stopwatchRunning = false
    @Published var countdownTotal: TimeInterval = 1500
    @Published var fontSize: CGFloat = 65
    @Published var displayColor = DisplayColor.ink
    @Published var displayTone = DisplayTone.deep
    @Published var displayFont = DisplayFont.sfProRounded
    @Published var adaptiveColor = false
    @Published var usesLightInk = false
    @Published var adaptiveStatus = "Off"
    @Published var showBackdrop = true
}
@main
struct ControlPanelUpdateChecks {
    static func main() {
        let manager = TimerManager()
        let updates = ControlPanelUpdates(manager: manager)
        var changes = 0
        let subscription = updates.$configuration.dropFirst().sink { _ in changes += 1 }
        func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.08)) }
        for _ in 0..<20 {
            manager.currentTime = Date()
            manager.countdownRemaining -= 1
            manager.stopwatchElapsed += 1
        }
        drain()
        precondition(changes == 0, "Time ticks invalidated the panel")
        manager.fontSize = 100
        drain()
        precondition(changes == 1 && updates.configuration.size == 100, "Font controls stopped updating")
        manager.mode = .countdown
        manager.countdownRunning = true
        drain()
        precondition(changes == 2 && updates.configuration.running, "Mode/running changes were lost")
        manager.fontSize = 100
        drain()
        precondition(changes == 2, "Duplicate settings caused unnecessary updates")
        withExtendedLifetime(subscription) {}
        print("Control panel updates: ticks isolated, settings responsive, duplicate updates suppressed")
    }
}
