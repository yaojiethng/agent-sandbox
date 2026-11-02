#!/usr/bin/env bash
# tests/test_skill_collisions.sh
# The skill-name collision report: a shipped name an added package also holds is
# named with both paths, the declared image copy of a shipped payload is not a
# collision, and a session with no collision prints nothing.
#
# Covers:
#   added package -- a package holding a shipped name reports both paths and the name
#   image copy     -- the declared image copy of the same payload reports nothing
#   no collision   -- a package holding no shipped name prints nothing
#   no packages    -- a session with no configured package prints nothing
#   exit           -- the report exits 0 with and without a collision

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$REPO_ROOT/scripts/skill_collisions.mjs"
LAYERS="$REPO_ROOT/scripts/skill_layers.mjs"

# shipped_dir ROOT -- the provider layer's source directory under a fixture root.
shipped_dir() {
  local root="$1" source
  source="$(node "$LAYERS" --list | awk -F'\t' '$1 == "provider" { print $2 }')"
  printf '%s\n' "$root/$source"
}

# write_skill DIR NAME -- one skill, so pi's loader discovers it.
write_skill() {
  mkdir -p "$1/$2"
  printf -- '---\nname: %s\ndescription: fixture skill\n---\n\nFixture.\n' "$2" >"$1/$2/SKILL.md"
}

# fixture_root -- a tree with one shipped skill, a manifest that declares its
# image destination, and an agent home. Prints "root<TAB>home<TAB>package".
fixture_root() {
  local base root home pkg
  base="$(mktemp -d)"
  root="$base/project"
  home="$base/home"
  pkg="$base/pkg"
  mkdir -p "$root/src/build" "$home"
  write_skill "$(shipped_dir "$root")" probe
  cat >"$root/src/build/container-interface.json" <<EOF
{"image":[{"provider":"pi","source":"src/reasoning/providers/pi/config/","destination":"$base/image/"}],"env":[],"provision":[]}
EOF
  printf '%s\t%s\t%s\n' "$root" "$home" "$pkg"
}

# configure_package HOME PACKAGE -- the settings file pi reads for user packages.
configure_package() {
  printf '{"packages":["%s"]}\n' "$2" >"$1/settings.json"
}

test_an_added_package_holding_a_shipped_name_is_reported() {
  local root home pkg out rc
  IFS=$'\t' read -r root home pkg < <(fixture_root)
  write_skill "$pkg/skills" probe
  configure_package "$home" "$pkg"
  out="$(node "$REPORT" --root "$root" --agent-dir "$home" 2>&1)"
  rc=$?
  assert_eq "$rc" 0 "the report fails nothing"
  assert_contains "$out" "skill collision: 'probe'" "the collision names the skill"
  assert_contains "$out" "$(shipped_dir "$root")/probe/SKILL.md" "the collision names the shipped path"
  assert_contains "$out" "$pkg/skills/probe/SKILL.md" "the collision names the added path"
}

test_the_declared_image_copy_is_not_a_collision() {
  local root home pkg out image
  IFS=$'\t' read -r root home pkg < <(fixture_root)
  image="$(dirname "$root")/image/agent/skills/probe"
  mkdir -p "$image"
  cp "$(shipped_dir "$root")/probe/SKILL.md" "$image/SKILL.md"
  configure_package "$home" "$(dirname "$root")/image"
  out="$(node "$REPORT" --root "$root" --agent-dir "$home" 2>&1)"
  assert_not_contains "$out" "skill collision" "one payload in two declared places is not a collision"
}

test_a_package_with_no_shipped_name_reports_nothing() {
  local root home pkg out
  IFS=$'\t' read -r root home pkg < <(fixture_root)
  write_skill "$pkg/skills" other-skill
  configure_package "$home" "$pkg"
  out="$(node "$REPORT" --root "$root" --agent-dir "$home" 2>&1)"
  assert_empty "$out" "a clean session prints nothing"
}

test_a_session_with_no_package_reports_nothing() {
  local root home pkg out
  IFS=$'\t' read -r root home pkg < <(fixture_root)
  out="$(node "$REPORT" --root "$root" --agent-dir "$home" 2>&1)"
  assert_empty "$out" "no configured package means nothing to report"
}

run_test test_an_added_package_holding_a_shipped_name_is_reported
run_test test_the_declared_image_copy_is_not_a_collision
run_test test_a_package_with_no_shipped_name_reports_nothing
run_test test_a_session_with_no_package_reports_nothing

test_done
