#!/usr/bin/env bash
# Tests for the active-tracker skill's tool, active-tracker.mjs.
#
# The tree is an edge list, so the tests feed it edges and read the derived path
# and frontier.
#
# The frame model frames the cases. A frame is one divergence: the operator forks
# at a node, works a task, and returns. The tracker does not store a frame, so
# the cases derive their transitions from it:
#
#   frame    fork at   work   return to
#   outer    B         T      B
#   nested   T         U      T
#
# Each row derives a push and pop pair. `push <work> <fork-at>` moves the pointer
# into the divergence, and `pop <work>` returns it to the fork point. The pair is
# one frame's transition, and the log carries both legs, so a frame whose pop
# was missed is visible as a push with no matching pop.
#
# Covers:
#   push    --  a node lands, the pointer moves, a repeat is a no-op, the state is an enum
#   pop     --  one id or many prune their subtrees and the pointer falls to the parent
#   view    --  the tree, the path and the frontier render with the enum values
#   log     --  push and pop each append one event, and the log is append-only
#   library --  the module drives the same operations with no CLI
#   frame   --  a stated frame transition derives its push and pop pair, and an
#               open frame is visible in the log when its pop was missed
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
    { "id": "root", "parent": null, "label": "the work", "state": "open" },
    { "id": "A", "parent": "root", "label": "the first branch", "state": "open" },
    { "id": "B", "parent": "root", "label": "the second branch", "state": "open" },
    { "id": "B1", "parent": "B", "label": "a child", "state": "later" }
  ]
}
JSON
  cat > "$d/TRACKER.md" <<'MD'
# ACTIVE_TASK_TRACKER

**Resume here.** Current node: **B**, the second branch.

## The work tree

stale legend

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
  assert_contains "$out" "pushed B2; pointer -> B2" "the pointer follows the push"
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

test_push_state_is_an_enum() {
  local d out state
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push B2 B --state later >/dev/null
  state="$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");console.log(JSON.parse(s).nodes.find(n=>n.id==="B2").state)' "$d/TRACKER.json")"
  assert_eq "$state" "later" "the store holds the enum value, not a symbol"
  assert_contains "$(run_at "$d" view 2>&1)" "later" "the enum value renders directly"
  out="$(run_at "$d" push C root --state suspended 2>&1)"
  assert_contains "$out" "state must be one of open later elsewhere" "a value outside the enum refuses"
}

test_push_keeps_an_existing_state() {
  local d state
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push B1 B --label "renamed" >/dev/null
  state="$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");console.log(JSON.parse(s).nodes.find(n=>n.id==="B1").state)' "$d/TRACKER.json")"
  assert_eq "$state" "later" "a push with no --state keeps the state"
}

test_pop_prunes_a_subtree() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(run_at "$d" pop B 2>&1)"
  assert_contains "$out" "popped B, B1" "the subtree is named"
  assert_contains "$out" "pointer -> root" "the pointer falls to the parent"
  assert_not_contains "$(run_at "$d" view 2>&1)" "B1." "the child is gone from the render"
}

test_pop_prunes_many_at_once() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(run_at "$d" pop A B 2>&1)"
  assert_contains "$out" "popped A, B, B1" "a bulk pop prunes every named subtree in one call"
}

test_pop_is_idempotent() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(run_at "$d" pop absent 2>&1)"
  assert_contains "$out" "nothing present, nothing changed" "an absent id changes nothing"
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
  assert_contains "$t" "<- here" "the pointer is marked"
  assert_contains "$t" "A node is \`open\`" "the legend is rendered, not cross-referenced"
  assert_not_contains "$t" "stale legend" "the legend replaces the prose it owns"
  assert_not_contains "$t" "placeholder" "the owned blocks replace their placeholder"
}

test_log_records_every_change() {
  local d t
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push B2 B >/dev/null
  run_at "$d" pop B2 >/dev/null
  assert_contains "$(run_at "$d" log 2>&1)" '"op":"push"' "the log records a push"
  assert_contains "$(run_at "$d" log 2>&1)" '"op":"pop"' "the log records a pop"
  assert_contains "$(run_at "$d" log --since 1 2>&1)" '"n":2' "a since bound trims the log"
  t="$(wc -l < "$d/ACTIVE_TASK_TRACKER_LOG.jsonl")"
  assert_eq "$t" "2" "one line per change, and re-reading appends nothing"
}

test_library_drives_the_same_operations() {
  local d out
  d="$(get_fixture_dir)"
  write_store "$d"
  out="$(node --input-type=module -e "
    import { push, pop, view } from 'file://$AT';
    const opts = { store: '$d/TRACKER.json', tracker: '$d/TRACKER.md' };
    push({ ...opts, id: 'C', parent: 'root', label: 'via the library' });
    pop({ ...opts, ids: ['A'] });
    console.log(view({ store: opts.store }).join('|'));
  " 2>&1)"
  assert_contains "$out" "C. via the library" "the library pushes"
  assert_not_contains "$out" "A. the first branch" "the library prunes"
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

# The outer frame: push T under B enters the divergence, and pop T returns the
# pointer to B, the fork point. The two legs are one frame's transition.
test_a_frame_transition_restores_the_pointer() {
  local d log
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push T B --label "the divergence's task" >/dev/null
  assert_contains "$(run_at "$d" pop T 2>&1)" "pointer -> B" "the frame's return node is its fork point"
  log="$(run_at "$d" log 2>&1)"
  assert_contains "$log" '"op":"push","id":"T"' "the log records the fork leg"
  assert_contains "$log" '"op":"pop","id":"T"' "the log records the return leg"
}

# The nested frame: the fork point is itself inside the outer frame, so the
# inner pair unwinds first and the outer return then reaches B.
test_a_nested_frame_unwinds_in_order() {
  local d
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push T B >/dev/null
  run_at "$d" push U T >/dev/null
  run_at "$d" pop U >/dev/null
  assert_contains "$(run_at "$d" pop T 2>&1)" "pointer -> B" "the outer return reaches the fork point after the inner one"
  assert_not_contains "$(run_at "$d" view 2>&1)" "T." "a returned frame's task is pruned"
}

# A frame whose pop was missed leaves a push with no matching pop. The store
# cannot show that; the log can, which is what the log is for.
test_the_log_reconciles_a_missed_pop() {
  local d open
  d="$(get_fixture_dir)"
  write_store "$d"
  run_at "$d" push T B >/dev/null
  open="$(node -e '
    const fs = require("fs");
    const events = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map(JSON.parse);
    const open = new Set();
    for (const e of events) {
      if (e.op === "push") open.add(e.id);
      if (e.op === "pop") open.delete(e.id);
    }
    console.log([...open].join(",") || "none");
  ' "$d/ACTIVE_TASK_TRACKER_LOG.jsonl")"
  assert_eq "$open" "T" "the log names the frame whose pop was missed"
}

run_test test_push_lands_a_node_and_moves_the_pointer
run_test test_push_is_idempotent
run_test test_push_state_is_an_enum
run_test test_push_keeps_an_existing_state
run_test test_pop_prunes_a_subtree
run_test test_pop_prunes_many_at_once
run_test test_pop_is_idempotent
run_test test_view_renders_the_tree_and_the_path
run_test test_log_records_every_change
run_test test_library_drives_the_same_operations
run_test test_missing_store_refuses
run_test test_missing_section_refuses
run_test test_a_frame_transition_restores_the_pointer
run_test test_a_nested_frame_unwinds_in_order
run_test test_the_log_reconciles_a_missed_pop

test_done
