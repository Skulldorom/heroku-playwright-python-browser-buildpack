#!/usr/bin/env bash

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"; }
assert_not_contains() { ! grep -Fq -- "$2" "$1" || fail "$1 unexpectedly contains: $2"; }
assert_success() { "$@" || fail "command failed: $*"; }
assert_failure() { if "$@"; then fail "command unexpectedly succeeded: $*"; fi; }

new_fixture() {
  TEST_TMP=$(mktemp -d)
  BUILD_DIR="$TEST_TMP/build"
  CACHE_DIR="$TEST_TMP/cache"
  ENV_DIR="$TEST_TMP/env"
  FAKEBIN="$TEST_TMP/bin"
  mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR" "$FAKEBIN"
}
