#!/usr/bin/env bash
# tests/test_references.sh
# TEST_DEADLINE: 30
# Behavioural tests for `scripts/lint/references.mjs`, the two reference rules
# over the files the manifest declares: a skill invocation names a skill the
# tree provides, and an absolute mention inside a declared zone names a declared
# root.
#
# Each case adds one file to a fixture tree and runs the scanner. The clean case
# is asserted first, because a scanner that reports nothing on every fixture
# would pass each rejecting case by accident.
#
# Covers:
#   clean        --  a document with no reference is clean
#   absent skill --  "`name` skill" naming a skill no SKILL.md provides is named
#   present skill--  the same form naming a skill the tree carries is clean
#   undeclared   --  an /opt path under no declared root is named
#   ancestor     --  a path that is an ancestor of a declared root is clean
#   home         --  a $AGENT_HOME path is clean, both the variable and its value
#   outside zone --  /dev/null and an API endpoint are not the rule's subject
#   command      --  a one-segment token such as `/iter` is a command, not a path
#   fenced       --  a finding inside a fenced block is not reported
#   project skill--  a skill only the working tree carries counts as provided

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_references.sh"
SCANNER="$REPO_ROOT/scripts/lint/references.mjs"

fixture() {
  local name="$1"
  local dir="$FIXTURE_DIR/$name"
  mkdir -p "$dir/src/build"
  cat > "$dir/src/build/container-interface.json" <<'EOF'
{
  "note": "fixture",
  "image": [{ "provider": "pi", "source": "src/libs/", "destination": "/opt/sandbox/lib/" }],
  "provision": [{ "provider": "pi", "source": "src/config/", "template": "/opt/workflow/agent/config/", "home": "$AGENT_HOME/" }],
  "mounts": [{ "provider": "pi", "source": "/host/skills", "target": "/home/agentuser/.pi/agent/skills" }],
  "env": [{ "provider": "pi", "name": "AGENT_HOME", "value": "/home/agentuser/.pi" }],
  "session": [{ "path": "/home/agentuser/sandbox/", "holds": "the project tree" }],
  "cells": [
    { "sources": ["src/reasoning/agent/skills/"], "runtime_path": "/opt/workflow/agent/skills/", "loader": "a skill root" }
  ]
}
EOF
  mkdir -p "$dir/src/reasoning/agent/skills/present"
  printf -- '---\nname: present\ndescription: "d"\n---\n\n# Present\n' > "$dir/src/reasoning/agent/skills/present/SKILL.md"
  printf '%s' "$dir"
}

scan() {
  local dir="$WORK"
  set +e
  SCAN_OUT="$(node "$SCANNER" --root "$dir" 2>&1)"
  SCAN_RC=$?
  set -e
}

test_a_document_with_no_reference_is_clean() {
  local dir; dir="$(fixture clean)"
  printf '# Doc\n\nNothing here.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'no reference is clean'
  assert_contains "$SCAN_OUT" 'references: clean' 'the clean line is printed'
}

test_an_absent_skill_is_named() {
  local dir; dir="$(fixture absent_skill)"
  printf '# Doc\n\nRead the `absent-one` skill before you start.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 1 "$SCAN_RC" 'a skill the tree lacks fails'
  assert_contains "$SCAN_OUT" 'names `absent-one` as a skill' 'the name is reported'
  assert_contains "$SCAN_OUT" 'src/reasoning/agent/skills/notes.md:3' 'the file and line are reported'
}

test_a_present_skill_is_clean() {
  local dir; dir="$(fixture present_skill)"
  printf '# Doc\n\nThe `present` skill holds the rule.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'a skill the tree carries is clean'
}

test_a_project_scope_skill_counts_as_provided() {
  local dir; dir="$(fixture project_skill)"
  mkdir -p "$dir/.agents/skills/project-only"
  printf -- '---\nname: project-only\ndescription: "d"\n---\n\n# Project\n' \
    > "$dir/.agents/skills/project-only/SKILL.md"
  printf '# Doc\n\nThe `project-only` skill loads from the working tree.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'a skill no cell declares still counts as provided'
}

test_an_undeclared_root_inside_a_zone_is_named() {
  local dir; dir="$(fixture undeclared)"
  printf '# Doc\n\nSee `/opt/workflow/agent/typo/` for the root.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 1 "$SCAN_RC" 'a path under no declared root fails'
  assert_contains "$SCAN_OUT" "names '/opt/workflow/agent/typo/'" 'the token is reported'
  assert_contains "$SCAN_OUT" 'under no root it names' 'the reason is reported'
}

test_an_ancestor_of_a_declared_root_is_clean() {
  local dir; dir="$(fixture ancestor)"
  printf '# Doc\n\nThe libraries live under `/opt/sandbox/`.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'an ancestor of a root is a legal mention'
}

test_the_agent_home_passes_in_both_forms() {
  local dir; dir="$(fixture home)"
  printf '# Doc\n\n`$AGENT_HOME/agent/skills/present/SKILL.md` and `/home/agentuser/.pi/agent/skills/` both.\n' \
    > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'the variable and its value both name a declared root'
}

test_a_path_outside_every_zone_is_not_the_subject() {
  local dir; dir="$(fixture outside_zone)"
  printf '# Doc\n\nSilence it with `/dev/null`, and the endpoint is `/v1/models`.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'a device and an endpoint are not zones the image builds'
}

test_a_one_segment_token_is_a_command() {
  local dir; dir="$(fixture command)"
  printf '# Doc\n\nRun `/iter` to start.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'a command name is not a path'
}

test_a_fenced_block_is_skipped() {
  local dir; dir="$(fixture fenced)"
  cat > "$dir/src/reasoning/agent/skills/notes.md" <<'EOF'
# Doc

```text
Read the `absent-one` skill.
See `/opt/workflow/agent/typo/`.
```
EOF
  WORK="$dir"; scan
  assert_rc 0 "$SCAN_RC" 'a quoted block makes no reference'
}

test_the_gate_wraps_the_scanner() {
  local dir; dir="$(fixture gate)"
  printf '# Doc\n\nRead the `absent-one` skill.\n' > "$dir/src/reasoning/agent/skills/notes.md"
  set +e
  GATE_OUT="$(bash "$GATE" --root "$dir" 2>&1)"
  GATE_RC=$?
  set -e
  assert_rc 1 "$GATE_RC" 'the gate fails on the scanner finding'
  assert_contains "$GATE_OUT" 'Blocking gate' 'the gate states the blocking line'
}

run_test test_a_document_with_no_reference_is_clean
run_test test_an_absent_skill_is_named
run_test test_a_present_skill_is_clean
run_test test_a_project_scope_skill_counts_as_provided
run_test test_an_undeclared_root_inside_a_zone_is_named
run_test test_an_ancestor_of_a_declared_root_is_clean
run_test test_the_agent_home_passes_in_both_forms
run_test test_a_path_outside_every_zone_is_not_the_subject
run_test test_a_one_segment_token_is_a_command
run_test test_a_fenced_block_is_skipped
run_test test_the_gate_wraps_the_scanner

test_done
