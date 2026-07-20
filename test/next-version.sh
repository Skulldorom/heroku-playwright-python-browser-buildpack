#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

test "$("$ROOT/bin/next-version")" = v0.0.1
test "$("$ROOT/bin/next-version" v1.2.3 patch)" = v1.2.4
test "$("$ROOT/bin/next-version" v1.2.3 minor)" = v1.3.0
test "$("$ROOT/bin/next-version" v1.2.3 major)" = v2.0.0

if "$ROOT/bin/next-version" v1.2 invalid >/dev/null 2>&1; then
  echo "invalid versions must fail" >&2
  exit 1
fi

if "$ROOT/bin/next-version" v1.2.3 invalid >/dev/null 2>&1; then
  echo "invalid increments must fail" >&2
  exit 1
fi

printf 'next-version tests ok\n'
