#!/usr/bin/env bash
# TEST_DEADLINE: 120
# tests/test_parallel_records.sh
# The concurrency proof: two sessions advance two sub-milestones at once for a
# fixed round count, with no lost update and no record conflict.
#
# The protocol under test is the one the work-log seam confirmed: each session
# writes only its own track's handover, and the shared roadmap has one writer,
# the merge role. Two real writer processes run three rounds each in two
# linked worktrees; the ids come from the track's reserved block through
# scripts/worklog.sh. The negative control proves the assertion can fail: two
# writers on one roadmap row do conflict on merge.
#
# Covers:
#   concurrent writers    -- two sessions, two tracks, three rounds each
#   no lost update        -- every round marker survives the merge
#   no record conflict    -- both branches merge cleanly; one writer applies
#                            both roadmap deltas
#   the negative control  -- two writers on one roadmap row conflict
#
# Run:   bash tests/test_parallel_records.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

TOOL="$REPO_ROOT/scripts/worklog.sh"
DATE=20261106
ROUNDS=3

make_repo() {
  local root="$1"
  mkdir -p "$root/src/build" "$root/devlog/handovers/M9.1" "$root/devlog/handovers/M9.2"
  cp "$REPO_ROOT/src/build/record-layout.json" "$root/src/build/record-layout.json"
  printf 'ids: 20-39\n' > "$root/devlog/handovers/M9.1/README.md"
  printf 'ids: 40-59\n' > "$root/devlog/handovers/M9.2/README.md"
  cat > "$root/devlog/roadmap.md" <<'EOF'
# Fixture Roadmap

- [ ] **M9.1 row** -- fixture session A.
- [ ] **M9.2 row** -- fixture session B.
EOF
  git -C "$root" init -q
  git -C "$root" config user.email test@example.com
  git -C "$root" config user.name Test
  git -C "$root" config commit.gpgsign false
  git -C "$root" config core.hooksPath /dev/null
  git -C "$root" add -A
  git -C "$root" commit -q -m baseline
}

# write_handover PATH TRACK MARKER -- a record carrying a round marker.
write_handover() {
  local path="$1" track="$2" marker="$3"
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'date: %s\n' "$DATE"
    printf 'milestone: %s - Fixture\n' "$track"
    printf 'type: Implementation\n'
    printf 'status: Closed\n'
    printf -- '---\n\n'
    printf '# Handover - %s\n\n' "$marker"
    printf '## Objective\n\nFixture round %s.\n\n' "$marker"
    printf '## Scope\n\nFixture.\n\n'
    printf '## Acceptance criteria\n\nFixture.\n\n'
    printf '## Decisions\n\nNone.\n\n'
    printf '## Decisions pending\n\nNone.\n\n'
    printf '## Findings\n\nNone.\n\n'
    printf '## Completed\n\nNo file changes this iteration.\n'
  } > "$path"
}

# session_write WT TRACK ROW ROUNDS PREFIX -- one session's whole run.
session_write() {
  local wt="$1" track="$2" row="$3" rounds="$4" prefix="$5"
  local i id path waited=0

  # Both sessions are alive before either writes, so "at once" is real.
  : > "$FIXTURE_DIR/live-$prefix"
  while [[ ! -f "$FIXTURE_DIR/live-A" || ! -f "$FIXTURE_DIR/live-B" ]]; do
    sleep 0.01
    waited=$((waited + 1))
    ((waited < 500)) || return 1
  done

  for ((i = 1; i <= rounds; i++)); do
    id="$("$TOOL" reserve-id --root "$wt" --track "$track" --date "$DATE")" || return 1
    path="$wt/devlog/handovers/$track/$id-impl-round$i.md"
    write_handover "$path" "$track" "$prefix-round-$i"
    printf -- '- [x] **%s row** -- %s rounds landed.\n' "$row" "$rounds" \
      > "$wt/devlog/handovers/$track/roadmap-delta.txt"
    git -C "$wt" add -A || return 1
    git -C "$wt" commit -q -m "$prefix round $i" || return 1
  done
}

test_two_sessions_advance_two_submilestones() {
  local root wt_a wt_b pid_a pid_b rc_a rc_b
  local merge_a merge_b count_a count_b dups i
  root="$FIXTURE_DIR/repo"
  make_repo "$root"
  wt_a="$FIXTURE_DIR/session-a"
  wt_b="$FIXTURE_DIR/session-b"
  git -C "$root" worktree add -q -b session-a "$wt_a" HEAD
  git -C "$root" worktree add -q -b session-b "$wt_b" HEAD

  echo "rounds=$ROUNDS"
  session_write "$wt_a" M9.1 "M9.1" "$ROUNDS" A & pid_a=$!
  session_write "$wt_b" M9.2 "M9.2" "$ROUNDS" B & pid_b=$!
  wait "$pid_a"; rc_a=$?
  wait "$pid_b"; rc_b=$?
  assert_eq "$rc_a" "0" "session A completed every round"
  assert_eq "$rc_b" "0" "session B completed every round"

  git -C "$root" merge -q --no-ff session-a -m "merge session-a"; merge_a=$?
  git -C "$root" merge -q --no-ff session-b -m "merge session-b"; merge_b=$?
  assert_eq "$merge_a" "0" "the session-a branch merges with no conflict"
  assert_eq "$merge_b" "0" "the session-b branch merges with no conflict"

  count_a="$(find "$root/devlog/handovers/M9.1" -name "*-round*.md" | wc -l | tr -d ' ')"
  count_b="$(find "$root/devlog/handovers/M9.2" -name "*-round*.md" | wc -l | tr -d ' ')"
  assert_eq_num "$count_a" "$ROUNDS" "session A wrote one handover per round"
  assert_eq_num "$count_b" "$ROUNDS" "session B wrote one handover per round"

  dups="$(find "$root/devlog/handovers" -name "*-round*.md" -printf '%f\n' | sort | uniq -d)"
  assert_eq "$dups" "" "the two tracks took disjoint ids"

  for ((i = 1; i <= ROUNDS; i++)); do
    assert_eq "$(grep -Rl "A-round-$i" "$root/devlog/handovers" | wc -l | tr -d ' ')" "1" "round $i of session A survived"
    assert_eq "$(grep -Rl "B-round-$i" "$root/devlog/handovers" | wc -l | tr -d ' ')" "1" "round $i of session B survived"
  done

  # The merge role is the shared roadmap's one writer.
  local delta_a delta_b
  delta_a="$(cat "$root/devlog/handovers/M9.1/roadmap-delta.txt")"
  delta_b="$(cat "$root/devlog/handovers/M9.2/roadmap-delta.txt")"
  sed -i "s|^- \[ \] \*\*M9.1 row\*\*.*|$delta_a|" "$root/devlog/roadmap.md"
  sed -i "s|^- \[ \] \*\*M9.2 row\*\*.*|$delta_b|" "$root/devlog/roadmap.md"
  git -C "$root" add -A
  git -C "$root" commit -q -m "record both sub-milestones"

  assert_contains "$(cat "$root/devlog/roadmap.md")" "- [x] **M9.1 row**" "session A's sub-milestone advanced"
  assert_contains "$(cat "$root/devlog/roadmap.md")" "- [x] **M9.2 row**" "session B's sub-milestone advanced"
  assert_eq "$(git -C "$root" status --porcelain)" "" "the merged tree is clean"
}

test_two_writers_on_one_roadmap_row_conflict() {
  local root wt_a wt_b merge_a merge_b rc
  root="$FIXTURE_DIR/repo"
  make_repo "$root"
  wt_a="$FIXTURE_DIR/session-a"
  wt_b="$FIXTURE_DIR/session-b"
  git -C "$root" worktree add -q -b session-a "$wt_a" HEAD
  git -C "$root" worktree add -q -b session-b "$wt_b" HEAD

  sed -i 's|^- \[ \] \*\*M9.1 row\*\*.*|- [x] **M9.1 row** -- A|' "$wt_a/devlog/roadmap.md"
  git -C "$wt_a" add -A
  git -C "$wt_a" commit -q -m "A flips the row"
  sed -i 's|^- \[ \] \*\*M9.1 row\*\*.*|- [x] **M9.1 row** -- B|' "$wt_b/devlog/roadmap.md"
  git -C "$wt_b" add -A
  git -C "$wt_b" commit -q -m "B flips the row"

  git -C "$root" merge -q --no-ff session-a -m "merge session-a"; merge_a=$?
  git -C "$root" merge -q --no-ff session-b -m "merge session-b"; merge_b=$?
  assert_eq "$merge_a" "0" "the first writer merges"
  rc="$merge_b"
  assert_eq "$rc" "1" "the second writer on the same row conflicts"
  assert_contains "$(git -C "$root" status --porcelain)" "UU devlog/roadmap.md" "the conflict names the roadmap"
  git -C "$root" merge --abort
}

run_test test_two_sessions_advance_two_submilestones
run_test test_two_writers_on_one_roadmap_row_conflict

test_done
