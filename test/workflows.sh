#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

ruby -ryaml -e '
  smoke = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: true)
  release = YAML.safe_load(File.read(ARGV.fetch(1)), aliases: true)

  smoke_container = smoke.dig("jobs", "integration", "container")
  abort "smoke integration must run as root" unless smoke_container == {
    "image" => "${{ matrix.image }}",
    "options" => "--user root"
  }

  triggers = release.fetch(true)
  abort "release tag trigger is missing" unless triggers.dig("push", "tags") == ["v*"]
  manual_tag = triggers.dig("workflow_dispatch", "inputs", "tag")
  abort "manual release tag must be required" unless manual_tag&.fetch("required", false) == true

  release_container = release.dig("jobs", "integration", "container")
  abort "release integration must run as root" unless release_container == {
    "image" => "heroku/heroku:26-build",
    "options" => "--user root"
  }

  publish = release.dig("jobs", "release")
  abort "release must depend on all tests" unless publish.fetch("needs") == ["unit", "integration"]
  abort "release must have write permission" unless publish.dig("permissions", "contents") == "write"
' "$ROOT/.github/workflows/smoke.yml" "$ROOT/.github/workflows/release.yml"

printf 'workflow tests ok\n'
