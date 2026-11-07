#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output=$(mktemp -d "${TMPDIR:-/tmp}/HoverTime-policy.XXXXXX")
python3 - "$output/BackdropPolicyChecks.swift" <<'PY'
from pathlib import Path
import sys
source = Path('HoverTime/AppDelegate.swift').read_text()
policy = source.split('// BEGIN BACKDROP POLICY')[1].split('\n', 1)[1].split('// END BACKDROP POLICY')[0]
Path(sys.argv[1]).write_text('import Foundation\n' + policy + Path('Tests/BackdropPolicyChecks.swift.inc').read_text())
PY
scp "$output/BackdropPolicyChecks.swift" my:code/macos-cross-build/projects/HoverTime/app/BackdropPolicyChecks.swift
ssh my 'bash -s' <<'REMOTE'
set -euo pipefail
cd ~/code/macos-cross-build
docker run --rm -i -v "$PWD/projects/HoverTime/app:/workspace" -v "$PWD/shared/toolchain/.stage/27/sdks:/opt/apple/sdks:ro" macos-cross:27 bash -s <<'BUILD'
set -euo pipefail
cd /workspace
SDK=/opt/apple/sdks/MacOSX.sdk
arm64-apple-macos-swiftc -Xlinker -syslibroot -Xlinker "$SDK" -L "$SDK/usr/lib/swift" -F "$SDK/System/Library/Frameworks" -parse-as-library -swift-version 5 -module-cache-path /workspace/.module-cache BackdropPolicyChecks.swift -o BackdropPolicyChecks
BUILD
REMOTE
scp my:code/macos-cross-build/projects/HoverTime/app/BackdropPolicyChecks "$output/BackdropPolicyChecks"
chmod +x "$output/BackdropPolicyChecks"
codesign --force --sign - "$output/BackdropPolicyChecks"
"$output/BackdropPolicyChecks"
