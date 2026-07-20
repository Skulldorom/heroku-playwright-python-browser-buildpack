#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"
trap 'rm -rf "${TEST_TMP:-}"' EXIT

for manifest in pyproject.toml uv.lock requirements.txt poetry.lock; do
  new_fixture
  touch "$BUILD_DIR/$manifest"
  assert_success "$ROOT/bin/detect" "$BUILD_DIR" >"$TEST_TMP/output"
  assert_contains "$TEST_TMP/output" "Playwright Python browser installer"
  rm -rf "$TEST_TMP"
done

new_fixture
touch "$BUILD_DIR/package.json"
assert_failure "$ROOT/bin/detect" "$BUILD_DIR" 2>"$TEST_TMP/error"
assert_contains "$TEST_TMP/error" "Python app not detected"
printf 'detect tests ok\n'
