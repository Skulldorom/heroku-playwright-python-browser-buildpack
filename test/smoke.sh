#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

BUILD_DIR="$TMP/build"
CACHE_DIR="$TMP/cache"
ENV_DIR="$TMP/env"
FAKEBIN="$TMP/fakebin"
mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR" "$FAKEBIN"

touch "$BUILD_DIR/pyproject.toml"

"$ROOT/bin/detect" "$BUILD_DIR" >"$TMP/detect.out"
grep -q "Playwright Python browser installer" "$TMP/detect.out"

bash -n "$ROOT/bin/detect"
bash -n "$ROOT/bin/compile"
bash -n "$ROOT/bin/release"

cat >"$FAKEBIN/python" <<'PYTHON_STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "-c" ]; then
  exit 0
fi

if [ "$1" = "-m" ] && [ "$2" = "playwright" ] && [ "$3" = "install" ]; then
  printf '%s\n' "browser_args=${*:4}" >"$BUILD_DIR/playwright-install.log"
  printf '%s\n' "build_path=$PLAYWRIGHT_BROWSERS_PATH" >>"$BUILD_DIR/playwright-install.log"
  exit 0
fi

printf 'unexpected python call: %s\n' "$*" >&2
exit 2
PYTHON_STUB
chmod +x "$FAKEBIN/python"

PATH="$FAKEBIN:$PATH" BUILD_DIR="$BUILD_DIR" \
  "$ROOT/bin/compile" "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"

grep -q "browser_args=chromium-headless-shell" "$BUILD_DIR/playwright-install.log"
grep -q "build_path=$BUILD_DIR/.cache/ms-playwright" "$BUILD_DIR/playwright-install.log"
grep -q "PLAYWRIGHT_BROWSERS_PATH='/app/.cache/ms-playwright'" "$BUILD_DIR/.profile.d/playwright-browsers.sh"
grep -q "PLAYWRIGHT_SKIP_BROWSER_GC='1'" "$BUILD_DIR/.profile.d/playwright-browsers.sh"

printf 'smoke ok\n'
