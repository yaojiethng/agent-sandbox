#!/usr/bin/env bash
# Tests for the active-tracker skill's tool, active-tracker.mjs.
#
# The tree is an edge list, so the tests feed it edges and read the derived
# path and frontier. The frame model is a domain model the tool does not store;
# a test that feeds a sequence of divergences and returns is a case for the
# tool's idempotence, which the repeated-push case holds.
#
# Covers:
#   push    --  a node lands, the pointer moves, a repeat is a no-op
#   pop     --  a subtree drops and the pointer falls to the parent
#   view    --  the tree and the path render into the tracker file
#   refuse  --  an unknown state, a missing store and a missing section

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AT="$REPO_ROOT_DIR/src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs"

write_store() {
  local d="$1"
  cat > "$d/TRACKER.json" <<'JSON'
{
  "current": "B",
  "nodes": [
    { "id": "root", "parent": null, "label": "the work", "state": "[ ]" },
    { "id": "A", "parent": "root", "label": "the first branch", "state": "[ ]" },
    { "id": "B", "parent": "root", "label": "the second branch", "state": "[ ]" },
    { "id": "B1", "parent": "B", "label": "a child", "state": "[~]" }
  ]
}
JSON
  cat > "$d/TRACKER.md" <<'MD'
# ACTIVE_TASK_TRACKER

**Resume here.** Current node: **B**, the second branch.

## The work tree

```text
placeholder
```

## The stack

```text
placeholder
```

## The workspace note

Workspace HEAD at last write: `0000000`.
MD
}

run_at() {
  local d="$1"
  shift
  node "$AT" "$@" --store "$d/TRACKER.json" --tracker "$d/TRACKER.md"
}

test_push_lands_a_node_and_moves_the_pointer() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(run_at "$d" push B2 B --label "a new child" 2>&1)"
  assert_contains "$out" "pushed B2 under B, pointer -> B2" "the pointer follows the push"
  assert_contains "$(run_at "$d" view 2>&1)" "B2. a new child" "the node renders"
}

test_push_is_idempotent() {
  local d count
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push B2 B --label "a new child" >/dev/null
  run_at "$d" push B2 B --label "a new child" >/dev/null
  run_at "$d" push B2 B --label "a new child" >/dev/null
  count="$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");console.log(JSON.parse(s).nodes.length)' "$d/TRACKER.json")"
  assert_eq "$count" "5" "a repeated push adds one node, not three"
}

test_push_stay_keeps_the_pointer() {
  local d
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push B2 B --label "a new child" --stay >/dev/null
  assert_contains "$(cat "$d/TRACKER.md")" "Current node: **B**" "the pointer stays put with --stay"
}

test_pop_drops_the_subtree() {
  local d out t
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(run_at "$d" pop B 2>&1)"
  assert_contains "$out" "popped B and 1 descendant(s)" "the subtree is counted"
  assert_contains "$out" "pointer -> root" "the pointer falls to the parent"
  t="$(cat "$d/TRACKER.md")"
  assert_not_contains "$t" "B1." "the child is gone from the render"
}

test_pop_is_idempotent() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(run_at "$d" pop absent 2>&1)"
  assert_contains "$out" "not present, nothing changed" "an absent id changes nothing"
}

test_view_renders_the_tree_and_the_path() {
  local d t
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" view >/dev/null
  t="$(cat "$d/TRACKER.md")"
  assert_contains "$t" "root. the work" "the tree renders"
  assert_contains "$t" "path:     root -> B" "the path is derived from the edges"
  assert_contains "$t" "frontier: at root: A" "the frontier is derived from the edges"
  assert_contains "$t" "resume here" "the pointer is marked"
  assert_not_contains "$t" "placeholder" "the owned blocks replace their placeholder"
}

test_unknown_state_refuses() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(run_at "$d" push C root --state "[x]" 2>&1)"
  assert_contains "$out" "state must be one of" "a resolved state is not in the vocabulary"
}

test_missing_store_refuses() {
  local d out
  d="$(get_fixture_dir)"
  out="$(node "$AT" view --store "$d/absent.json" --tracker "$d/absent.md" 2>&1)"
  assert_contains "$out" "no store at" "a missing store refuses"
}

test_missing_section_refuses() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  printf '# ACTIVE_TASK_TRACKER\n' > "$d/TRACKER.md"
  out="$(run_at "$d" view 2>&1)"
  assert_contains "$out" "no \"## The work tree\" section" "a missing region refuses rather than half-writing"
}

run_test test_push_lands_a_node_and_moves_the_pointer
run_test test_push_is_idempotent
run_test test_push_stay_keeps_the_pointer
run_test test_pop_drops_the_subtree
run_test test_pop_is_idempotent
run_test test_view_renders_the_tree_and_the_path
run_test test_unknown_state_refuses
run_test test_missing_store_refuses
run_test test_missing_section_refuses

test_done
