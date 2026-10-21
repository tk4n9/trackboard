#!/bin/bash
set -euo pipefail

TRACKBOARD_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'Building Trackboard.app requires macOS 13+ and Xcode Command Line Tools.' >&2
    exit 2
fi
cd "$TRACKBOARD_ROOT"
command -v swift >/dev/null || { printf '%s\n' 'Install Xcode Command Line Tools: xcode-select --install' >&2; exit 2; }
xcrun --find clang >/dev/null

BUILD_ARGS=(-c release)
if [[ "${TRACKBOARD_UNIVERSAL:-0}" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}" --product Trackboard
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
mkdir -p dist
STAGE="$(mktemp -d "$TRACKBOARD_ROOT/dist/.package.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
APP="$STAGE/Trackboard.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/Trackboard" "$APP/Contents/MacOS/Trackboard"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
xcrun swift scripts/render-icon.swift "$APP/Contents/Resources/InputMenu.tiff"
plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign "${TRACKBOARD_SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
if [[ -e dist/Trackboard.app ]]; then mv dist/Trackboard.app "$STAGE/previous.app"; fi
mv "$APP" dist/Trackboard.app
printf '\nBuilt %s\n' "$TRACKBOARD_ROOT/dist/Trackboard.app"
printf '%s\n' 'Install for your account with: ./scripts/install.sh'
