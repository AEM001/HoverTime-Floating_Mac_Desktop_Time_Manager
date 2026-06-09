//
//  StatsManager.swift
//  HoverTime
//

import Foundation
import Combine
import SwiftUI

struct SessionRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var mode: String       // "Stopwatch" or "Countdown"
    var duration: TimeInterval
    var label: String?     // optional tag
}

class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published var records: [SessionRecord] = []

    private let key = "sessionRecords"

    init() { load() }

    // MARK: - Record

    func record(mode: String, duration: TimeInterval, label: String? = nil) {
        guard duration >= 1 else { return }
        let r = SessionRecord(date: Date(), mode: mode, duration: duration, label: label)
        records.append(r)
        save()
    }

    func deleteRecord(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    func clearAll() {
        records.removeAll()
        save()
    }

    // MARK: - Computed stats

    var totalFocusTime: TimeInterval {
        records.filter { $0.mode == "Countdown" }.reduce(0) { $0 + $1.duration }
    }

    var totalStopwatchTime: TimeInterval {
        records.filter { $0.mode == "Stopwatch" }.reduce(0) { $0 + $1.duration }
    }

    var totalSessions: Int { records.count }

    var todayRecords: [SessionRecord] {
        records.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayFocusTime: TimeInterval {
        todayRecords.filter { $0.mode == "Countdown" }.reduce(0) { $0 + $1.duration }
    }

    var todayStopwatchTime: TimeInterval {
        todayRecords.filter { $0.mode == "Stopwatch" }.reduce(0) { $0 + $1.duration }
    }

    var averageSessionDuration: TimeInterval {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.duration } / Double(records.count)
    }

    var longestSession: TimeInterval {
        records.map(\.duration).max() ?? 0
    }

    // Daily totals for past 7 days
    struct DailyStat: Identifiable {
        var id: Date { day }
        var day: Date
        var totalSeconds: TimeInterval
        var label: String
    }

    var last7DaysStats: [DailyStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset -> DailyStat? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayRecords = records.filter { cal.isDate($0.date, inSameDayAs: day) }
            let total = dayRecords.reduce(0) { $0 + $1.duration }
            let formatter = DateFormatter()
            formatter.dateFormat = offset == 0 ? "'Today'" : "EEE"
            return DailyStat(day: day, totalSeconds: total, label: formatter.string(from: day))
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) else { return }
        records = decoded
    }
}
