#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"
trap 'rm -rf "${TEST_TMP:-}"' EXIT

# Keep the fixtures independent of buildpack configuration exported by the
# machine running the tests (for example, PLAYWRIGHT_BROWSERS_PATH=/app).
unset PLAYWRIGHT_BUILDPACK_BROWSERS PLAYWRIGHT_INSTALL_OPTIONS
unset PLAYWRIGHT_BROWSERS_PATH PLAYWRIGHT_INSTALL_NATIVE_DEPS
unset PLAYWRIGHT_NATIVE_DEPS_PACKAGES PLAYWRIGHT_MISSING STACK

write_python() {
  cat >"$FAKEBIN/python" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = -c ]; then [ "${PLAYWRIGHT_MISSING:-0}" != 1 ]; exit; fi
if [ "${1:-}" = -m ] && [ "${2:-}" = playwright ] && [ "${3:-}" = install ]; then
  printf 'args=%s\npath=%s\nskip=%s\n' "${*:4}" "$PLAYWRIGHT_BROWSERS_PATH" "$PLAYWRIGHT_SKIP_BROWSER_GC" >"$BUILD_DIR/install.log"
  exit 0
fi
exit 2
EOF
  chmod +x "$FAKEBIN/python"
}

write_native_stub() {
  mkdir -p "$TEST_TMP/buildpack/bin"
  cp "$ROOT/bin/compile" "$TEST_TMP/buildpack/bin/compile"
  cat >"$TEST_TMP/buildpack/bin/install-native-deps" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$BUILD_DIR/native.log"
EOF
  chmod +x "$TEST_TMP/buildpack/bin/"*
  COMPILE="$TEST_TMP/buildpack/bin/compile"
}

setup() { new_fixture; write_python; write_native_stub; }
run_compile() { PATH="$FAKEBIN:$PATH" BUILD_DIR="$BUILD_DIR" STACK="${STACK:-heroku-24}" "$COMPILE" "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"; }

# Missing Python.
setup
NO_PYTHON_BIN="$TEST_TMP/no-python-bin"
mkdir -p "$NO_PYTHON_BIN"
ln -s "$(command -v dirname)" "$NO_PYTHON_BIN/dirname"
assert_failure env PATH="$NO_PYTHON_BIN" /bin/bash "$COMPILE" "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR" 2>"$TEST_TMP/error"
assert_contains "$TEST_TMP/error" "python was not found"
rm -rf "$TEST_TMP"

# Missing Playwright.
setup
assert_failure env PATH="$FAKEBIN:$PATH" PLAYWRIGHT_MISSING=1 "$COMPILE" "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR" 2>"$TEST_TMP/error"
assert_contains "$TEST_TMP/error" "playwright' is not installed"
rm -rf "$TEST_TMP"

# False-like values all opt out of native dependencies.
for value in 0 false FALSE no n off random ''; do
  setup
  printf '%s' "$value" >"$ENV_DIR/PLAYWRIGHT_INSTALL_NATIVE_DEPS"
  run_compile >/dev/null
  [ ! -e "$BUILD_DIR/native.log" ] || fail "native install ran for false-like value '$value'"
  rm -rf "$TEST_TMP"
done

# ENV_DIR wins over process environment; browser/options/package overrides are forwarded.
setup
printf 'firefox webkit' >"$ENV_DIR/PLAYWRIGHT_BUILDPACK_BROWSERS"
printf '%s' '--with-deps --force' >"$ENV_DIR/PLAYWRIGHT_INSTALL_OPTIONS"
printf 'libone libtwo' >"$ENV_DIR/PLAYWRIGHT_NATIVE_DEPS_PACKAGES"
PLAYWRIGHT_BUILDPACK_BROWSERS=chromium PLAYWRIGHT_INSTALL_OPTIONS=bad run_compile >/dev/null
assert_contains "$BUILD_DIR/install.log" "args=firefox webkit --with-deps --force"
assert_contains "$BUILD_DIR/native.log" "heroku-24 libone libtwo"
rm -rf "$TEST_TMP"

# Relative paths install under BUILD_DIR and become /app paths at runtime.
setup
printf 'vendor/browsers' >"$ENV_DIR/PLAYWRIGHT_BROWSERS_PATH"
run_compile >/dev/null
assert_contains "$BUILD_DIR/install.log" "path=$BUILD_DIR/vendor/browsers"
assert_contains "$BUILD_DIR/.profile.d/playwright-browsers.sh" "PLAYWRIGHT_BROWSERS_PATH='/app/vendor/browsers'"
rm -rf "$TEST_TMP"

# Absolute /app paths remain unchanged for build and runtime.
setup
printf '/app/shared/browsers' >"$ENV_DIR/PLAYWRIGHT_BROWSERS_PATH"
run_compile >/dev/null
assert_contains "$BUILD_DIR/install.log" "path=/app/shared/browsers"
assert_contains "$BUILD_DIR/.profile.d/playwright-browsers.sh" "PLAYWRIGHT_BROWSERS_PATH='/app/shared/browsers'"
rm -rf "$TEST_TMP"

printf 'compile tests ok\n'
