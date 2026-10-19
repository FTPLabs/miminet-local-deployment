#!/usr/bin/env sh
# Backwards-compatible entry point. The implementation lives in scripts/setup.sh.
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$ROOT_DIR/scripts/setup.sh" "$@"
