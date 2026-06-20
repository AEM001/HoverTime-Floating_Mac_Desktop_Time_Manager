//
//  TimerManager.swift
//  HoverTime
//

import Foundation
import Combine
import AppKit
import UserNotifications

enum TimeMode: String, CaseIterable {
    case clock = "Clock"
    case countdown = "Countdown"
    case stopwatch = "Stopwatch"
}

enum DisplayColor: String, CaseIterable {
    case porcelain = "Porcelain"
    case graphite = "Graphite"
    case sage = "Sage"
    case copper = "Copper"
}

enum DisplayFont: String, CaseIterable {
    case newYork = "New York"
    case sfProHeavy = "SF Pro Heavy"
    case impact = "Impact"
    case arialBlack = "Arial Black"
}

class TimerManager: ObservableObject {
    // MARK: - Mode
    @Published var mode: TimeMode = .clock

    // MARK: - Clock
    @Published var currentTime: Date = Date()
    @Published var use24Hour: Bool = true
    @Published var showSeconds: Bool = true
    @Published var showDate: Bool = false

    // MARK: - Countdown
    @Published var countdownTotal: TimeInterval = 25 * 60
    @Published var countdownRemaining: TimeInterval = 25 * 60
    @Published var countdownRunning: Bool = false
    @Published var countdownPaused: Bool = false
    @Published var countdownAutoRepeat: Bool = false

    // MARK: - Stopwatch
    @Published var stopwatchElapsed: TimeInterval = 0
    @Published var stopwatchRunning: Bool = false

    // MARK: - Appearance
    @Published var fontSize: CGFloat = 65
    @Published var windowOpacity: Double = 1.0
    @Published var showShadow: Bool = false
    @Published var clickThrough: Bool = false
    @Published var displayColor: DisplayColor = .sage
    @Published var displayFont: DisplayFont = .newYork

    // MARK: - Sound
    @Published var soundEnabled: Bool = true

    // MARK: - Reminder
    @Published var reminderEnabled: Bool = false
    @Published var reminderIntervalMinutes: Int = 5
    @Published var reminderPulseID: Int = 0
    @Published var reminderActiveUntil: Date?

    // MARK: - App
    @Published var showDockIcon: Bool = true

    private var displayTimer: Timer?
    private var countdownEndDate: Date?
    private var stopwatchStartDate: Date?
    private var stopwatchAccumulated: TimeInterval = 0
    private var lastCountdownWholeSeconds: Int?
    private var lastStopwatchWholeSeconds: Int?
    private var nextReminderDate: Date?

    init() {
        loadSettings()
        startDisplayTimer()
        requestNotificationPermission()
    }

    deinit {
        displayTimer?.invalidate()
    }

    // MARK: - Display Tick

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshDisplayedTime()
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
        refreshDisplayedTime()
    }

    private func refreshDisplayedTime() {
        let now = Date()
        currentTime = now
        updateCountdown(now: now)
        updateStopwatch(now: now)
        updateReminder(now: now)
    }

    // MARK: - Clock

    var clockDisplayString: String {
        let formatter = DateFormatter()
        if use24Hour {
            formatter.dateFormat = showSeconds ? "HH:mm:ss" : "HH:mm"
        } else {
            formatter.dateFormat = showSeconds ? "h:mm:ss a" : "h:mm a"
        }
        return formatter.string(from: currentTime)
    }

    var dateDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: currentTime)
    }

    // MARK: - Countdown

    func startCountdown() {
        if stopwatchRunning {
            pauseStopwatch()
        }
        let remaining = countdownPaused ? countdownRemaining : countdownTotal
        countdownRemaining = max(0, remaining)
        guard countdownRemaining > 0 else { return }
        countdownEndDate = Date().addingTimeInterval(countdownRemaining)
        lastCountdownWholeSeconds = Int(ceil(countdownRemaining))
        countdownRunning = true
        countdownPaused = false
        refreshDisplayedTime()
    }

    func pauseCountdown() {
        updateCountdown(now: Date())
        countdownRunning = false
        countdownPaused = true
        countdownEndDate = nil
        lastCountdownWholeSeconds = nil
    }

    func resetCountdown() {
        countdownRunning = false
        countdownPaused = false
        countdownEndDate = nil
        lastCountdownWholeSeconds = nil
        countdownRemaining = countdownTotal
    }

    func setCountdownPreset(_ minutes: Int) {
        countdownTotal = TimeInterval(minutes * 60)
        resetCountdown()
    }

    private func updateCountdown(now: Date) {
        guard countdownRunning, let endDate = countdownEndDate else { return }
        let remaining = max(0, endDate.timeIntervalSince(now))
        let wholeSeconds = Int(ceil(remaining))
        if wholeSeconds != lastCountdownWholeSeconds {
            lastCountdownWholeSeconds = wholeSeconds
            countdownRemaining = TimeInterval(wholeSeconds)
        }
        if remaining <= 0 {
            countdownRemaining = 0
            countdownFinished()
        }
    }

    private func countdownFinished() {
        countdownEndDate = nil
        lastCountdownWholeSeconds = nil
        countdownRunning = false
        countdownPaused = false
        playSound()
        sendNotification(title: "Countdown Complete", body: "Your timer has finished!")
        if countdownAutoRepeat {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startCountdown()
            }
        }
    }

    var countdownProgress: Double {
        guard countdownTotal > 0 else { return 0 }
        return 1.0 - (countdownRemaining / countdownTotal)
    }

    // MARK: - Stopwatch

    func startStopwatch() {
        if countdownRunning {
            pauseCountdown()
        }
        guard !stopwatchRunning else { return }
        stopwatchRunning = true
        stopwatchStartDate = Date()
        lastStopwatchWholeSeconds = Int(stopwatchElapsed)
        refreshDisplayedTime()
    }

    func pauseStopwatch() {
        updateStopwatch(now: Date())
        stopwatchRunning = false
        if let start = stopwatchStartDate {
            stopwatchAccumulated += Date().timeIntervalSince(start)
        }
        stopwatchStartDate = nil
        stopwatchElapsed = stopwatchAccumulated
        lastStopwatchWholeSeconds = nil
    }

    func resetStopwatch() {
        stopwatchRunning = false
        stopwatchStartDate = nil
        lastStopwatchWholeSeconds = nil
        stopwatchAccumulated = 0
        stopwatchElapsed = 0
    }

    private func updateStopwatch(now: Date) {
        guard stopwatchRunning, let start = stopwatchStartDate else { return }
        let elapsed = stopwatchAccumulated + now.timeIntervalSince(start)
        let wholeSeconds = Int(elapsed)
        if wholeSeconds != lastStopwatchWholeSeconds {
            lastStopwatchWholeSeconds = wholeSeconds
            stopwatchElapsed = elapsed
        }
    }

    var stopwatchDisplayString: String {
        let total = max(0, Int(stopwatchElapsed))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if showSeconds {
            if h > 0 {
                return String(format: "%d:%02d:%02d", h, m, s)
            }
            return String(format: "%02d:%02d", m, s)
        } else {
            return String(format: "%02d:%02d", h, m)
        }
    }

    // MARK: - Reminder

    var reminderIsActive: Bool {
        guard let activeUntil = reminderActiveUntil else { return false }
        return activeUntil > Date()
    }

    func rescheduleReminder(from date: Date = Date()) {
        guard reminderEnabled else {
            nextReminderDate = nil
            reminderActiveUntil = nil
            return
        }
        let minutes = max(1, reminderIntervalMinutes)
        nextReminderDate = date.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func updateReminder(now: Date) {
        guard reminderEnabled else {
            nextReminderDate = nil
            reminderActiveUntil = nil
            return
        }

        if nextReminderDate == nil {
            rescheduleReminder(from: now)
        }

        if let activeUntil = reminderActiveUntil, activeUntil <= now {
            reminderActiveUntil = nil
        }

        guard let next = nextReminderDate, now >= next else { return }
        reminderPulseID += 1
        reminderActiveUntil = now.addingTimeInterval(5)
        rescheduleReminder(from: now)
    }

    // MARK: - Toggle / Shortcuts

    func toggleStartPause() {
        switch mode {
        case .clock:
            break
        case .countdown:
            if countdownRunning {
                pauseCountdown()
            } else {
                startCountdown()
            }
        case .stopwatch:
            if stopwatchRunning {
                pauseStopwatch()
            } else {
                startStopwatch()
            }
        }
    }

    func cycleMode() {
        let modes = TimeMode.allCases
        guard let idx = modes.firstIndex(of: mode) else { return }
        let next = (idx + 1) % modes.count
        mode = modes[next]
    }

    func resetCurrent() {
        switch mode {
        case .clock: break
        case .countdown: resetCountdown()
        case .stopwatch: resetStopwatch()
        }
    }

    // MARK: - Helpers

    static func formatTime(_ interval: TimeInterval, showSeconds: Bool = true) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if !showSeconds {
            return String(format: "%02d:%02d", h, m)
        }
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func playSound() {
        guard soundEnabled else { return }
        NSSound(named: "Glass")?.play()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    func saveSettings() {
        let d = UserDefaults.standard
        d.set(use24Hour, forKey: "use24Hour")
        d.set(showSeconds, forKey: "showSeconds")
        d.set(showDate, forKey: "showDate")
        d.set(fontSize, forKey: "fontSize")
        d.set(windowOpacity, forKey: "windowOpacity")
        d.set(showShadow, forKey: "showShadow")
        d.set(clickThrough, forKey: "clickThrough")
        d.set(soundEnabled, forKey: "soundEnabled")
        d.set(countdownAutoRepeat, forKey: "countdownAutoRepeat")
        d.set(countdownTotal, forKey: "countdownTotal")
        d.set(mode.rawValue, forKey: "timeMode")
        d.set(displayColor.rawValue, forKey: "displayColor")
        d.set(displayFont.rawValue, forKey: "displayFont")
        d.set(reminderEnabled, forKey: "reminderEnabled")
        d.set(reminderIntervalMinutes, forKey: "reminderIntervalMinutes")
        d.set(showDockIcon, forKey: "showDockIcon")
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        if d.object(forKey: "use24Hour") != nil {
            use24Hour = d.bool(forKey: "use24Hour")
            showSeconds = d.bool(forKey: "showSeconds")
            showDate = d.bool(forKey: "showDate")
            fontSize = CGFloat(d.double(forKey: "fontSize"))
            windowOpacity = d.double(forKey: "windowOpacity")
            showShadow = d.bool(forKey: "showShadow")
            clickThrough = d.bool(forKey: "clickThrough")
            soundEnabled = d.bool(forKey: "soundEnabled")
            countdownAutoRepeat = d.bool(forKey: "countdownAutoRepeat")
            countdownTotal = d.double(forKey: "countdownTotal")
            countdownRemaining = countdownTotal
            if let modeStr = d.string(forKey: "timeMode"), let m = TimeMode(rawValue: modeStr) {
                mode = m
            }
            if let colorStr = d.string(forKey: "displayColor"), let c = DisplayColor(rawValue: colorStr) {
                displayColor = c
            }
            if let fontStr = d.string(forKey: "displayFont"), let f = DisplayFont(rawValue: fontStr) {
                displayFont = f
            }
            if d.object(forKey: "reminderEnabled") != nil {
                reminderEnabled = d.bool(forKey: "reminderEnabled")
            }
            if d.object(forKey: "reminderIntervalMinutes") != nil {
                reminderIntervalMinutes = d.integer(forKey: "reminderIntervalMinutes")
            }
            if d.object(forKey: "showDockIcon") != nil {
                showDockIcon = d.bool(forKey: "showDockIcon")
            }
            if fontSize < 40 { fontSize = 65 }
            if windowOpacity <= 0 { windowOpacity = 1.0 }
            if countdownTotal <= 0 { countdownTotal = 25 * 60; countdownRemaining = countdownTotal }
            if reminderIntervalMinutes < 1 { reminderIntervalMinutes = 5 }
        }
        fontSize = roundedFontSize(fontSize)
        countdownTotal = roundedCountdownDuration(countdownTotal)
        countdownRemaining = countdownTotal
        rescheduleReminder()
    }
}

private func roundedFontSize(_ value: CGFloat) -> CGFloat {
    min(200, max(40, (value / 5).rounded() * 5))
}

private func roundedCountdownDuration(_ value: TimeInterval) -> TimeInterval {
    let fiveMinutes = 5 * 60
    let units = max(1, Int((value / TimeInterval(fiveMinutes)).rounded()))
    return TimeInterval(units * fiveMinutes)
}
