#!/bin/bash
# Shared paths only: sourcing this file does not create or remove any files.
TRACKBOARD_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [[ -z "${TRACKBOARD_BUILD_DIR:-}" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # Separate checkouts must not share SwiftPM's path-dependent intermediates.
        TRACKBOARD_CHECKOUT_ID="$(printf '%s' "$TRACKBOARD_ROOT" | cksum | awk '{print $1}')"
        TRACKBOARD_BUILD_DIR="$HOME/Library/Caches/Trackboard/$TRACKBOARD_CHECKOUT_ID"
    else
        TRACKBOARD_BUILD_DIR="$TRACKBOARD_ROOT/.build/trackboard"
    fi
fi
case "$TRACKBOARD_BUILD_DIR" in
    /*) ;;
    *) TRACKBOARD_BUILD_DIR="$TRACKBOARD_ROOT/$TRACKBOARD_BUILD_DIR" ;;
esac
TRACKBOARD_SCRATCH_PATH="$TRACKBOARD_BUILD_DIR/swiftpm"
TRACKBOARD_APP_PATH="$TRACKBOARD_BUILD_DIR/Trackboard.app"
