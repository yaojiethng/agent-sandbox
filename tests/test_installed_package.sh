#!/usr/bin/env bash
# tests/test_installed_package.sh
# The installed package carrier, against pi's own resolver: a bare directory is
# a package, an exact filter disables one skill, a bare-name filter silently
# matches nothing, and an absent path loads nothing.
#
# Covers:
#   bare dir     -- a directory holding skills/ and no package.json is a package
#   exact filter -- a package entry's `-skills/<name>` disables that skill
#   glob filter  -- `!skills/<name>/*` disables it too
#   bare name    -- `-<name>` matches nothing and reports nothing
#   absent path  -- a declaration whose path is gone loads zero skills

set -uo pipefail

# TEST_DEADLINE: 90

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# fixture_root -- a home with a settings file, and a package holding two skills.
fixture_root() {
  local base
  base="$(mktemp -d)"
  mkdir -p "$base/pkg/skills/alpha" "$base/pkg/skills/beta" "$base/home"
  printf -- '---\nname: alpha\ndescription: fixture\n---\n\nAlpha.\n' >"$base/pkg/skills/alpha/SKILL.md"
  printf -- '---\nname: beta\ndescription: fixture\n---\n\nBeta.\n' >"$base/pkg/skills/beta/SKILL.md"
  printf '%s\n' "$base"
}

# resolve ROOT -- pi's resolved skills for ROOT/home, as "total enabled alpha".
resolve() {
  local root="$1"
  cat >"$root/probe.mjs" <<'JS'
const [repo, root] = process.argv.slice(2);
const pi = await import(`${repo}/scripts/skill_layers.mjs`);
const api = await import(`file://${pi.piModuleEntry()}`);
const agentDir = `${root}/home`;
const settings = api.SettingsManager.create(root, agentDir);
const manager = new api.DefaultPackageManager({ cwd: root, agentDir, settingsManager: settings });
const resolved = await manager.resolve(() => {});
const skills = resolved.skills || [];
const alpha = skills.find((entry) => entry.path.includes("/alpha/"));
console.log(`${skills.length} ${skills.filter((entry) => entry.enabled).length} ${alpha ? alpha.enabled : "absent"}`);
JS
  node "$root/probe.mjs" "$REPO_ROOT" "$root"
}

# write_settings ROOT JSON -- the packages entry under test.
write_settings() {
  printf '%s\n' "$2" >"$1/home/settings.json"
}

test_a_bare_directory_is_a_package() {
  local root out
  root="$(fixture_root)"
  write_settings "$root" "{\"packages\":[{\"source\":\"$root/pkg\"}]}"
  out="$(resolve "$root")"
  assert_eq "$out" "2 2 true" "a directory holding skills/ and no package.json is a package"
}

test_an_exact_filter_disables_one_skill() {
  local root out
  root="$(fixture_root)"
  write_settings "$root" "{\"packages\":[{\"source\":\"$root/pkg\",\"skills\":[\"-skills/alpha\"]}]}"
  out="$(resolve "$root")"
  assert_eq "$out" "2 1 false" "an exact path filter disables that skill"
}

test_a_glob_filter_disables_one_skill() {
  local root out
  root="$(fixture_root)"
  write_settings "$root" "{\"packages\":[{\"source\":\"$root/pkg\",\"skills\":[\"!skills/alpha/*\"]}]}"
  out="$(resolve "$root")"
  assert_eq "$out" "2 1 false" "a glob filter rooted at the package disables that skill"
}

test_a_bare_name_filter_matches_nothing() {
  local root out
  root="$(fixture_root)"
  write_settings "$root" "{\"packages\":[{\"source\":\"$root/pkg\",\"skills\":[\"-alpha\"]}]}"
  out="$(resolve "$root")"
  assert_eq "$out" "2 2 true" "a filter without the package-relative path silently matches nothing"
}

test_an_absent_path_loads_nothing() {
  local root out
  root="$(fixture_root)"
  write_settings "$root" "{\"packages\":[{\"source\":\"$root/ghost\"}]}"
  out="$(resolve "$root")"
  assert_eq "$out" "0 0 absent" "a declaration whose path is gone loads zero skills and says nothing"
}

run_test test_a_bare_directory_is_a_package
run_test test_an_exact_filter_disables_one_skill
run_test test_a_glob_filter_disables_one_skill
run_test test_a_bare_name_filter_matches_nothing
run_test test_an_absent_path_loads_nothing

test_done
