#!/usr/bin/env bash
# tests/test_resume.sh
# Command-shape tests for scripts/resume_agent.sh — the split-out resume command
# (F2 two-command design, design session `20260821-02`, impl `20260821-03`).

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
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
  if echo "$out" | grep -q "abc123.*pi.*20260821-120000.*main"; then
    pass "resume --list: renders enriched record display"
  else
    fail "resume --list: expected enriched abc123 row, got: $out"
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

# --list --provider=<n> with no matching records → clear error, non-zero.
test_list_provider_no_match() {
  local sandbox
  sandbox="$(build_fixture "nonnatch")"
  local out rc
  out="$(bash "$RESUME" --name=test --project="$FIXTURE_DIR/nonnatch/project" --sandbox="$sandbox" --list --provider=nope 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q "no resumable sessions for provider"; then
    pass "resume --list --provider=<n>: no match → clear error, non-zero"
  else
    fail "resume --list --provider=<n>: expected no-match error, got rc=$rc: $out"
  fi
}

# Bare resume (no target flags) → help hinting --list / --interactive, non-zero.
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

# Unknown flag → help + non-zero (D2).
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
    pass "resume --interactive: picker + confirm, abort on 'n' → non-zero"
  else
    fail "resume --interactive: expected picker+abort on n, got rc=$rc: $out"
  fi
}

# --interactive with no records → clear error, non-zero.
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
    pass "resume --interactive: no records → clear error, non-zero"
  else
    fail "resume --interactive: expected no-records error, got rc=$rc: $out"
  fi
}

# --provider alone (no --list / --interactive / --session-id) → guidance, non-zero.
test_provider_alone_guidance() {
  local out rc
  out="$(bash "$RESUME" --provider=pi 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q "inventory filter"; then
    pass "resume --provider alone: guidance that it is an inventory filter, non-zero"
  else
    fail "resume --provider alone: expected inventory-filter guidance, got rc=$rc: $out"
  fi
}

# --session-id with a missing record → clear error, non-zero.
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
    pass "resume --session-id: missing record → clear error, non-zero"
  else
    fail "resume --session-id: expected 'no session record', got rc=$rc: $out"
  fi
}

# --list renders a sandbox-staleness column (registry-truth, D7): a record whose
# host-head-sha matches the current project HEAD is 'fresh', a differing one is
# 'stale' (restores the criterion lost in the command-split; finding 20260821-05).
test_list_shows_sandbox_staleness() {
  local dir="$FIXTURE_DIR/staleness"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  # A git project so current HEAD is determinable.
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
  agent:
    image: pi-agent-test-project
EOF
  cat > "$dir/sandbox/.compose/bbb.yml" <<EOF
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef99
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260820-120000
services:
  agent:
    image: hermes-agent-test-project
EOF
  local out
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  if echo "$out" | grep -q "aaa.*main.*fresh" && echo "$out" | grep -q "bbb.*main.*stale"; then
    pass "resume --list: sandbox-staleness column marks matching= fresh, differing= stale"
  else
    fail "resume --list: expected fresh+stale staleness column, got: $out"
  fi
}

# Recompute the container-sig the stub will report for a "fresh" image.
# Sources the shared lib; deterministic content hash over the repo.
sandbox_sig() {
  source "$REPO_ROOT/src/libs/container_sig.sh"
  local -a s=(); mapfile -t s < <(_sandbox_sig_sources)
  container_sig "$REPO_ROOT" "${s[@]}"
}
agent_sig() {
  source "$REPO_ROOT/src/libs/container_sig.sh"
  local -a s=(); mapfile -t s < <(_agent_sig_sources "$REPO_ROOT" "$1")
  container_sig "$REPO_ROOT" "${s[@]}"
}
# Per-image fresh map for a pi provider record: both images carry their own
# recomputed sig, so the session is image-fresh.
fresh_sig_map() {
  echo "pi-agent-test-project:$(agent_sig pi) sandbox-test-project:$(sandbox_sig)"
}

# write_minimal_record DIR SID IMAGE
# A record with a host-head-sha of deadbeef and the given agent image (the
# sandbox-stale column is unknown without a git project; image tests assert
# only the image column).
write_minimal_record() {
  local dir="$1" sid="$2" image="$3"
  cat > "$dir/sandbox/.compose/$sid.yml" <<EOF
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-120000
services:
  agent:
    image: $image
EOF
}

# --list renders an image-staleness column: a record whose referenced image
# carries a container-sig differing from the recomputed source sig is image-
# stale, independent of the sandbox (registry-truth) staleness.
test_list_shows_image_staleness() {
  local dir="$FIXTURE_DIR/img_stale"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  write_minimal_record "$dir" "aaa" "pi-agent-test-project"

  local out
  out="$(PATH="$REPO_ROOT/test/stubs:$PATH" \
        DOCKER_STUB_IMAGE_SIG_LABEL="stale-baked-sig" \
        DOCKER_TRACE_LOG="$dir/docker-trace.log" \
        bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  if echo "$out" | grep -qE "aaa[[:space:]]+pi[[:space:]]+.*[[:space:]]+unknown[[:space:]]+stale"; then
    pass "resume --list: image-stale column marks differing container-sig record"
  else
    fail "resume --list: expected image-stale column, got: $out"
  fi
}

# Fresh images (baked sig == recomputed sig for BOTH agent and sandbox) are
# image-fresh and are NOT marked stale.
test_list_shows_image_fresh_when_sigs_match() {
  local dir="$FIXTURE_DIR/img_fresh"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  write_minimal_record "$dir" "aaa" "pi-agent-test-project"

  local out
  out="$(PATH="$REPO_ROOT/test/stubs:$PATH" \
        DOCKER_STUB_IMAGE_SIG_LABELS="$(fresh_sig_map)" \
        DOCKER_TRACE_LOG="$dir/docker-trace.log" \
        bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  if echo "$out" | grep -qE "aaa[[:space:]]+pi[[:space:]]+.*[[:space:]]+unknown[[:space:]]+fresh"; then
    pass "resume --list: matching container-sig marks image-fresh"
  else
    fail "resume --list: expected image-fresh column, got: $out"
  fi
}

# The two staleness dimensions are independent: a record sandbox-fresh (its
# host-head-sha == current project HEAD) but image-stale shows BOTH columns.
test_list_columns_are_independent() {
  local dir="$FIXTURE_DIR/img_indep"
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
  agent:
    image: pi-agent-test-project
EOF

  local out
  out="$(PATH="$REPO_ROOT/test/stubs:$PATH" \
        DOCKER_STUB_IMAGE_SIG_LABEL="stale-baked-sig" \
        DOCKER_TRACE_LOG="$dir/docker-trace.log" \
        bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --list)"
  if echo "$out" | grep -qE "aaa[[:space:]]+pi[[:space:]]+.*[[:space:]]+fresh[[:space:]]+stale"; then
    pass "resume --list: sandbox-fresh + image-stale both reported (independent columns)"
  else
    fail "resume --list: expected fresh+stale independent columns, got: $out"
  fi
}

# --interactive marks image-stale sessions in the picker (same backing
# inventory as --list).
test_interactive_marks_image_stale() {
  local dir="$FIXTURE_DIR/img_marker"
  mkdir -p "$dir/sandbox/.compose" "$dir/project"
  write_minimal_record "$dir" "aaa" "pi-agent-test-project"
  write_minimal_record "$dir" "bbb" "hermes-agent-test-project"

  local out
  out="$(printf '1\nn\n' | PATH="$REPO_ROOT/test/stubs:$PATH" \
        DOCKER_STUB_IMAGE_SIG_LABEL="stale-baked-sig" \
        DOCKER_TRACE_LOG="$dir/docker-trace.log" \
        bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q "IMG-STALE"; then
    pass "resume --interactive: picker marks image-stale session [IMG-STALE]"
  else
    fail "resume --interactive: expected [IMG-STALE] marker, got rc=$rc: $out"
  fi
}

# --list caps the displayed rows at the shared page size (10, same as draft's
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

run_test test_list_renders_enriched
run_test test_list_provider_filter
run_test test_list_provider_no_match
run_test test_bare_resume_prints_help
run_test test_unknown_flag_prints_help
run_test test_interactive_confirm_abort
run_test test_interactive_no_records
run_test test_provider_alone_guidance
run_test test_session_id_missing_record
run_test test_list_shows_sandbox_staleness
run_test test_list_shows_image_staleness
run_test test_list_shows_image_fresh_when_sigs_match
run_test test_list_columns_are_independent
run_test test_interactive_marks_image_stale
run_test test_list_caps_at_page_size
run_test test_interactive_paginates_at_page_size

echo ""
echo "Test complete: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] && exit 0 || exit 1