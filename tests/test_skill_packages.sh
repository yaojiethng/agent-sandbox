#!/usr/bin/env bash
# tests/test_skill_packages.sh
# The package manifest and its drift report: the gate reads the manifest alone,
# and the report names a package the manifest holds that is not configured and a
# configured package the manifest does not name.
#
# Covers:
#   gate clean     -- a well-formed manifest passes
#   gate missing   -- a tree with no manifest fails
#   gate shape     -- an entry with no source, no reason, a bad scope or a repeat fails
#   gate empty     -- a manifest naming no package fails
#   drift missing  -- a manifest entry that is not configured is reported
#   drift unlisted -- a configured package no entry names is reported
#   drift clean    -- a manifest that matches the configuration reports nothing

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$REPO_ROOT/scripts/skill_packages.mjs"
GATE="$REPO_ROOT/scripts/check_skill_packages.sh"

# fixture_root -- a root with the manifest directory and a package directory.
fixture_root() {
  local base
  base="$(mktemp -d)"
  mkdir -p "$base/.agents/registry" "$base/pkg/skills/probe" "$base/home"
  printf -- '---\nname: probe\ndescription: fixture\n---\n\nFixture.\n' >"$base/pkg/skills/probe/SKILL.md"
  printf '%s\n' "$base"
}

# write_manifest ROOT JSON -- the manifest under test.
write_manifest() {
  printf '%s\n' "$2" >"$1/.agents/registry/packages.json"
}

test_a_well_formed_manifest_passes() {
  local root out
  root="$(fixture_root)"
  write_manifest "$root" '{"packages":[{"source":"/opt/x","scope":"user","why":"a payload"}]}'
  out="$(SKILL_PACKAGES_SCAN_ROOT="$root" bash "$GATE" 2>&1)"
  assert_contains "$out" "skill packages: clean" "a well-formed manifest passes"
}

test_a_tree_with_no_manifest_fails() {
  local root out rc
  root="$(mktemp -d)"
  out="$(SKILL_PACKAGES_SCAN_ROOT="$root" bash "$GATE" 2>&1)"
  rc=$?
  assert_eq "$rc" 1 "a missing manifest is a finding"
  assert_contains "$out" "missing" "the finding names the manifest"
}

test_a_malformed_entry_fails() {
  local root out
  root="$(fixture_root)"
  write_manifest "$root" '{"packages":[{"scope":"user","why":"no source"},{"source":"/opt/y","scope":"everywhere","why":"bad scope"},{"source":"/opt/z","scope":"user"},{"source":"/opt/w","scope":"user","why":"a"},{"source":"/opt/w","scope":"user","why":"b"}]}'
  out="$(SKILL_PACKAGES_SCAN_ROOT="$root" bash "$GATE" 2>&1)"
  assert_contains "$out" "needs a 'source'" "an entry with no source is a finding"
  assert_contains "$out" "'scope' must be user or project" "an unknown scope is a finding"
  assert_contains "$out" "needs a 'why'" "an entry with no reason is a finding"
  assert_contains "$out" "named twice" "a repeated source is a finding"
}

test_a_manifest_naming_nothing_fails() {
  local root out
  root="$(fixture_root)"
  write_manifest "$root" '{"packages":[]}'
  out="$(SKILL_PACKAGES_SCAN_ROOT="$root" bash "$GATE" 2>&1)"
  assert_contains "$out" "names no package" "an empty manifest is a finding"
}

test_a_manifest_entry_that_is_not_configured_is_reported() {
  local root out
  root="$(fixture_root)"
  write_manifest "$root" '{"packages":[{"source":"/opt/absent","scope":"user","why":"a payload"}]}'
  out="$(node "$REPORT" --root "$root" --agent-dir "$root/home" 2>&1)"
  assert_contains "$out" "package missing: '/opt/absent'" "a named package that is not configured is reported"
}

test_a_configured_package_the_manifest_omits_is_reported() {
  local root out
  root="$(fixture_root)"
  write_manifest "$root" '{"packages":[]}'
  printf '{"packages":["%s/pkg"]}\n' "$root" >"$root/home/settings.json"
  out="$(node "$REPORT" --root "$root" --agent-dir "$root/home" 2>&1)"
  assert_contains "$out" "package unlisted: '$root/pkg'" "a configured package no entry names is reported"
}

test_a_manifest_that_matches_reports_nothing() {
  local root out
  root="$(fixture_root)"
  write_manifest "$root" "{\"packages\":[{\"source\":\"$root/pkg\",\"scope\":\"user\",\"why\":\"a payload\"}]}"
  printf '{"packages":["%s/pkg"]}\n' "$root" >"$root/home/settings.json"
  out="$(node "$REPORT" --root "$root" --agent-dir "$root/home" 2>&1)"
  assert_empty "$out" "a manifest that matches the configuration reports nothing"
}

run_test test_a_well_formed_manifest_passes
run_test test_a_tree_with_no_manifest_fails
run_test test_a_malformed_entry_fails
run_test test_a_manifest_naming_nothing_fails
run_test test_a_manifest_entry_that_is_not_configured_is_reported
run_test test_a_configured_package_the_manifest_omits_is_reported
run_test test_a_manifest_that_matches_reports_nothing

test_done
