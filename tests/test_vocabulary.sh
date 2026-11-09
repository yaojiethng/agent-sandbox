#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_vocabulary.sh
# Behavioural tests for scripts/check_vocabulary.sh -- the gate that holds the
# shipping instruction surfaces to the reserved vocabulary.
#
#   a conforming tree                              --  rc 0
#   a replaced sense of 'layer' in a surface       --  rc 1; the file is named
#   the container-architecture sense of 'layer'    --  rc 0 (not a finding)
#   a surface the manifest declares but is absent  --  rc 1; the source is named
#   a manifest with no instruction-surface source  --  rc 1 (fails closed)
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with VOCABULARY_SCAN_ROOT, so the repository's own surfaces
# are never the subject.
#
# Run:   bash tests/test_vocabulary.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_vocabulary.sh"
MANIFEST_REL="src/build/container-interface.json"

# write_manifest ROOT  --  two instruction-surface rows: the shipped docs and a
# module prompt root.
write_manifest() {
  local root="$1"
  local path="$root/$MANIFEST_REL"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
{
  "image": [
    { "provider": "pi", "source": "docs/reference/", "destination": "/opt/sandbox/docs/reference/" },
    { "provider": "pi", "source": "workflow/coding-agent/prompts/", "destination": "/opt/workflow/agent/modules/coding-agent/prompts/" }
  ]
}
EOF
}

# write_surfaces ROOT  --  conforming surface files, one under each manifest
# row.
write_surfaces() {
  local root="$1"
  mkdir -p "$root/docs/reference" "$root/workflow/coding-agent/prompts"
  cat > "$root/docs/reference/overview.md" <<'EOF'
The capability layer runs the diff pipeline; the reasoning layer runs the agent.
EOF
  cat > "$root/workflow/coding-agent/prompts/iter.md" <<'EOF'
Read the roadmap and open a handover.
EOF
}

write_conforming_tree() {
  local root="$1"
  write_manifest "$root"
  write_surfaces "$root"
}

GATE_RC=0
GATE_OUT=""
run_gate() {
  GATE_RC=0
  GATE_OUT=$(VOCABULARY_SCAN_ROOT="$1" bash "$GATE" 2>&1) || GATE_RC=$?
}

test_conforming_tree_passes() {
  local root="$FIXTURE_DIR/conforming"
  write_conforming_tree "$root"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a conforming tree passes'
  assert_contains "$GATE_OUT" 'clean across 2 instruction-surface source(s)' 'the sources are counted'
}

test_disallowed_sense_flagged() {
  local root="$FIXTURE_DIR/sense"
  write_conforming_tree "$root"
  printf '\nThe provider layer loads first.\n' >> "$root/docs/reference/overview.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a replaced sense of layer fails'
  assert_contains "$GATE_OUT" 'overview.md' 'the offending file is named'
}

test_container_architecture_sense_allowed() {
  local root="$FIXTURE_DIR/allowed"
  write_conforming_tree "$root"
  printf '\nThe capability layer starts first and owns the sandbox volume.\n' >> "$root/docs/reference/overview.md"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'the container-architecture sense is not a finding'
}

test_missing_surface_flagged() {
  local root="$FIXTURE_DIR/missing"
  write_conforming_tree "$root"
  rm -rf "$root/workflow/coding-agent/prompts"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a declared but absent surface fails'
  assert_contains "$GATE_OUT" 'declares this surface, but it is missing' 'the source is named'
}

test_manifest_with_no_source_fails_closed() {
  local root="$FIXTURE_DIR/nosource"
  write_conforming_tree "$root"
  printf '{ "image": [] }\n' > "$root/$MANIFEST_REL"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a manifest with no instruction-surface source fails closed'
  assert_contains "$GATE_OUT" 'declares no instruction-surface source' 'the empty declaration is named'
}

run_test test_conforming_tree_passes
run_test test_disallowed_sense_flagged
run_test test_container_architecture_sense_allowed
run_test test_missing_surface_flagged
run_test test_manifest_with_no_source_fails_closed

test_done
