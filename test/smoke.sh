#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

BUILD_DIR="$TMP/build"
CACHE_DIR="$TMP/cache"
ENV_DIR="$TMP/env"
mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"

touch "$BUILD_DIR/pyproject.toml"

"$ROOT/bin/detect" "$BUILD_DIR" >/tmp/detect.out
grep -q "Playwright Python browser installer" /tmp/detect.out

bash -n "$ROOT/bin/detect"
bash -n "$ROOT/bin/compile"
bash -n "$ROOT/bin/release"

printf 'smoke ok\n'
