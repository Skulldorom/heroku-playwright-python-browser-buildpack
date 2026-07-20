#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"
trap 'rm -rf "${TEST_TMP:-}"' EXIT

setup() {
  new_fixture
  cat >"$FAKEBIN/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_TMP/apt.log"
cache=''
for arg in "$@"; do case "$arg" in dir::cache=*) cache=${arg#dir::cache=};; esac; done
if [[ " $* " == *" install "* ]] && [ "${EMPTY_DOWNLOAD:-0}" != 1 ]; then mkdir -p "$cache/archives"; : >"$cache/archives/pkg.deb"; fi
EOF
  cat >"$FAKEBIN/dpkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_TMP/dpkg.log"
mkdir -p "$3/usr/lib"; : >"$3/usr/lib/unpacked"
EOF
  chmod +x "$FAKEBIN/"*
}
run_native() { PATH="$FAKEBIN:$PATH" TEST_TMP="$TEST_TMP" "$ROOT/bin/install-native-deps" "$BUILD_DIR" "$CACHE_DIR" "$1" "${2:-}"; }

setup; run_native heroku-26 >"$TEST_TMP/out"
assert_contains "$TEST_TMP/apt.log" libasound2t64
[ -f "$BUILD_DIR/.apt/usr/lib/unpacked" ] || fail "heroku-26 did not unpack"
rm -rf "$TEST_TMP"

# Unchanged inputs reuse cache; package and stack changes invalidate it.
setup
run_native heroku-26 'one two' >/dev/null
run_native heroku-26 'one two' >"$TEST_TMP/reuse"
assert_contains "$TEST_TMP/reuse" "Reusing native dependency APT cache"
run_native heroku-26 'one three' >"$TEST_TMP/packages"
assert_contains "$TEST_TMP/packages" "refreshing APT cache"
run_native ubuntu26.04 'one three' >"$TEST_TMP/stack"
assert_contains "$TEST_TMP/stack" "refreshing APT cache"
rm -rf "$TEST_TMP"

# Custom packages replace defaults.
setup; run_native heroku-26 'custom-a custom-b' >/dev/null
assert_contains "$TEST_TMP/apt.log" custom-a
assert_not_contains "$TEST_TMP/apt.log" libnss3
rm -rf "$TEST_TMP"

# Missing tools and an empty successful download fail clearly.
setup; rm "$FAKEBIN/apt-get"
assert_failure env PATH="$FAKEBIN" /bin/bash "$ROOT/bin/install-native-deps" "$BUILD_DIR" "$CACHE_DIR" heroku-26 custom 2>"$TEST_TMP/error"
assert_contains "$TEST_TMP/error" "apt-get was not found"
rm -rf "$TEST_TMP"
setup; rm "$FAKEBIN/dpkg"
assert_failure env PATH="$FAKEBIN" /bin/bash "$ROOT/bin/install-native-deps" "$BUILD_DIR" "$CACHE_DIR" heroku-26 custom 2>"$TEST_TMP/error"
assert_contains "$TEST_TMP/error" "dpkg was not found"
rm -rf "$TEST_TMP"
setup
assert_failure env PATH="$FAKEBIN:$PATH" TEST_TMP="$TEST_TMP" EMPTY_DOWNLOAD=1 "$ROOT/bin/install-native-deps" "$BUILD_DIR" "$CACHE_DIR" heroku-26 custom 2>"$TEST_TMP/error"
assert_contains "$TEST_TMP/error" "No .deb files were downloaded"
printf 'native dependency tests ok\n'
