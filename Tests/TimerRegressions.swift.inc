
extension TimerManager {
    static func runCountdownRegressions() -> TimerManager {
        let defaults = UserDefaults(suiteName: "HoverTime.RegressionTests")!
        defaults.removePersistentDomain(forName: "HoverTime.RegressionTests")
        let manager = TimerManager()
        manager.displayTimer?.invalidate()
        manager.soundEnabled = false
        manager.mode = .countdown
        manager.countdownTotal = 300
        manager.resetCountdown()

        func expire() {
            manager.countdownEndDate = Date().addingTimeInterval(-60)
            manager.updateCountdown(now: Date())
        }
        manager.startCountdown()
        expire()
        precondition(manager.countdownRemaining == 300 && !manager.countdownRunning && !manager.countdownPaused)
        precondition(manager.countdownProgress == 0 && manager.countdownEndDate == nil)
        precondition(NotificationSpy.completions == 1)
        manager.updateCountdown(now: Date())
        precondition(NotificationSpy.completions == 1, "Completion must only fire once")
        print("PASS: expired / overdue countdown resets, stops, and notifies once")

        manager.startCountdown()
        let deadline = manager.countdownEndDate
        manager.startCountdown()
        precondition(manager.countdownEndDate == deadline, "Duplicate start must not extend the deadline")
        manager.countdownEndDate = Date().addingTimeInterval(120)
        manager.pauseCountdown()
        precondition(manager.countdownPaused && !manager.countdownRunning && manager.countdownRemaining == 120)
        manager.startCountdown()
        precondition(manager.countdownRunning && !manager.countdownPaused && manager.countdownRemaining == 120)
        print("PASS: duplicate start and pause / resume preserve duration")

        manager.countdownAutoRepeat = true
        expire()
        precondition(manager.countdownRunning && !manager.countdownPaused && manager.countdownRemaining == 300)
        precondition(NotificationSpy.completions == 2)
        manager.resetCountdown()
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        precondition(!manager.countdownRunning && manager.countdownRemaining == 300)
        print("PASS: auto-repeat starts immediately; reset leaves no delayed restart")

        manager.countdownAutoRepeat = false
        manager.startCountdown()
        manager.countdownEndDate = Date().addingTimeInterval(-1)
        manager.pauseCountdown()
        precondition(!manager.countdownPaused && !manager.countdownRunning && manager.countdownRemaining == 300)
        print("PASS: pause at expiration leaves a reset timer")

        manager.startCountdown()
        manager.startStopwatch()
        precondition(manager.stopwatchRunning && !manager.countdownRunning)
        manager.startCountdown()
        precondition(manager.countdownRunning && !manager.stopwatchRunning)
        manager.resetCountdown()
        manager.resetStopwatch()
        print("PASS: switching running timers keeps only one active")
        return manager
    }
}
