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
    case white = "White"
    case amber = "Amber"
    case cyan = "Cyan"
    case rose = "Rose"
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
    @Published var stopwatchShowSeconds: Bool = true

    // MARK: - Appearance
    @Published var fontSize: CGFloat = 64
    @Published var windowOpacity: Double = 1.0
    @Published var showShadow: Bool = false
    @Published var clickThrough: Bool = false
    @Published var displayColor: DisplayColor = .cyan
    @Published var displayFont: DisplayFont = .newYork

    // MARK: - Sound
    @Published var soundEnabled: Bool = true

    private var clockTimer: Timer?
    private var countdownTimer: Timer?
    private var stopwatchTimer: Timer?
    private var stopwatchStartDate: Date?
    private var stopwatchAccumulated: TimeInterval = 0

    init() {
        loadSettings()
        startClockTimer()
        requestNotificationPermission()
    }

    // MARK: - Clock

    private func startClockTimer() {
        let interval = showSeconds ? 0.5 : 1.0
        clockTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.currentTime = Date()
        }
    }

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
        if countdownPaused {
            countdownPaused = false
        } else {
            countdownRemaining = countdownTotal
        }
        countdownRunning = true
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.countdownRemaining > 0 {
                self.countdownRemaining -= 1
            } else {
                self.countdownFinished()
            }
        }
    }

    func pauseCountdown() {
        countdownRunning = false
        countdownPaused = true
        countdownTimer?.invalidate()
    }

    func resetCountdown() {
        countdownRunning = false
        countdownPaused = false
        countdownTimer?.invalidate()
        countdownRemaining = countdownTotal
    }

    func setCountdownPreset(_ minutes: Int) {
        countdownTotal = TimeInterval(minutes * 60)
        resetCountdown()
    }

    private func countdownFinished() {
        countdownTimer?.invalidate()
        countdownRunning = false
        countdownPaused = false
        playSound()
        sendNotification(title: "Countdown Complete", body: "Your timer has finished!")
        StatsManager.shared.record(mode: "Countdown", duration: countdownTotal)
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
        stopwatchRunning = true
        stopwatchStartDate = Date()
        stopwatchTimer?.invalidate()
        stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.stopwatchStartDate else { return }
            self.stopwatchElapsed = self.stopwatchAccumulated + Date().timeIntervalSince(start)
        }
    }

    func pauseStopwatch() {
        stopwatchRunning = false
        if let start = stopwatchStartDate {
            stopwatchAccumulated += Date().timeIntervalSince(start)
        }
        stopwatchStartDate = nil
        stopwatchTimer?.invalidate()
        stopwatchElapsed = stopwatchAccumulated
    }

    func resetStopwatch() {
        stopwatchRunning = false
        stopwatchTimer?.invalidate()
        stopwatchStartDate = nil
        if stopwatchAccumulated >= 1 {
            StatsManager.shared.record(mode: "Stopwatch", duration: stopwatchAccumulated)
        }
        stopwatchAccumulated = 0
        stopwatchElapsed = 0
    }

    var stopwatchDisplayString: String {
        let total = max(0, Int(stopwatchElapsed))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if stopwatchShowSeconds {
            if h > 0 {
                return String(format: "%d:%02d:%02d", h, m, s)
            }
            return String(format: "%02d:%02d", m, s)
        } else {
            if h > 0 {
                return String(format: "%d:%02d", h, m)
            }
            return String(format: "%02d min", m)
        }
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

    static func formatTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
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
        d.set(stopwatchShowSeconds, forKey: "stopwatchShowSeconds")
        d.set(countdownAutoRepeat, forKey: "countdownAutoRepeat")
        d.set(countdownTotal, forKey: "countdownTotal")
        d.set(mode.rawValue, forKey: "timeMode")
        d.set(displayColor.rawValue, forKey: "displayColor")
        d.set(displayFont.rawValue, forKey: "displayFont")
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
            if d.object(forKey: "stopwatchShowSeconds") != nil {
                stopwatchShowSeconds = d.bool(forKey: "stopwatchShowSeconds")
            }
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
            if fontSize < 40 { fontSize = 64 }
            if windowOpacity <= 0 { windowOpacity = 1.0 }
            if countdownTotal <= 0 { countdownTotal = 25 * 60; countdownRemaining = countdownTotal }
        }
    }
}
