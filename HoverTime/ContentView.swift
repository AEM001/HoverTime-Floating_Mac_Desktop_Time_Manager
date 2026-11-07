//
//  ContentView.swift
//  HoverTime
//

import SwiftUI
import AppKit

extension DisplayColor {
    var nsColor: NSColor {
        adaptiveColor(dark: false)
    }
    func adaptiveColor(dark: Bool) -> NSColor {
        let rgb: (CGFloat, CGFloat, CGFloat)
        switch self {
        case .ink: rgb = dark ? (0.78, 0.86, 1.0) : (0.16, 0.23, 0.36)
        case .porcelain: rgb = dark ? (1.0, 0.91, 0.75) : (0.39, 0.27, 0.16)
        case .graphite: rgb = dark ? (0.88, 0.82, 0.97) : (0.31, 0.24, 0.40)
        case .sage: rgb = dark ? (0.73, 0.91, 0.83) : (0.16, 0.32, 0.28)
        case .frost: rgb = dark ? (0.73, 0.91, 0.97) : (0.14, 0.31, 0.40)
        }
        return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
    var title: String {
        switch self {
        case .ink: return "Harbor"
        case .porcelain: return "Amber"
        case .graphite: return "Iris"
        case .sage: return "Pine"
        case .frost: return "Lagoon"
        }
    }

    var color: Color { Color(nsColor: nsColor) }
}

/// AppKit draws a true glyph outline: positive strokeWidth leaves the centers
/// transparent. The exact same font metrics size the view and its NSPanel.
private struct TimeGlyphRun {
    let text: String
    let font: NSFont
    let color: NSColor
    var outlined = false
    var edge: NSColor? = nil

    var attributedString: NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if outlined {
            attributes[.strokeColor] = color
            attributes[.strokeWidth] = 1.4
        }
        if !outlined, let edge {
            attributes[.strokeColor] = edge
            attributes[.strokeWidth] = -1.0
        }
        return NSAttributedString(string: text, attributes: attributes)
    }

    var size: NSSize {
        let measured = attributedString.size()
        return NSSize(width: ceil(measured.width) + 4, height: ceil(measured.height) + 4)
    }
}

private final class TimeGlyphView: NSView {
    var run: TimeGlyphRun? { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        run?.attributedString.draw(at: NSPoint(x: 2, y: 2))
    }
}

private struct TimeGlyphs: NSViewRepresentable {
    let run: TimeGlyphRun
    func makeNSView(context: Context) -> TimeGlyphView { TimeGlyphView() }
    func updateNSView(_ nsView: TimeGlyphView, context: Context) { nsView.run = run }
}

struct ContentView: View {
    @ObservedObject var manager: TimerManager

    private var isDark: Bool { manager.adaptiveColor && manager.adaptiveDarkBackground }
    private var foreground: NSColor { manager.displayColor.adaptiveColor(dark: isDark) }
    private var surface: Color {
        isDark ? Color(red: 0.10, green: 0.14, blue: 0.21) : Color(red: 0.96, green: 0.97, blue: 0.99)
    }
    private var timeRun: TimeGlyphRun {
        TimeGlyphRun(text: displayText, font: timeFont, color: foreground,
                     outlined: manager.displayRendering == .outline,
                     edge: isDark ? NSColor(srgbRed: 0.10, green: 0.14, blue: 0.21, alpha: 0.9) : NSColor.white.withAlphaComponent(0.9))
    }
    private var dateRun: TimeGlyphRun {
        TimeGlyphRun(text: manager.dateDisplayString,
                     font: .systemFont(ofSize: max(10, manager.fontSize * 0.21), weight: .medium),
                     color: foreground.withAlphaComponent(0.72))
    }
    private var reminderRun: TimeGlyphRun {
        TimeGlyphRun(text: "LOOK UP · REST YOUR EYES", font: .systemFont(ofSize: max(9, manager.fontSize * 0.16), weight: .semibold),
                     color: foreground)
    }
    private var showsDate: Bool { manager.mode == .clock && manager.showDate }

    /// Independent of the hosting view's previous frame, so shrinking the font
    /// or hiding seconds shrinks the actual window and its mouse hit area too.
    var displaySize: NSSize {
        let time = timeRun.size
        let date = showsDate ? dateRun.size : .zero
        let reminder = manager.reminderIsActive ? reminderRun.size : .zero
        return NSSize(width: max(time.width, date.width, reminder.width) + 12,
                      height: time.height + date.height + reminder.height + 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            if manager.reminderIsActive { glyphs(reminderRun) }
            glyphs(timeRun)
            if showsDate { glyphs(dateRun) }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(width: displaySize.width, height: displaySize.height)
        // Imperceptible alpha retains a draggable hit surface in a clear NSPanel.
         .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(manager.showBackdrop ? surface.opacity(0.92) : Color.black.opacity(0.001))
                .overlay {
                    if manager.showBackdrop {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(nsColor: foreground).opacity(0.18), lineWidth: 1)
                    }
                }
        }
        .contentShape(Rectangle())
        .fixedSize()
        .help("Drag to move · Click for controls")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(manager.mode.rawValue): \(displayText)")
        .accessibilityAction(named: "Open controls") {
            (NSApp.delegate as? AppDelegate)?.toggleCompactControls()
        }
    }

    private func glyphs(_ run: TimeGlyphRun) -> some View {
        TimeGlyphs(run: run)
            .frame(width: run.size.width, height: run.size.height)
            .shadow(color: manager.showShadow ? .black.opacity(0.15) : .clear, radius: 2, y: 1)
    }

    private var displayText: String {
        switch manager.mode {
        case .clock: return manager.clockDisplayString
        case .countdown: return TimerManager.formatTime(manager.countdownRemaining, showSeconds: manager.showSeconds)
        case .stopwatch: return manager.stopwatchDisplayString
        }
    }

    private var timeFont: NSFont {
        let size = manager.fontSize
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
        switch manager.displayFont {
        case .sfProRounded:
            return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        case .newYork:
            return base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        case .sfProHeavy: return .monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        case .impact: return NSFont(name: "Impact", size: size) ?? base
        case .arialBlack: return NSFont(name: "Arial-BoldMT", size: size) ?? base
        }
    }
}

// MARK: - Time Picker Field Component

struct TimePickerField: View {
    let label: String
    @Binding var value: Int
    let options: [Int]
    let suffix: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Button(action: { cycleDown() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("\(value)")
                    .frame(width: 42)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                
                Button(action: { cycleUp() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private func cycleUp() {
        guard let currentIndex = options.firstIndex(of: value) else {
            value = options.first ?? 0
            return
        }
        let nextIndex = (currentIndex + 1) % options.count
        value = options[nextIndex]
    }
    
    private func cycleDown() {
        guard let currentIndex = options.firstIndex(of: value) else {
            value = options.last ?? 0
            return
        }
        let prevIndex = currentIndex == 0 ? options.count - 1 : currentIndex - 1
        value = options[prevIndex]
    }
}
