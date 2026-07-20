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
  abort "release main trigger is missing" unless triggers.dig("push", "branches") == ["main"]
  increment = triggers.dig("workflow_dispatch", "inputs", "increment")
  abort "manual increment must be required" unless increment&.fetch("required", false) == true
  abort "manual increment must be a choice" unless increment["type"] == "choice"
  abort "manual increment choices are invalid" unless increment["options"] == %w[patch minor major]
  abort "automatic increment must default to patch" unless increment["default"] == "patch"
  abort "releases must be serialized" unless release.dig("concurrency", "group") == "release"

  release_container = release.dig("jobs", "integration", "container")
  abort "release integration must run as root" unless release_container == {
    "image" => "heroku/heroku:26-build",
    "options" => "--user root"
  }

  publish = release.dig("jobs", "release")
  abort "release must depend on all tests" unless publish.fetch("needs") == ["unit", "integration"]
  abort "release must have write permission" unless publish.dig("permissions", "contents") == "write"

  steps = publish.fetch("steps")
  version_step = steps.find { |step| step["id"] == "version" }
  abort "release must calculate a version" unless version_step
  abort "automatic releases must increment patch" unless version_step.dig("env", "INCREMENT").include?("patch")
  create_step = steps.find { |step| step["name"] == "Create release" }
  abort "release must use the calculated version" unless create_step.dig("env", "RELEASE_TAG") == "${{ steps.version.outputs.tag }}"
' "$ROOT/.github/workflows/smoke.yml" "$ROOT/.github/workflows/release.yml"

printf 'workflow tests ok\n'
