//
//  StatsView.swift
//  HoverTime
//

import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var stats = StatsManager.shared
    @State private var showClearConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summarySection
                barChartSection
                sessionListSection
            }
            .padding(24)
        }
        .frame(minWidth: 480, minHeight: 500)
    }

    // MARK: - Summary Cards

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.title2.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard("Today Focus",
                         value: formatDuration(stats.todayFocusTime),
                         icon: "timer", color: .cyan)
                statCard("Today Stopwatch",
                         value: formatDuration(stats.todayStopwatchTime),
                         icon: "stopwatch", color: .orange)
                statCard("Sessions Today",
                         value: "\(stats.todayRecords.count)",
                         icon: "checkmark.circle", color: .green)
                statCard("Total Focus",
                         value: formatDuration(stats.totalFocusTime),
                         icon: "clock.fill", color: .blue)
                statCard("Avg Session",
                         value: formatDuration(stats.averageSessionDuration),
                         icon: "chart.bar", color: .purple)
                statCard("Longest Session",
                         value: formatDuration(stats.longestSession),
                         icon: "flame.fill", color: .red)
            }
        }
    }

    private func statCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Bar Chart (last 7 days)

    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.title2.bold())

            if stats.last7DaysStats.allSatisfy({ $0.totalSeconds == 0 }) {
                Text("No sessions recorded yet. Start a timer to see your stats here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                Chart(stats.last7DaysStats) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Minutes", day.totalSeconds / 60)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
                }
                .chartYAxisLabel("Minutes")
                .frame(height: 180)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Session List

    private var sessionListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session History")
                    .font(.title2.bold())
                Spacer()
                if !stats.records.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear All", systemImage: "trash")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .confirmationDialog("Clear all session history?",
                                        isPresented: $showClearConfirm,
                                        titleVisibility: .visible) {
                        Button("Clear All", role: .destructive) { stats.clearAll() }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }

            if stats.records.isEmpty {
                Text("No sessions yet.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(stats.records.reversed()) { record in
                        sessionRow(record)
                    }
                }
            }
        }
    }

    private func sessionRow(_ record: SessionRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.mode == "Countdown" ? "timer" : "stopwatch")
                .font(.system(size: 14))
                .foregroundStyle(record.mode == "Countdown" ? Color.cyan : Color.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.mode)
                    .font(.subheadline.weight(.medium))
                if let label = record.label, !label.isEmpty {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatDuration(record.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)

            Text(shortDate(record.date))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
        let f = DateFormatter(); f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }
}
