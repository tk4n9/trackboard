#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'Building Trackboard.app requires macOS 13+ and Xcode Command Line Tools.' >&2
    exit 2
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/build-paths.sh"
cd "$TRACKBOARD_ROOT"
command -v swift >/dev/null || { printf '%s\n' 'Install Xcode Command Line Tools: xcode-select --install' >&2; exit 2; }
xcrun --find clang >/dev/null

BUILD_ARGS=(-c release --scratch-path "$TRACKBOARD_SCRATCH_PATH")
if [[ "${TRACKBOARD_UNIVERSAL:-0}" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}" --product Trackboard
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
mkdir -p "$TRACKBOARD_BUILD_DIR"
STAGE="$(mktemp -d "$TRACKBOARD_BUILD_DIR/.package.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
APP="$STAGE/Trackboard.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto --norsrc --noextattr "$BIN_PATH/Trackboard" "$APP/Contents/MacOS/Trackboard"
ditto --norsrc --noextattr Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
xcrun swift scripts/render-icon.swift "$APP/Contents/Resources/InputMenu.tiff"
plutil -lint "$APP/Contents/Info.plist"
# Clean only our newly generated bundle, never the checkout or user's files.
xattr -cr "$APP"
codesign --force --sign "${TRACKBOARD_SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
if [[ -e "$TRACKBOARD_APP_PATH" ]]; then mv "$TRACKBOARD_APP_PATH" "$STAGE/previous.app"; fi
mv "$APP" "$TRACKBOARD_APP_PATH"
printf '\nBuilt %s\n' "$TRACKBOARD_APP_PATH"
printf '%s\n' 'Install for your account with: ./scripts/install.sh'
