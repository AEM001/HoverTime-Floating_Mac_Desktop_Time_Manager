# Regression checks

Run `bash Tests/run-regressions.sh` on the Mac. This prepares the sources, builds
on `ssh my` using the shared toolchain, downloads and signs the test executable,
and runs it locally. The final line reports the PNG preview directory.

`prepare-regressions.py OUTPUT_DIR` copies the current production Swift sources
and adds the regression entry point. Test copies use an isolated UserDefaults
suite and replace only notification delivery/authorization with a counter, so
running tests never changes app preferences or requests notification permission.

Compile the generated sources with the same remote Swift compiler and flags as
`~/code/macos-cross-build/projects/HoverTime/app/build-linux.sh`, omitting
`HoverTimeApp.swift` (the preparer already excludes it). Run the resulting ARM64
executable on a Mac with a GUI session, passing an output directory for PNGs.
The harness checks actual timer transitions, native menu object identities and
menu actions, and renders all three SwiftUI surfaces. It does not simulate
physical pointer movement through an open menu.

Validated 2026-11-05 using the remote macOS toolchain and local execution:

- Expiration, including overdue expiration, resets to the configured duration.
- Completion notifies once and clears paused/running state.
- Duplicate start and pause/resume preserve the deadline/remaining time.
- Auto-repeat restarts immediately; Reset leaves no delayed restart.
- Pause at expiration leaves the countdown reset.
- Starting one timer pauses the other.
- Clock publications preserve submenu and menu-item object identities.
- Mode actions, checkmarks, click-through and shortcuts remain functional.
- Floating display, quick controls and settings render to PNG.

- The actual NSPanel shrinks in width and height with font size and hidden seconds; date text fits.


For adaptation logic only, run `bash Tests/run-backdrop-policy-checks.sh`.
This extracts the production scalar policy, compiles it on Linux with the shared
macOS cross compiler, and runs its command-line assertions locally. It creates
no windows, requests no capture permissions and takes no screenshots. Checks
cover black/white contrast selection at 1001 background luminance values,
including middle gray, and verify that preceding samples do not affect selection.


`bash Tests/run-control-panel-update-checks.sh` extracts the production
configuration subscription and exercises it with a minimal observable input
model. It checks that time ticks produce no panel configuration updates, settings
and running-state changes propagate, and identical settings do not refresh the
panel. Compilation runs on Linux; the CLI assertions run locally without windows
or screenshots. This does not validate compositor behavior on the desktop.

The control-panel subscription checks also exercise all directed mode transitions,
including Clock in both directions, with time publications interleaved. Each
transition must propagate after exactly one assignment. Pointer hit regions and
first-click delivery still require manual desktop verification.
