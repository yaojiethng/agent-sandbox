#!/usr/bin/env bash
# TEST_DEADLINE: 120
# tests/test_package_eval_snapshot.sh
# Behavioural tests for src/libs/package_eval_snapshot.sh -- the eval snapshot
# packager -- and for the shape it promises the `package-eval-snapshot` prompt.
#
#   a conforming run                        --  rc 0; all seven artefacts land
#   the transcript copy                     --  byte-identical to the source
#   the operator turns                      --  numbered in order, empty turns skipped
#   a partial last transcript line          --  dropped from the turns, reported in the facts, the copy unchanged
#   the bundle                              --  verifies, and clones to the head commit
#   the credential scan                     --  a count per pattern, no matched value in the report
#   an unset PI_SESSION_FILE                --  rc 1; the variable is named
#   a transcript path that is absent        --  rc 1; the path is named
#   no base commit at all                   --  rc 1; both sources are named
#   a base that is not a commit             --  rc 1; the value is named
#   the summary shape                       --  rc 1 for spaces, capitals, a short or long value
#   an explicit baseline                    --  the facts report the recorded init_sha and the movement
#
# The fixture repositories sit under $FIXTURE_DIR, outside the repo tree. The
# script is called as a library so a case can point it at a fixture repository;
# the direct-mode flag handling is covered by the shape cases.
#
# Run:   bash tests/test_package_eval_snapshot.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/package_eval_snapshot.sh"

# write_transcript PATH KIND  --  a minimal pi-style JSONL transcript.
#   plain      --  two user turns and one assistant turn, one user turn empty
#   secret     --  the same, with a key-shaped string in the second turn
#   partial    --  the same as plain, with a truncated final line
write_transcript() {
  local path="$1"
  local kind="${2:-plain}"
  local secret=""
  if [[ "$kind" == "secret" ]]; then
    secret=" with a key sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 in it"
  fi
  {
    printf '%s\n' '{"type":"session","id":"fixture"}'
    printf '%s\n' '{"type":"message_start","message":{"role":"user","content":[{"type":"text","text":"first turn"}]}}'
    printf '%s\n' '{"type":"message_start","message":{"role":"assistant","content":[{"type":"text","text":"acknowledged"}]}}'
    printf '%s\n' '{"type":"message_start","message":{"role":"user","content":[{"type":"text","text":"second turn'"$secret"'"}]}}'
    printf '%s\n' '{"type":"message_start","message":{"role":"user","content":[]}}'
  } > "$path"
  if [[ "$kind" == "partial" ]]; then
    printf '%s' '{"type":"message_start","message":{"role":"user","conte' >> "$path"
  fi
}

# make_snapshot_fixture ROOT  --  a sandbox repository with SESSION_STATE and a
# transcript, the two inputs a snapshot needs. Prints the fixture repository path.
make_snapshot_fixture() {
  local root="$1"
  local repo="$root/repo"
  make_sandbox_fixture "$repo" > /dev/null
  commit_change "$repo" "second commit" > /dev/null
  echo "session_id=fixture01" >> "$repo/.git/SESSION_STATE"
  write_transcript "$root/chat.jsonl" "${2:-plain}"
  printf '%s' "$repo"
}

run_snapshot() {
  local repo="$1" out="$2" baseline="${3:-}"
  SNAPSHOT_RC=0
  SNAPSHOT_OUT=$(package_eval_snapshot "$repo" "$out" "$baseline" 2>&1) || SNAPSHOT_RC=$?
}

test_snapshot_writes_every_artefact() {
  local root="$FIXTURE_DIR/artefacts"
  local repo; repo=$(make_snapshot_fixture "$root")
  local out="$root/snapshot"
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$out"
  assert_rc 0 "$SNAPSHOT_RC" 'a conforming run succeeds'
  local name
  for name in chat.jsonl operator-turns.md repo.bundle bundle-verify.txt commits.txt eval-point.json credentials-scan.txt .snapshot-status; do
    assert_file_exists "$out/$name" "$name is written"
  done
  if [[ ! -e "$out/.work" ]]; then
    pass 'the working directory is removed'
  else
    fail 'the working directory survives the run'
  fi
  unset PI_SESSION_FILE
}

test_transcript_copy_is_byte_identical() {
  local root="$FIXTURE_DIR/copy"
  local repo; repo=$(make_snapshot_fixture "$root")
  local out="$root/snapshot"
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$out"
  if cmp -s "$root/chat.jsonl" "$out/chat.jsonl"; then
    pass 'the transcript copy is byte-identical'
  else
    fail 'the transcript copy differs from the source'
  fi
  unset PI_SESSION_FILE
}

test_operator_turns_are_numbered_in_order() {
  local root="$FIXTURE_DIR/turns"
  local repo; repo=$(make_snapshot_fixture "$root")
  local out="$root/snapshot"
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$out"
  assert_contains "$(cat "$out/operator-turns.md")" '### Operator turn 1' 'the first turn is numbered'
  assert_contains "$(cat "$out/operator-turns.md")" '### Operator turn 2' 'the second turn is numbered'
  assert_contains "$(cat "$out/operator-turns.md")" "$(printf '### Operator turn 1\n\nfirst turn')" 'the first turn carries its text'
  local counted
  counted=$(grep -c '^### Operator turn ' "$out/operator-turns.md")
  assert_eq "2" "$counted" 'the empty turn is skipped'
  unset PI_SESSION_FILE
}

test_partial_last_line_is_reported() {
  local root="$FIXTURE_DIR/partial"
  local repo; repo=$(make_snapshot_fixture "$root" partial)
  local out="$root/snapshot"
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$out"
  assert_rc 0 "$SNAPSHOT_RC" 'a truncated final line does not fail the run'
  assert_eq "true" "$(jq -r '.transcript.last_line_incomplete_at_copy' "$out/eval-point.json")" 'the facts report the incomplete line'
  assert_eq "2" "$(jq -r '.transcript.operator_turns' "$out/eval-point.json")" 'the truncated line is not a turn'
  if cmp -s "$root/chat.jsonl" "$out/chat.jsonl"; then
    pass 'the copy keeps the truncated byte'
  else
    fail 'the copy was rewritten'
  fi
  unset PI_SESSION_FILE
}

test_bundle_verifies_and_clones() {
  local root="$FIXTURE_DIR/bundle"
  local repo; repo=$(make_snapshot_fixture "$root")
  local out="$root/snapshot"
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$out"
  assert_contains "$(cat "$out/bundle-verify.txt")" 'is okay' 'the bundle verifies'
  local head_sha clone_sha
  head_sha=$(git -C "$repo" rev-parse HEAD)
  git clone --quiet "$out/repo.bundle" "$root/clone" 2>/dev/null
  clone_sha=$(git -C "$root/clone" rev-parse HEAD 2>/dev/null)
  assert_eq "$head_sha" "$clone_sha" 'the clone reaches the head commit'
  unset PI_SESSION_FILE
}

test_credential_scan_reports_counts_only() {
  local root="$FIXTURE_DIR/scan"
  local repo; repo=$(make_snapshot_fixture "$root" secret)
  local out="$root/snapshot"
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$out"
  local report; report=$(cat "$out/credentials-scan.txt")
  assert_contains "$report" "1	sk-[A-Za-z0-9]{20,}" 'the key pattern is counted'
  assert_contains "$report" '# total	1' 'the total is stated'
  if [[ "$report" == *"ABCDEFGHIJKLMNOP"* ]]; then
    fail 'the report prints a matched value'
  else
    pass 'the report prints no matched value'
  fi
  assert_eq "1" "$(jq -r '.credential_scan.pattern_hits' "$out/eval-point.json")" 'the facts carry the hit count'
  unset PI_SESSION_FILE
}

test_unset_session_file_fails_closed() {
  local root="$FIXTURE_DIR/nosession"
  local repo; repo=$(make_snapshot_fixture "$root")
  unset PI_SESSION_FILE
  run_snapshot "$repo" "$root/snapshot"
  assert_rc 1 "$SNAPSHOT_RC" 'an unset PI_SESSION_FILE fails'
  assert_contains "$SNAPSHOT_OUT" 'PI_SESSION_FILE is unset' 'the variable is named'
  if [[ ! -e "$root/snapshot/chat.jsonl" ]]; then
    pass 'no partial artefact is left'
  else
    fail 'the refused run left an artefact behind'
  fi
}

test_absent_transcript_fails_closed() {
  local root="$FIXTURE_DIR/absent"
  local repo; repo=$(make_snapshot_fixture "$root")
  export PI_SESSION_FILE="$root/not-here.jsonl"
  run_snapshot "$repo" "$root/snapshot"
  assert_rc 1 "$SNAPSHOT_RC" 'an absent transcript fails'
  assert_contains "$SNAPSHOT_OUT" 'no transcript at' 'the path is named'
  unset PI_SESSION_FILE
}

test_no_base_commit_fails_closed() {
  local root="$FIXTURE_DIR/nobase"
  local repo; repo=$(make_snapshot_fixture "$root")
  rm -f "$repo/.git/SESSION_STATE"
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$root/snapshot"
  assert_rc 1 "$SNAPSHOT_RC" 'no base commit fails'
  assert_contains "$SNAPSHOT_OUT" 'SESSION_STATE carries no init_sha' 'both sources are named'
  unset PI_SESSION_FILE
}

test_base_that_is_not_a_commit_fails_closed() {
  local root="$FIXTURE_DIR/badbase"
  local repo; repo=$(make_snapshot_fixture "$root")
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$root/snapshot" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
  assert_rc 1 "$SNAPSHOT_RC" 'a base that is not a commit fails'
  assert_contains "$SNAPSHOT_OUT" 'is not a commit in' 'the value is named'
  unset PI_SESSION_FILE
}

test_summary_shape_is_enforced() {
  local good bad
  for good in abc a_b_c instruction_surface_contract; do
    if package_eval_snapshot_validate_summary "$good" 2>/dev/null; then
      pass "accepts '$good'"
    else
      fail "rejects '$good'"
    fi
  done
  for bad in "" "ab" "Has Spaces" "Has-Caps" "_leading" "trailing_" "a"$(printf 'b%.0s' $(seq 1 48)); do
    if package_eval_snapshot_validate_summary "$bad" 2>/dev/null; then
      fail "accepts '$bad'"
    else
      pass "rejects '$bad'"
    fi
  done
}

test_explicit_baseline_is_recorded_as_moved() {
  local root="$FIXTURE_DIR/baseline"
  local repo; repo=$(make_snapshot_fixture "$root")
  local out="$root/snapshot"
  local recorded head_sha
  recorded=$(session_state_read "$repo" init_sha)
  head_sha=$(git -C "$repo" rev-parse HEAD)
  export PI_SESSION_FILE="$root/chat.jsonl"
  run_snapshot "$repo" "$out" "$head_sha"
  assert_rc 0 "$SNAPSHOT_RC" 'an explicit baseline runs'
  assert_eq "$recorded" "$(jq -r '.repository.recorded_init_sha' "$out/eval-point.json")" 'the recorded init_sha is kept'
  assert_eq "$head_sha" "$(jq -r '.repository.base' "$out/eval-point.json")" 'the explicit base is used'
  assert_eq "true" "$(jq -r '.repository.baseline_moved' "$out/eval-point.json")" 'the movement is reported'
  assert_eq "" "$(cat "$out/commits.txt")" 'an empty series is written, not an error'
  unset PI_SESSION_FILE
}

run_test test_snapshot_writes_every_artefact
run_test test_transcript_copy_is_byte_identical
run_test test_operator_turns_are_numbered_in_order
run_test test_partial_last_line_is_reported
run_test test_bundle_verifies_and_clones
run_test test_credential_scan_reports_counts_only
run_test test_unset_session_file_fails_closed
run_test test_absent_transcript_fails_closed
run_test test_no_base_commit_fails_closed
run_test test_base_that_is_not_a_commit_fails_closed
run_test test_summary_shape_is_enforced
run_test test_explicit_baseline_is_recorded_as_moved

test_done
