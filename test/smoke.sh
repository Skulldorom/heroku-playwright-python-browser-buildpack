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
bash -n "$ROOT/bin/install-native-deps"

cat >"$FAKEBIN/python" <<'PYTHON_STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "-c" ]; then
  exit 0
fi

if [ "$1" = "-m" ] && [ "$2" = "playwright" ] && [ "$3" = "install" ]; then
  printf '%s\n' "browser_args=${*:4}" >"$BUILD_DIR/playwright-install.log"
  printf '%s\n' "build_path=$PLAYWRIGHT_BROWSERS_PATH" >>"$BUILD_DIR/playwright-install.log"
  printf '%s\n' "skip_gc=$PLAYWRIGHT_SKIP_BROWSER_GC" >>"$BUILD_DIR/playwright-install.log"
  exit 0
fi

printf 'unexpected python call: %s\n' "$*" >&2
exit 2
PYTHON_STUB
chmod +x "$FAKEBIN/python"

cat >"$FAKEBIN/apt-get" <<'APT_STUB'
#!/usr/bin/env bash
set -euo pipefail

cache_dir=""
mode=""
packages=()
for arg in "$@"; do
  case "$arg" in
    dir::cache=*) cache_dir=${arg#dir::cache=} ;;
    update) mode=update ;;
    install) mode=install ;;
    lib*) packages+=("$arg") ;;
  esac
done

if [ "$mode" = "update" ]; then
  exit 0
fi

if [ "$mode" = "install" ]; then
  mkdir -p "$cache_dir/archives"
  printf '%s\n' "packages=${packages[*]}" >"$BUILD_DIR/native-packages.log"
  : >"$cache_dir/archives/libatk1.0-0t64_1.0_amd64.deb"
  : >"$cache_dir/archives/libnss3_1.0_amd64.deb"
  exit 0
fi

printf 'unexpected apt-get call: %s\n' "$*" >&2
exit 2
APT_STUB
chmod +x "$FAKEBIN/apt-get"

cat >"$FAKEBIN/dpkg" <<'DPKG_STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "-x" ]; then
  dest=$3
  mkdir -p "$dest/usr/lib/x86_64-linux-gnu"
  : >"$dest/usr/lib/x86_64-linux-gnu/libatk-1.0.so.0"
  exit 0
fi

printf 'unexpected dpkg call: %s\n' "$*" >&2
exit 2
DPKG_STUB
chmod +x "$FAKEBIN/dpkg"

PATH="$FAKEBIN:$PATH" BUILD_DIR="$BUILD_DIR" STACK=heroku-26 \
  "$ROOT/bin/compile" "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"

grep -q "browser_args=chromium-headless-shell" "$BUILD_DIR/playwright-install.log"
grep -q "build_path=$BUILD_DIR/.cache/ms-playwright" "$BUILD_DIR/playwright-install.log"
grep -q "skip_gc=1" "$BUILD_DIR/playwright-install.log"
grep -q "libatk1.0-0t64" "$BUILD_DIR/native-packages.log"
test -f "$BUILD_DIR/.apt/usr/lib/x86_64-linux-gnu/libatk-1.0.so.0"
grep -q "PLAYWRIGHT_BROWSERS_PATH='/app/.cache/ms-playwright'" "$BUILD_DIR/.profile.d/playwright-browsers.sh"
grep -q "PLAYWRIGHT_SKIP_BROWSER_GC='1'" "$BUILD_DIR/.profile.d/playwright-browsers.sh"
grep -q "LD_LIBRARY_PATH" "$BUILD_DIR/.profile.d/playwright-browsers.sh"

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
