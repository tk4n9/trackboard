#!/bin/bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/build-paths.sh"
cd "$TRACKBOARD_ROOT"
# Keep generated/signable bundles outside cloud-synced source folders on macOS.
exec swift test --scratch-path "$TRACKBOARD_SCRATCH_PATH" "$@"
