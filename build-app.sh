#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
build_dir="${TMPDIR:-/tmp}/HoverTime-release"
xcodebuild -project HoverTime.xcodeproj -scheme HoverTime -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$build_dir" \
  MACOSX_DEPLOYMENT_TARGET=15.0 CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= MARKETING_VERSION=1.1.0 CURRENT_PROJECT_VERSION=2 build
mkdir -p dist
ditto "$build_dir/Build/Products/Release/HoverTime.app" dist/HoverTime.app
codesign --verify --deep --strict dist/HoverTime.app
