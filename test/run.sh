#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

for entrypoint in detect compile native-deps next-version; do
  "$ROOT/test/$entrypoint.sh"
done

if command -v ruby >/dev/null 2>&1; then
  "$ROOT/test/release.sh"
  "$ROOT/test/workflows.sh"
else
  printf 'SKIP: release and workflow tests (ruby missing)\n'
fi

for script in "$ROOT"/bin/* "$ROOT"/test/*.sh; do bash -n "$script"; done
printf 'all tests ok\n'
