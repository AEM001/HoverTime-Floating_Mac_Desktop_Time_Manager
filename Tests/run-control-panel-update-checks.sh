#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output=$(mktemp -d "${TMPDIR:-/tmp}/HoverTime-controls.XXXXXX")
python3 - "$output/ControlPanelUpdateChecks.swift" <<'PY'
from pathlib import Path
import sys
source = Path('HoverTime/CompactControlPanel.swift').read_text()
model = source[source.index('private final class ControlPanelUpdates:'):]
Path(sys.argv[1]).write_text('import Foundation\nimport Combine\n' + model + Path('Tests/ControlPanelUpdateChecks.swift.inc').read_text())
PY
scp "$output/ControlPanelUpdateChecks.swift" my:code/macos-cross-build/projects/HoverTime/app/ControlPanelUpdateChecks.swift
ssh my 'bash -s' <<'REMOTE'
set -euo pipefail
cd ~/code/macos-cross-build
docker run --rm -i -v "$PWD/projects/HoverTime/app:/workspace" -v "$PWD/shared/toolchain/.stage/27/sdks:/opt/apple/sdks:ro" macos-cross:27 bash -s <<'BUILD'
set -euo pipefail
cd /workspace
SDK=/opt/apple/sdks/MacOSX.sdk
arm64-apple-macos-swiftc -Xlinker -syslibroot -Xlinker "$SDK" -L "$SDK/usr/lib/swift" -F "$SDK/System/Library/Frameworks" -parse-as-library -swift-version 5 -module-cache-path /workspace/.module-cache ControlPanelUpdateChecks.swift -o ControlPanelUpdateChecks
BUILD
REMOTE
scp my:code/macos-cross-build/projects/HoverTime/app/ControlPanelUpdateChecks "$output/ControlPanelUpdateChecks"
chmod +x "$output/ControlPanelUpdateChecks"
codesign --force --sign - "$output/ControlPanelUpdateChecks"
"$output/ControlPanelUpdateChecks"
