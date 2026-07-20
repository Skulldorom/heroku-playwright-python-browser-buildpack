#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
"$ROOT/bin/release" >"$TMP/release.yml"
ruby -ryaml -e '
  release = YAML.safe_load(File.read(ARGV.fetch(0)))
  abort "addons must be empty" unless release["addons"] == []
  expected = {
    "PLAYWRIGHT_BROWSERS_PATH" => "/app/.cache/ms-playwright",
    "PLAYWRIGHT_BUILDPACK_BROWSERS" => "chromium-headless-shell",
    "PLAYWRIGHT_INSTALL_NATIVE_DEPS" => "true",
    "PLAYWRIGHT_SKIP_BROWSER_GC" => "1"
  }
  abort "unexpected config_vars" unless release["config_vars"] == expected
' "$TMP/release.yml"
printf 'release tests ok\n'
