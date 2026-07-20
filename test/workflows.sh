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
  automatic = triggers["workflow_run"]
  abort "release must follow buildpack tests" unless automatic["workflows"] == ["Buildpack tests"]
  abort "release must wait for completed tests" unless automatic["types"] == ["completed"]
  abort "release main filter is missing" unless automatic["branches"] == ["main"]
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
  condition = publish.fetch("if")
  abort "automatic release must require successful tests" unless condition.include?("github.event.workflow_run.conclusion") && condition.include?("success")
  abort "automatic release must only follow pushes" unless condition.include?("github.event.workflow_run.event") && condition.include?("push")
  abort "manual release must require its tests" unless condition.include?("needs.unit.result") && condition.include?("needs.integration.result")

  steps = publish.fetch("steps")
  version_step = steps.find { |step| step["id"] == "version" }
  abort "release must calculate a version" unless version_step
  abort "automatic releases must increment patch" unless version_step.dig("env", "INCREMENT").include?("patch")
  create_step = steps.find { |step| step["name"] == "Create release" }
  abort "release must use the calculated version" unless create_step.dig("env", "RELEASE_TAG") == "${{ steps.version.outputs.tag }}"
  abort "release must target the tested commit" unless create_step.dig("env", "RELEASE_SHA") == "${{ github.event.workflow_run.head_sha || github.sha }}"
' "$ROOT/.github/workflows/smoke.yml" "$ROOT/.github/workflows/release.yml"

printf 'workflow tests ok\n'
