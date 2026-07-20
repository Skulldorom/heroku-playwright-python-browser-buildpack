#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for entrypoint in detect compile native-deps release next-version workflows; do "$ROOT/test/$entrypoint.sh"; done
for script in "$ROOT"/bin/* "$ROOT"/test/*.sh; do bash -n "$script"; done
printf 'all tests ok\n'
