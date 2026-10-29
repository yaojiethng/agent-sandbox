#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_instruction_surfaces.sh
# Behavioural tests for scripts/check_instruction_surfaces.sh -- the gate that
# holds the two AGENTS.md layer tables and the loop inventory to their sources.
#
# The instruction surfaces themselves are declared in
# src/build/container-interface.json and checked against the images by
# scripts/check_container_layout.sh, which tests/test_container_layout.sh
# covers. This file covers the two claims that live outside that manifest: the
# layer split of the `session` rows, and the loop inventory.
#
#   a conforming tree                          --  rc 0
#   a layer path outside the session rows      --  rc 1; the path is named
#   a session row no layer covers              --  rc 1; the row is named
#   a session row two layers cover             --  rc 1; the collision is named
#   a layer with no `## Scope` heading         --  rc 1; the heading is named
#   a section with no subject-table row         --  rc 1; the section is named
#   a subject-table row naming the other layer  --  rc 1; both layers are named
#   a subject-table row no layer carries        --  rc 1; the section is named
#   an inventory omitting a governed prompt    --  rc 1; the prompt is named
#   an inventory row the policy does not govern--  rc 1; the row is named
#   a manifest with no session row             --  rc 1 (fails closed)
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with INSTRUCTION_SURFACE_SCAN_ROOT, so the repository's own
# layers are never the subject.
#
# Run:   bash tests/test_instruction_surfaces.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_instruction_surfaces.sh"
MANIFEST_REL="src/build/container-interface.json"

# write_manifest ROOT  --  the two session rows the layers split. The `cells`
# section is present because a real manifest carries one; this gate does not
# read it.
write_manifest() {
  local root="$1"
  local path="$root/$MANIFEST_REL"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
{
  "session": [
    { "path": "/home/agentuser/sandbox/", "holds": "the project tree" },
    { "path": "/opt/workflow/agent/", "holds": "the agent tree" }
  ],
  "cells": [
    {
      "sources": ["src/reasoning/agent/prompts/"],
      "runtime_path": "/opt/workflow/agent/prompts/",
      "loader": "the running provider's config lists this path as a prompt root"
    }
  ]
}
EOF
}

# write_layers ROOT  --  the two AGENTS.md layers, each with a `## Scope` table
# covering its half of the session rows, plus the loop inventory and the policy
# scope it must match.
write_layers() {
  local root="$1"
  mkdir -p "$root/src/reasoning/providers/pi/config/agent" "$root/docs/reference"
  cat > "$root/src/reasoning/providers/pi/config/agent/AGENTS.md" <<'EOF'
# Provider layer

## Scope

| Path | What is there |
|---|---|
| `/opt/workflow/agent/` | the agent tree |
EOF
  cat > "$root/AGENTS.md" <<'EOF'
# Project layer

## Scope

| Path | What is there |
|---|---|
| `/home/agentuser/sandbox/` | the project tree |

## Iteration Lifecycle

### Loop prompts

| Prompt | Runs from |
|---|---|
| `/iter` | `workflow/coding-agent/prompts/iter.md` |
| `/wrapup` | `workflow/coding-agent/prompts/wrapup.md` |
EOF
  mkdir -p "$root/docs/development"
  cat > "$root/docs/development/instruction-surface-conventions.md" <<'EOF'
# Instruction Surface Conventions

## The layers

**The subject table.**

| Subject | Section | Layer |
|---|---|---|
| the container paths | `Scope` | provider |
| the working tree | `Scope` | project |
| the iteration | `Iteration Lifecycle` | project |
EOF
  cat > "$root/docs/reference/iteration_protocol.md" <<'EOF'
---
description: "Owns the iteration grain."
scope: ["/iter", "/wrapup"]
---

# Iteration Protocol
EOF
}

# write_conforming_tree ROOT  --  the manifest and the two layers, agreeing.
write_conforming_tree() {
  local root="$1"
  write_manifest "$root"
  write_layers "$root"
}

GATE_RC=0
GATE_OUT=""
run_gate() {
  GATE_RC=0
  GATE_OUT=$(INSTRUCTION_SURFACE_SCAN_ROOT="$1" bash "$GATE" 2>&1) || GATE_RC=$?
}

test_conforming_tree_passes() {
  local root="$FIXTURE_DIR/conforming"
  write_conforming_tree "$root"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a conforming tree passes'
  assert_contains "$GATE_OUT" 'clean across 2 session row(s)' 'the session rows are counted'
}

test_layer_path_outside_the_session_rows_flagged() {
  local root="$FIXTURE_DIR/layerextra"
  write_conforming_tree "$root"
  sed -i 's#| `/opt/workflow/agent/` | the agent tree |#| `/opt/workflow/agent/` | the agent tree |\n| `/opt/elsewhere/` | another tree |#' \
    "$root/src/reasoning/providers/pi/config/agent/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a layer path outside the session rows fails'
  assert_contains "$GATE_OUT" 'which is not a session row in the manifest' 'the path is named'
}

test_uncovered_session_row_flagged() {
  local root="$FIXTURE_DIR/uncovered"
  write_conforming_tree "$root"
  sed -i 's#| `/home/agentuser/sandbox/` | the project tree |#| `/home/agentuser/elsewhere/` | the project tree |#' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a session row no layer covers fails'
  assert_contains "$GATE_OUT" 'no layer covers' 'the uncovered row is named'
}

test_session_row_covered_twice_flagged() {
  local root="$FIXTURE_DIR/doublecover"
  write_conforming_tree "$root"
  sed -i 's#| `/home/agentuser/sandbox/` | the project tree |#| `/opt/workflow/agent/` | the agent tree again |#' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a session row two layers cover fails'
  assert_contains "$GATE_OUT" 'more than one layer covers' 'the collision is named'
}

test_layer_without_scope_heading_flagged() {
  local root="$FIXTURE_DIR/noheading"
  write_conforming_tree "$root"
  sed -i 's/^## Scope$/## Not the scope/' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a layer with no Scope heading fails'
  assert_contains "$GATE_OUT" "missing heading '## Scope'" 'the heading is named'
}

test_inventory_omitting_a_scope_prompt_flagged() {
  local root="$FIXTURE_DIR/invomit"
  write_conforming_tree "$root"
  sed -i '/| `\/wrapup` |/d' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an inventory that omits a scope prompt fails'
  assert_contains "$GATE_OUT" "the inventory omits [/wrapup]" 'the omitted prompt is named'
}

test_inventory_row_outside_scope_flagged() {
  local root="$FIXTURE_DIR/invextra"
  write_conforming_tree "$root"
  sed -i 's#| `/wrapup` | `workflow/coding-agent/prompts/wrapup.md` |#| `/wrapup` | `workflow/coding-agent/prompts/wrapup.md` |\n| `/gm` | `workflow/coding-agent/prompts/gm.md` |#' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an inventory row the policy does not govern fails'
  assert_contains "$GATE_OUT" "the inventory names [/gm]" 'the ungoverned row is named'
}

test_section_with_no_subject_row_flagged() {
  local root="$FIXTURE_DIR/nosubjectrow"
  write_conforming_tree "$root"
  printf '\n## A new section\n\nText.\n' >> "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a section with no subject-table row fails'
  assert_contains "$GATE_OUT" "the section 'A new section' has no subject-table row" 'the section is named'
}

test_subject_row_naming_the_other_layer_flagged() {
  local root="$FIXTURE_DIR/wronglayer"
  write_conforming_tree "$root"
  sed -i 's#^| the iteration | `Iteration Lifecycle` | project |#| the iteration | `Iteration Lifecycle` | provider |#' \
    "$root/docs/development/instruction-surface-conventions.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a subject-table row naming the other layer fails'
  assert_contains "$GATE_OUT" "files 'Iteration Lifecycle' under 'provider', but the section is in the project layer" 'both layers are named'
}

test_subject_row_with_no_section_flagged() {
  local root="$FIXTURE_DIR/stalesubjectrow"
  write_conforming_tree "$root"
  sed -i 's#^| the iteration | `Iteration Lifecycle` | project |#| the iteration | `Iteration Lifecycle` | project |\n| a retired section | `Gone` | project |#' \
    "$root/docs/development/instruction-surface-conventions.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a subject-table row with no section fails'
  assert_contains "$GATE_OUT" "the row for 'Gone' names the project layer, which carries no such section" 'the stale row is named'
}

test_manifest_with_no_session_row_fails_closed() {
  local root="$FIXTURE_DIR/nosession"
  write_conforming_tree "$root"
  node -e '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.session = [];
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  ' "$root/$MANIFEST_REL"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a manifest with no session row fails closed'
  assert_contains "$GATE_OUT" 'declares no session row' 'the empty declaration is named'
}

run_test test_conforming_tree_passes
run_test test_layer_path_outside_the_session_rows_flagged
run_test test_uncovered_session_row_flagged
run_test test_session_row_covered_twice_flagged
run_test test_layer_without_scope_heading_flagged
run_test test_section_with_no_subject_row_flagged
run_test test_subject_row_naming_the_other_layer_flagged
run_test test_subject_row_with_no_section_flagged
run_test test_inventory_omitting_a_scope_prompt_flagged
run_test test_inventory_row_outside_scope_flagged
run_test test_manifest_with_no_session_row_fails_closed

test_done
