//
//  ContentView.swift
//  HoverTime
//

import SwiftUI
import AppKit

// MARK: - Main ContentView (floating display only)

struct ContentView: View {
    @ObservedObject var manager: TimerManager
    @State private var colonHovered = false

    var body: some View {
        VStack(spacing: manager.reminderIsActive ? 4 : 2) {
            if manager.reminderIsActive {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("LOOK UP")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black.opacity(0.82))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.65),
                                    reminderColor,
                                    reminderColor.opacity(0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.75), lineWidth: 0.7)
                        )
                        .shadow(color: reminderColor.opacity(0.45), radius: 6, x: 0, y: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            switch manager.mode {
            case .clock:     clockView
            case .countdown: countdownView
            case .stopwatch: stopwatchView
            }
        }
        .padding(.horizontal, manager.reminderIsActive ? 18 : 12)
        .padding(.vertical, manager.reminderIsActive ? 8 : 4)
        .background(panelBackground)
        .overlay(reminderOverlay)
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.001))
        .scaleEffect(manager.reminderIsActive ? 1.08 : 1)
        .animation(.easeInOut(duration: 0.48).repeatCount(8, autoreverses: true), value: manager.reminderPulseID)
        .animation(.easeOut(duration: 0.2), value: manager.reminderIsActive)
        .fixedSize()
    }

    // MARK: - Color & Font Helpers

    var tintColor: Color {
        switch manager.displayColor {
        case .porcelain: return Color(red: 0.92, green: 0.90, blue: 0.84)
        case .graphite: return Color(red: 0.76, green: 0.78, blue: 0.76)
        case .sage: return Color(red: 0.68, green: 0.76, blue: 0.67)
        case .frost: return Color(red: 0.62, green: 0.74, blue: 0.82)
        }
    }

    private var glowColor: Color { tintColor.opacity(0.22) }
    private var reminderColor: Color { Color(red: 1.0, green: 0.80, blue: 0.18) }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(manager.showShadow ? 0.055 : 0.025))

            if manager.showShadow {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .opacity(0.72)
            }

            // Liquid glass specular highlight: a soft white sheen along the top edge.
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .mask(
                    RoundedRectangle(cornerRadius: 10)
                        .padding(.horizontal, 0.5)
                )

            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)

            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.8)
                .blendMode(.multiply)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 2)
        .shadow(color: Color.white.opacity(0.14), radius: 5, x: 0, y: 0)
    }

    @ViewBuilder
    private var reminderOverlay: some View {
        if manager.reminderIsActive {
            ZStack {
                // Warm golden wash layered under the glass for a liquid-glass glow.
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: reminderColor.opacity(0.08), location: 0.0),
                                .init(color: reminderColor.opacity(0.22), location: 0.5),
                                .init(color: reminderColor.opacity(0.06), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner specular stroke to simulate a glassy rim catching the light.
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                reminderColor.opacity(0.95),
                                Color.white.opacity(0.55),
                                reminderColor.opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.6
                    )

                // Outer accent stroke.
                RoundedRectangle(cornerRadius: 12)
                    .stroke(reminderColor.opacity(0.55), lineWidth: 0.6)
                    .blur(radius: 0.3)
            }
            .shadow(color: reminderColor.opacity(0.60), radius: 20, x: 0, y: 0)
            .shadow(color: reminderColor.opacity(0.30), radius: 40, x: 0, y: 0)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    func timeFont(size: CGFloat) -> Font {
        switch manager.displayFont {
        case .newYork:   return .system(size: size, weight: .semibold, design: .serif)
        case .sfProHeavy: return .system(size: size, weight: .semibold, design: .default)
        case .impact:    return Font.custom("Impact", size: size)
        case .arialBlack: return Font.custom("Arial-BoldMT", size: size)
        }
    }

    // MARK: - Time display with colon-as-click-target

    /// Renders the time string with a subtle hover affordance on each colon.
    /// The enclosing FloatingPanel owns click detection so it remains reliable
    /// for this borderless AppKit window.
    @ViewBuilder
    private func timeDisplay(_ text: String) -> some View {
        let parts = text.components(separatedBy: ":")
        HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                if idx > 0 {
                    colonHotspot
                }
                Text(part)
                    .font(timeFont(size: manager.fontSize))
                    .foregroundStyle(tintColor)
                    .monospacedDigit()
            }
        }
        .shadow(color: .white.opacity(0.30), radius: 1.0, x: 0, y: 0)
        .shadow(color: glowColor, radius: manager.reminderIsActive ? 14 : 5, x: 0, y: 0)
        .shadow(color: .black.opacity(0.58), radius: 2.0, x: 0, y: 1)
        .fixedSize()
    }

    /// The colon opens the small temporary control panel.
    private var colonHotspot: some View {
        Text(":")
            .font(timeFont(size: manager.fontSize))
            .foregroundStyle(tintColor)
            .monospacedDigit()
            .contentShape(Rectangle())
            .onHover { hovering in colonHovered = hovering }
            .scaleEffect(colonHovered ? 1.12 : 1)
            .animation(.easeOut(duration: 0.15), value: colonHovered)
    }

    // MARK: - Clock View

    private var clockView: some View {
        VStack(spacing: 2) {
            timeDisplay(manager.clockDisplayString)
            if manager.showDate {
                Text(manager.dateDisplayString)
                    .font(timeFont(size: manager.fontSize * 0.3))
                    .foregroundStyle(tintColor.opacity(0.68))
                    .shadow(color: .white.opacity(0.22), radius: 0.8, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.42), radius: 1.5, x: 0, y: 1)
            }
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        timeDisplay(TimerManager.formatTime(manager.countdownRemaining, showSeconds: manager.showSeconds))
    }

    // MARK: - Stopwatch View

    private var stopwatchView: some View {
        timeDisplay(manager.stopwatchDisplayString)
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
