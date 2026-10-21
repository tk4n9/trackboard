#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'Trackboard can only be installed on macOS.' >&2
    exit 2
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/build-paths.sh"
APP="$TRACKBOARD_APP_PATH"
if [[ ! -x "$APP/Contents/MacOS/Trackboard" ]]; then
    printf '%s\n' 'Build the app first: ./scripts/build.sh' >&2
    exit 2
fi
codesign --verify --strict "$APP"
DESTINATION="$HOME/Library/Input Methods/Trackboard.app"
mkdir -p "$HOME/Library/Input Methods"
STAGE="$(mktemp -d "$HOME/Library/Input Methods/.trackboard-install.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
ditto --norsrc --noextattr "$APP" "$STAGE/Trackboard.app"
codesign --verify --strict "$STAGE/Trackboard.app"
if [[ -e "$DESTINATION" ]]; then
    EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist")"
    if [[ "$EXISTING_ID" != 'dev.trackboard.inputmethod' ]]; then
        printf '%s\n' 'The destination contains a different application; it was not replaced.' >&2
        exit 1
    fi
    mkdir -p "$HOME/Library/Caches/Trackboard/backups"
    BACKUP="$(mktemp -d "$HOME/Library/Caches/Trackboard/backups/install.XXXXXX")"
    mv "$DESTINATION" "$BACKUP/Trackboard.app"
    printf 'Previous version preserved at %s\n' "$BACKUP/Trackboard.app"
fi
mv "$STAGE/Trackboard.app" "$DESTINATION"
if ! "$DESTINATION/Contents/MacOS/Trackboard" --register; then
    printf '%s\n' 'The app is installed. macOS may need a logout before it can register the input source.'
fi
printf '\nInstalled %s\n' "$DESTINATION"
printf '%s\n' \
    'Log out and back in after first installation or an update.' \
    'In System Settings → Keyboard → Text Input → Edit → +, add Trackboard (under Korean).' \
    'Click a text field, then select Trackboard from the input menu.' \
    'Return inserts handwriting. Escape closes the pad; Control–Shift–Space reopens it.'
