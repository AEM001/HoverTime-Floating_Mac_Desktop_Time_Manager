# HoverTime

A floating, always-on-top time utility for macOS. Transparent window with only numbers visible — minimal distraction, persistent visibility across all apps and Spaces.

## Features

### Time Modes
- **Clock** — Digital time (HH:MM:SS), 12h/24h toggle, optional date & seconds
- **Countdown** — Manual input or presets (5, 10, 25, 45, 60 min), pause/resume/reset, visual progress ring, auto-repeat
- **Pomodoro** — 25/5 work/break cycle, customizable durations, session counter, long break after N sessions, auto-start toggle

### Window Behavior
- Always-on-top (floats above all windows including fullscreen)
- Visible across all Spaces
- Fully transparent background — only numbers are visible
- Click-through mode (optional)
- Draggable positioning with position memory
- Adjustable font size and opacity
- Optional background blur

### System Integration
- Menu bar control (clock icon)
- LSUIElement — no Dock icon
- macOS native notifications on timer completion
- Sound notification (Glass)
- Settings persistence via UserDefaults

### Keyboard Shortcuts
| Action       | Shortcut       |
|-------------|----------------|
| Show/Hide   | Cmd+Shift+T    |
| Start/Pause | Cmd+Shift+S    |
| Cycle Mode  | Cmd+Shift+M    |
| Reset       | Cmd+Shift+R    |

## Build & Run

### Requirements
- macOS 15+ (Sequoia)
- Xcode 16+

### Steps
1. Open `HoverTime.xcodeproj` in Xcode
2. Select the **HoverTime** scheme
3. Press **Cmd+R** to build and run

The app launches as a menu bar app (no Dock icon). A floating time display appears on screen. Right-click the clock icon in the menu bar for controls and settings.

## Architecture

| File | Purpose |
|------|---------|
| `HoverTimeApp.swift` | App entry point, wires AppDelegate |
| `AppDelegate.swift` | Creates floating panel, menu bar, global hotkeys, settings window |
| `FloatingPanel.swift` | NSPanel subclass — always-on-top, transparent, draggable, click-through |
| `TimerManager.swift` | Core logic — clock, countdown, pomodoro state machines, persistence |
| `ContentView.swift` | SwiftUI floating display — minimal typography, progress rings, hover controls |
| `SettingsView.swift` | Tabbed settings — general, clock, countdown, pomodoro, appearance |
| `Info.plist` | LSUIElement (menu bar only app) |

## UX Philosophy
- Always visible, never intrusive
- Zero friction — hover to reveal controls
- One-click state changes
- Minimal cognitive load
