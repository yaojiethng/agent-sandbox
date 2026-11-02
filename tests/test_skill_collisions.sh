#!/usr/bin/env bash
# tests/test_skill_collisions.sh
# The skill-name collision report: a name a package the project added holds is
# reported when it meets a copy we ship, in the set the session actually loads.
# A name held twice by our own copies is our seeding, not a collision, and a
# session with no collision prints nothing.
#
# Covers:
#   added package -- a package holding a shipped name reports both loaded paths
#   ours twice    -- the image payload configured as a package is not an addition
#   not loaded    -- the repository's committed copy is not a participant
#   no collision  -- a package holding no shipped name prints nothing
#   no packages   -- a session with no configured package prints nothing
#   exit          -- the report exits 0 with and without a collision

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$REPO_ROOT/scripts/skill_collisions.mjs"
LAYERS="$REPO_ROOT/scripts/skill_layers.mjs"

# provider_source ROOT -- the provider layer's committed source directory.
provider_source() {
  local root="$1" source
  source="$(node "$LAYERS" --list | awk -F'\t' '$1 == "provider" { print $2 }')"
  printf '%s\n' "$root/$source"
}

# write_skill DIR NAME -- one skill, so pi's loader discovers it.
write_skill() {
  mkdir -p "$1/$2"
  printf -- '---\nname: %s\ndescription: fixture skill\n---\n\nFixture.\n' "$2" >"$1/$2/SKILL.md"
}

# fixture_root -- a project with a manifest that declares where the provider
# payload lands, a seeded home, and a directory for a package the project adds.
# Prints "root<TAB>agentdir<TAB>package<TAB>image".
fixture_root() {
  local base root agentdir pkg image
  base="$(mktemp -d)"
  root="$base/project"
  agentdir="$base/home/agent"
  pkg="$base/pkg"
  image="$base/image/agent/skills"
  mkdir -p "$root/src/build" "$agentdir/skills" "$image"
  write_skill "$(provider_source "$root")" probe
  write_skill "$image" probe
  cp "$(provider_source "$root")/probe/SKILL.md" "$image/probe/SKILL.md"
  write_skill "$agentdir/skills" probe
  cat >"$root/src/build/container-interface.json" <<EOF
{
  "image": [{"provider": "pi", "source": "src/reasoning/providers/pi/config/", "destination": "$base/image/"}],
  "env": [{"provider": "pi", "name": "AGENT_HOME", "value": "$base/home"}],
  "provision": [{"provider": "pi", "source": "src/reasoning/providers/pi/config/", "template": "$base/image/", "home": "\$AGENT_HOME/"}]
}
EOF
  printf '%s\t%s\t%s\t%s\n' "$root" "$agentdir" "$pkg" "$base/image/agent/skills"
}

# configure_package AGENTDIR PACKAGE -- the settings file pi reads for user packages.
configure_package() {
  printf '{"packages":["%s"]}\n' "$2" >"$1/settings.json"
}

test_a_package_holding_a_shipped_name_is_reported() {
  local root agentdir pkg image out rc
  IFS=$'\t' read -r root agentdir pkg image < <(fixture_root)
  write_skill "$pkg/skills" probe
  configure_package "$agentdir" "$pkg"
  out="$(node "$REPORT" --root "$root" --agent-dir "$agentdir" 2>&1)"
  rc=$?
  assert_eq "$rc" 0 "the report fails nothing"
  assert_contains "$out" "skill collision: 'probe'" "the collision names the skill"
  assert_contains "$out" "$agentdir/skills/probe/SKILL.md" "the collision names the loaded shipped path"
  assert_contains "$out" "$pkg/skills/probe/SKILL.md" "the collision names the added path"
}

test_the_image_payload_is_ours_twice_not_an_addition() {
  local root agentdir pkg image out
  IFS=$'\t' read -r root agentdir pkg image < <(fixture_root)
  configure_package "$agentdir" "$image"
  out="$(node "$REPORT" --root "$root" --agent-dir "$agentdir" 2>&1)"
  assert_empty "$out" "the same payload loaded twice is our seeding, not a collision"
}

test_the_committed_copy_is_not_a_participant() {
  local root agentdir pkg image out
  IFS=$'\t' read -r root agentdir pkg image < <(fixture_root)
  write_skill "$pkg/skills" probe
  configure_package "$agentdir" "$pkg"
  out="$(node "$REPORT" --root "$root" --agent-dir "$agentdir" --json 2>&1)"
  assert_not_contains "$out" "$(provider_source "$root")" "the committed source is not in the load set and is not reported"
}

test_a_package_with_no_shipped_name_reports_nothing() {
  local root agentdir pkg image out
  IFS=$'\t' read -r root agentdir pkg image < <(fixture_root)
  write_skill "$pkg/skills" other-skill
  configure_package "$agentdir" "$pkg"
  out="$(node "$REPORT" --root "$root" --agent-dir "$agentdir" 2>&1)"
  assert_empty "$out" "a clean session prints nothing"
}

test_a_session_with_no_package_reports_nothing() {
  local root agentdir pkg image out
  IFS=$'\t' read -r root agentdir pkg image < <(fixture_root)
  out="$(node "$REPORT" --root "$root" --agent-dir "$agentdir" 2>&1)"
  assert_empty "$out" "no configured package means nothing to report"
}

run_test test_a_package_holding_a_shipped_name_is_reported
run_test test_the_image_payload_is_ours_twice_not_an_addition
run_test test_the_committed_copy_is_not_a_participant
run_test test_a_package_with_no_shipped_name_reports_nothing
run_test test_a_session_with_no_package_reports_nothing

test_done
