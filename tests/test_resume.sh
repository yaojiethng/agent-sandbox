#!/usr/bin/env bash
# tests/test_resume.sh
# Command-shape tests for scripts/resume_agent.sh  --  the split-out resume command
# (F2 two-command design, design session `20260821-02`, impl `20260821-03`).

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
source "$TEST_DIR/libs/sig_helpers.sh"
test_setup

RESUME="$REPO_ROOT/scripts/resume_agent.sh"

# Build a minimal fixture sandbox with a .env and .compose/<session-id>.yml
# registry records (the unified inventory, D7). Records embed the provider via
# the agent image line and the session labels (ID 06). Builds pi + hermes
# records so provider-filtering and the interactive picker are testable.
build_fixture() {
  local FIXTURE_ID="$1"
  local dir="$FIXTURE_DIR/$FIXTURE_ID"
  mkdir -p "$dir/sandbox/.compose" "$dir/sandbox/.workspace/session-diffs" \
           "$dir/sandbox/.workspace/input" "$dir/sandbox/.workspace/output" \
           "$dir/project"

  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF

  cat > "$dir/sandbox/.compose/abc123.yml" <<'EOF'
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-120000
  agent-sandbox.session-id: abc123
services:
  sandbox:
    image: agent-sandbox-abc123
  agent:
    image: pi-agent-test-project
EOF

  cat > "$dir/sandbox/.compose/def456.yml" <<'EOF'
x-session-labels:
  agent-sandbox.host-head-sha: c0ffee
  agent-sandbox.host-branch: feat
  agent-sandbox.session-ts: 20260821-090000
  agent-sandbox.session-id: def456
services:
  sandbox:
    image: agent-sandbox-def456
  agent:
    image: hermes-agent-test-project
EOF

  echo "$dir/sandbox"
}

# --list renders the enriched registry display (id | provider | ts | branch),
# newest session first, and filters by PROVIDER (decisions I-2, I-3).
test_list_renders_enriched() {
  local sandbox
  sandbox="$(build_fixture "list")"
  local out
  out="$(bash "$RESUME" --name=test --project="$FIXTURE_DIR/list/project" --sandbox="$sandbox" --list)"
  if echo "$out" | grep -q "SESSION.*PROVIDER.*BRANCH.*WORK.*STATE" \
     && echo "$out" | grep -q "abc123.*pi.*main"; then
    pass "resume --list: renders enriched record display (headers + row)"
  else
    fail "resume --list: expected headers + abc123 row, got: $out"
  fi
}

# --list --provider=<n> filters the inventory to that provider (decision I-2).
test_list_provider_filter() {
  local sandbox
  sandbox="$(build_fixture "filter")"
  local out pi_out hermes_out
  pi_out="$(bash "$RESUME" --name=test --project="$FIXTURE_DIR/filter/project" --sandbox="$sandbox" --list --provider=pi)"
  hermes_out="$(bash "$RESUME" --name=test --project="$FIXTURE_DIR/filter/project" --sandbox="$sandbox" --list --provider=hermes)"
  if echo "$pi_out" | grep -q "abc123" && ! echo "$pi_out" | grep -q "def456" \
     && echo "$hermes_out" | grep -q "def456" && ! echo "$hermes_out" | grep -q "abc123"; then
    pass "resume --list --provider=<n>: filters inventory by provider"
  else
    fail "resume --list --provider=<n>: expected provider-filtered rows, got pi=[$pi_out] hermes=[$hermes_out]"
  fi
}

# --list --provider=<n> with no matching records -> clear error, non-zero.
test_list_provider_no_match() {
  local sandbox
  sandbox="$(build_fixture "nonnatch")"
  local out rc
  out="$(bash "$RESUME" --name=test --project="$FIXTURE_DIR/nonnatch/project" --sandbox="$sandbox" --list --provider=nope 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q "no resumable sessions for provider"; then
    pass "resume --list --provider=<n>: no match -> clear error, non-zero"
  else
    fail "resume --list --provider=<n>: expected no-match error, got rc=$rc: $out"
  fi
}

# Bare resume (no target flags) -> help hinting --list / --interactive, non-zero.
test_bare_resume_prints_help() {
  local out rc
  out="$(bash "$RESUME" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] \
     && echo "$out" | grep -q -- "--list" \
     && echo "$out" | grep -q -- "--interactive"; then
    pass "resume (bare): prints help hinting --list and --interactive, non-zero exit"
  else
    fail "resume (bare): expected non-zero + help hinting --list/--interactive, got rc=$rc: $out"
  fi
}

# Unknown flag -> help + non-zero (D2).
test_unknown_flag_prints_help() {
  local out rc
  out="$(bash "$RESUME" --bogus 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q -- "--list"; then
    pass "resume: unknown flag prints help, non-zero exit"
  else
    fail "resume: expected non-zero + help on unknown flag, got rc=$rc: $out"
  fi
}

# --interactive presents the picker + confirm; 'n' at confirm aborts (I-1).
test_interactive_confirm_abort() {
  local sandbox
  sandbox="$(build_fixture "int_abort")"
  local out rc
  out="$(printf '1\nn\n' | bash "$RESUME" --name=test --project="$FIXTURE_DIR/int_abort/project" --sandbox="$sandbox" --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] \
     && echo "$out" | grep -q "Resume which session?" \
     && echo "$out" | grep -qi "pi-agent\|abc123" \
     && echo "$out" | grep -qi "aborted"; then
    pass "resume --interactive: picker + confirm, abort on 'n' -> non-zero"
  else
    fail "resume --interactive: expected picker+abort on n, got rc=$rc: $out"
  fi
}

# --interactive with no records -> clear error, non-zero.
test_interactive_no_records() {
  local dir="$FIXTURE_DIR/int_none"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF
  local out rc
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q "No resumable sessions found"; then
    pass "resume --interactive: no records -> clear error, non-zero"
  else
    fail "resume --interactive: expected no-records error, got rc=$rc: $out"
  fi
}

# --provider alone (no --list / --interactive / --session-id) -> guidance, non-zero.
test_provider_alone_guidance() {
  local out rc
  out="$(bash "$RESUME" --provider=pi 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q "inventory filter"; then
    pass "resume --provider alone: guidance that it is an inventory filter, non-zero"
  else
    fail "resume --provider alone: expected inventory-filter guidance, got rc=$rc: $out"
  fi
}

# --session-id with a missing record -> clear error, non-zero.
test_session_id_missing_record() {
  local dir="$FIXTURE_DIR/missing"
  mkdir -p "$dir/sandbox/.compose" "$dir/project/.git"
  git -C "$dir/project" init -q >/dev/null 2>&1
  git -C "$dir/project" -c user.email=t@t -c user.name=t commit --allow-empty -q -m init >/dev/null 2>&1
  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF
  local out rc
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --session-id=nope 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "no session record"; then
    pass "resume --session-id: missing record -> clear error, non-zero"
  else
    fail "resume --session-id: expected 'no session record', got rc=$rc: $out"
  fi
}

# --list renders a sandbox-staleness WARNING label (registry-truth, D7): a
# record whose host-head-sha matches the current HEAD shows no marker; a
# differing one is flagged [SANDBOX_STALE].
test_list_shows_sandbox_staleness() {
  local dir="$FIXTURE_DIR/staleness"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  git -C "$dir/project" init -q >/dev/null 2>&1
  git -C "$dir/project" -c user.email=t@t -c user.name=t commit --allow-empty -q -m init >/dev/null 2>&1
  local head_sha
  head_sha="$(git -C "$dir/project" rev-parse HEAD)"
  cat > "$dir/sandbox/.compose/aaa.yml" <<EOF
x-session-labels:
  agent-sandbox.host-head-sha: $head_sha
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-120000
services:
  sandbox:
    image: sandbox-test-project
  agent:
    image: pi-agent-test-project
EOF
  cat > "$dir/sandbox/.compose/bbb.yml" <<EOF
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef99
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260820-120000
services:
  sandbox:
    image: sandbox-test-project
  agent:
    image: hermes-agent-test-project
EOF
  local out
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  if echo "$out" | grep -qE "bbb.*main.*SANDBOX_STALE" \
     && ! echo "$out" | grep -qE "aaa.*main.*SANDBOX_STALE"; then
    pass "resume --list: SANDBOX_STALE label only on a differing host-head-sha record"
  else
    fail "resume --list: expected SANDBOX_STALE only on bbb, got: $out"
  fi
}

# write_minimal_record DIR SID IMAGE
# A record with a host-head-sha of deadbeef, the given agent image and a
# sandbox image (the real compose record carries both service image lines).
# The sandbox-stale column is unknown without a git project; image tests
# assert only the image column.
write_minimal_record() {
  local dir="$1" sid="$2" image="$3"
  local sandbox_img="sandbox-${image#*-agent-}"
  cat > "$dir/sandbox/.compose/$sid.yml" <<EOF
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-120000
  agent-sandbox.image-sig: 1234abcd5678
services:
  sandbox:
    image: $sandbox_img
  agent:
    image: $image
EOF
}

# The PROVIDER cell shows the bare provider name. The image-content signature
# value was dropped from rows (operator-directed, 20260901-17) -- image
# identity now travels in the record's digest labels, shown nowhere in rows.
test_list_shows_provider_without_image_sig() {
  local dir="$FIXTURE_DIR/img_sig"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  write_minimal_record "$dir" "aaa" "pi-agent-test-project"

  local out
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  # Positive assertion only: the cell shows the bare provider name followed by
  # whitespace (a parenthetical image-sig would sit where the whitespace is).
  if echo "$out" | grep -qE "aaa[[:space:]]+pi[[:space:]]"; then
    pass "resume --list: provider cell shows bare provider (no image-sig)"
  else
    fail "resume --list: expected bare 'pi', got: $out"
  fi
}

# A record with no image-sig field (legacy/before-this-field) renders `pi`
# with no parenthetical -- graceful, no `pi (` shell-noise.
test_list_no_sig_when_field_empty() {
  local dir="$FIXTURE_DIR/img_nosig"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  cat > "$dir/sandbox/.compose/aaa.yml" <<'EOF'
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-120000
services:
  sandbox:
    image: sandbox-test-project
  agent:
    image: pi-agent-test-project
EOF

  local out
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  # Legacy record without an image-sig field: the row still renders the bare
  # provider (no parenthetical, no crash on the missing field).
  if echo "$out" | grep -qE "aaa[[:space:]]+pi[[:space:]]"; then
    pass "resume --list: legacy record without image-sig renders bare pi"
  else
    fail "resume --list: expected bare pi for legacy record, got: $out"
  fi
}

# picker) and reports the remainder honestly.
test_list_caps_at_page_size() {
  local dir="$FIXTURE_DIR/list_cap"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  local i
  for i in $(seq -w 1 12); do
    write_minimal_record "$dir" "s$i" "pi-agent-test-project"
  done

  local out
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list 2>&1)"
  local rows shown
  rows="$(echo "$out" | grep -cE '^  s[0-9]+  ' || true)"
  shown="$(echo "$out" | grep -c 'more session' || true)"
  if [[ "$rows" -eq 10 ]] && [[ "$shown" -eq 1 ]] && echo "$out" | grep -q "2 more session"; then
    pass "resume --list: caps at 10 rows with remainder footer"
  else
    fail "resume --list: expected 10 rows + remainder footer, got rows=$rows footer=$shown: $out"
  fi
}

# The interactive picker paginates at the same page size (10): page nav via n/p.
test_interactive_paginates_at_page_size() {
  local dir="$FIXTURE_DIR/img_page"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  local i
  for i in $(seq -w 1 12); do
    write_minimal_record "$dir" "s$i" "pi-agent-test-project"
  done

  local out
  out="$(printf 'n\n1\nn\n' | bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q "page 2 of 2"; then
    pass "resume --interactive: picker paginates at page size (page 2 of 2)"
  else
    fail "resume --interactive: expected paginated picker, got rc=$rc: $out"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

# STATE cell is the LAST lifecycle event (start/stop) from the session log,
# verb overridden by live docker state; stopped sessions show when they were
# last active (operator-directed consolidation of STARTED/STATE/LAST_USED).
test_list_state_cell_from_log() {
  local dir="$FIXTURE_DIR/state_cell"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  write_minimal_record "$dir" "aaa" "pi-agent-test-project"
  local recent past
  recent=$(date -u -d '-10 minutes' +%Y%m%d-%H%M%S)
  past=$(date -u -d '-2 days' +%Y%m%d-%H%M%S)
  # stop is the last event -> cell shows the stop
  printf 'last_started=%s\nlast_stopped=%s\n' "$past" "$recent" > "$dir/sandbox/.compose/aaa.log"

  local out
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  if echo "$out" | grep -qE "stopped 10m ago"; then
    pass "resume --list: STATE cell shows the last log event (stopped 10m ago)"
  else
    fail "resume --list: expected 'stopped 10m ago', got: $out"
  fi

  # start after stop -> last event is the start
  printf 'last_started=%s\nlast_stopped=%s\n' "$recent" "$past" > "$dir/sandbox/.compose/aaa.log"
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  if echo "$out" | grep -qE "started 10m ago"; then
    pass "resume --list: STATE cell flips to the start event when it is last"
  else
    fail "resume --list: expected 'started 10m ago', got: $out"
  fi
}

run_test test_list_renders_enriched
run_test test_list_provider_filter
run_test test_list_provider_no_match
run_test test_list_shows_provider_without_image_sig
run_test test_list_no_sig_when_field_empty
run_test test_list_state_cell_from_log
run_test test_bare_resume_prints_help
run_test test_unknown_flag_prints_help
run_test test_interactive_confirm_abort
run_test test_interactive_no_records
run_test test_provider_alone_guidance
run_test test_session_id_missing_record
run_test test_list_shows_sandbox_staleness
run_test test_list_caps_at_page_size
run_test test_interactive_paginates_at_page_size

echo ""
echo "Test complete: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] && exit 0 || exit 1