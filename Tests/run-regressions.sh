#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output=$(mktemp -d "${TMPDIR:-/tmp}/HoverTime-regressions.XXXXXX")
python3 Tests/prepare-regressions.py "$output"
rsync -av --include='*/' --include='*.swift' --exclude='*' "$output/" my:code/macos-cross-build/projects/HoverTime/app/regression-tests/
ssh my 'bash -s' <<'REMOTE'
set -euo pipefail
cd ~/code/macos-cross-build
docker run --rm -i -v "$PWD/projects/HoverTime/app:/workspace" -v "$PWD/shared/toolchain/.stage/27/sdks:/opt/apple/sdks:ro" macos-cross:27 bash -s <<'BUILD'
set -euo pipefail
cd /workspace
SDK=/opt/apple/sdks/MacOSX.sdk
arm64-apple-macos-swiftc -Xlinker -syslibroot -Xlinker "$SDK" \
  -L "$SDK/usr/lib/swift" -F "$SDK/System/Library/Frameworks" \
  -parse-as-library -O -swift-version 5 -default-isolation MainActor \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -enable-upcoming-feature MemberImportVisibility \
  -module-cache-path /workspace/.module-cache -module-name HoverTimeRegression \
  regression-tests/*.swift -o regression-tests/HoverTimeRegression
BUILD
REMOTE
scp my:code/macos-cross-build/projects/HoverTime/app/regression-tests/HoverTimeRegression "$output/HoverTimeRegression"
chmod +x "$output/HoverTimeRegression"
codesign --force --sign - "$output/HoverTimeRegression"
"$output/HoverTimeRegression" "$output"
echo "Previews: $output"
