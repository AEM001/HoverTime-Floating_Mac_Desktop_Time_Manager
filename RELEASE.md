# Release Notes

## 2026-11-07 panel rendering fix

- Isolate ticking time into a fixed-size readout. The panel and appearance controls observe deduplicated configuration snapshots rather than every half-second timer publication.
- Draw the solid rounded background in a stationary AppKit view, independent of SwiftUI time updates; disable implicit panel animations and reserve stable space for status text.
- Remove all control-window resizing from the timer publication subscription.
- Linux cross build and nonvisual subscription checks passed: time ticks produce zero configuration updates, while font and mode changes remain responsive. No screenshot or UI tests performed.

## 2026-11-07 follow-up

- Expose manual Deep / Light palette selection, including light blue, cream, lilac, mint and ice cyan. Swatches show the effective tone.
- Fix size-slider movement feedback: disable HostingView size negotiation for quick controls, keep their frame fixed while editing, and resize the display atomically from its top-left anchor. Only actual pointer dragging dismisses controls.
- Back off adaptation from 45 seconds to 120 seconds after stable observations. Use a five-minute median, Schmitt thresholds (0.18 / 0.32), 60-second confirmation and 180-second minimum dwell; moving preserves dwell time.
- Cache content filters for five minutes, skip captures during editing/dragging or while hidden, honor low power mode, and exponentially back off failures to fifteen minutes. One-shot timers allow 15% scheduling tolerance. No image files or continuous capture stream.
- Linux cross build and scalar policy checks passed (confirmation, hysteresis, dwell, noise, stale history and sampling backoff). No UI or screenshot tests performed.

## 2026-11-07

- Redesign quick controls with icon mode cards, a larger timer, paired palette swatches, size slider, typeface selection and appearance switches.
- Replace muddy display colors with Harbor, Amber, Iris, Pine and Lagoon pairs; add fine glyph edges and an optional protective surface.
- Add opt-in local background adaptation: a 16×16 regional sample every 30 seconds, excluding this app, with a five-minute median, hysteresis and a two-minute minimum between changes. History resets when moved; no image is saved, and sampling stops while disabled or hidden.
- Screen Recording permission is requested only when enabling adaptation. Without permission, or on failure, the fixed palette and optional protective surface remain available.
- Built on Linux with the shared macOS cross compiler. No screenshot or UI tests run; desktop verification is left to the user.

## 2026-11-05

- Use a persistent native status menu so timer updates cannot dismiss Mode submenus.
- Reset completed countdowns to the configured duration; Auto-repeat starts the next run immediately.
- Keep the floating display transparent, with a palette tuned for light backgrounds and optional hollow glyph outlines.
- Fit the actual window and mouse hit area to the text, including when shrinking the font or hiding seconds.
- Add a live appearance preview, rounded system numerals and optional soft text shadow.

Built with the shared macOS cross compiler on `ssh my`, ARM64, minimum macOS 15. Strict signature verification and local timer, menu identity and window resizing regression checks passed.

## 1.1.0

- Fix window dragging and distinguish clicks from drags.
- Preserve window position; recover off-screen windows after display changes.
- Add direct mode selection, grouped settings and countdown status.
- Add a menu-bar click-through toggle to restore mouse interaction.
- Fix overdue reminders and cancelled auto-repeat restarting unexpectedly.
- Cache formatters and fit the floating window to its actual content.
- Release build supports macOS 15+, Apple silicon and Intel.

Validated with a Release build and AppKit smoke checks for clicks, dragging, click-through, screen recovery, preset protection, stopwatch reset, overdue reminders, and font sizing. Physical mouse and multi-monitor behavior still require desktop verification.

## HoverTime Desktop Timer 1.0.0

Initial product-ready release for macOS.

### Highlights

- Floating desktop clock, countdown, and stopwatch
- Always-on-top transparent timer display across Spaces and fullscreen apps
- Compact click-to-open control panel
- Refined low-distraction visual design
- Global seconds setting across all modes
- 5-point font size controls
- Countdown duration picker with 5-minute steps
- Configurable reminder pulse
- Optional Dock icon
- Native countdown completion notification and sound

### Distribution Notes

- Bundle identifier: `com.albert.HoverTime`
- Minimum supported macOS target for manual builds: `macOS 15.0`
- Current manual build output: `dist/HoverTime.app`

### Known Notes

- The Xcode project remains named `HoverTime` for compatibility with the existing target and scheme.
- Public-facing documentation uses `HoverTime Desktop Timer` for clearer discovery.
