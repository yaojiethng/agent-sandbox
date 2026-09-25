#!/usr/bin/env bash
# tests/test_prune.sh
# Unit/behaviour tests for the registry-based prune (scripts/prune.sh):
# Pins cite: roadmap "Label-filtered volume prune" (l.140);
#             code-owner: scripts/prune.sh (echo text).

# Rule 1 record selection (staleness, provider, age filters), dry-run, the
# interactive confirm wrapper, and the STALE=image not-yet-implemented guard.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"

setup_prune_fixture() {
  local FIXTURE_DIR="$1"
  PROJECT_NAME="test-project"
  SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  PROJECT_DIR="$FIXTURE_DIR/project"
  mkdir -p "$SANDBOX_DIR" "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init -q 2>/dev/null
  git -C "$PROJECT_DIR" config user.email test@example.com
  git -C "$PROJECT_DIR" config user.name test
  : > "$PROJECT_DIR/README"
  git -C "$PROJECT_DIR" add -A
  git -C "$PROJECT_DIR" commit -qm init
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"
  :> "$DOCKER_TRACE_LOG"
  unset DOCKER_STUB_PS_IDS DOCKER_STUB_NETWORK_IDS DOCKER_STUB_SESSION_ID_LABEL DOCKER_STUB_VOLUME_NAMES
  unset DOCKER_STUB_SESSION_ID_LABELS DOCKER_STUB_LABELS
}
current_sha() { git -C "$PROJECT_DIR" rev-parse HEAD; }

write_record() {
  # write_record SESSION_ID PROVIDER HOST_HEAD_SHA SESSION_TS [SANDBOX_TYPE]
  local sid="$1" provider="$2" sha="$3" ts="$4" sbox_type="${5:-copy}"
  mkdir -p "$SANDBOX_DIR/.compose"
  cat > "$SANDBOX_DIR/.compose/$sid.yml" <<EOF
services:
  sandbox:
    image: sandbox-test-project
  agent:
    image: ${provider}-agent-test-project
    labels:
      agent-sandbox.session-id: $sid
      agent-sandbox.session-ts: $ts
      agent-sandbox.host-head-sha: $sha
      agent-sandbox.host-branch: main
    environment:
      - SANDBOX_TYPE=$sbox_type
EOF
}

invoke_prune() {
  (
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/prune.sh" \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      "$@"
  )
}

record_exists() { [[ -f "$SANDBOX_DIR/.compose/$1.yml" ]]; }

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Given: two stale records, one `pi` and one `hermes`, both older than the cutoff
# When:  prune runs with --provider=pi
# Then:  only the pi record is removed and the hermes record survives
# Asserts: --provider narrows Rule 1 selection
test_rule1_provider_filter() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_provider"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  local sha; sha="$(current_sha)"
  write_record "s_pi_a" "pi" "aaaa1111aaaa"   "20260801-000000"
  write_record "s_hermes_a" "hermes" "bbbb2222bbbb" "20260801-000000"

  invoke_prune --provider=pi > /dev/null 2>&1

  if ! record_exists "s_pi_a" && record_exists "s_hermes_a"; then
    pass "Rule 1 provider filter: only pi's stale record removed, hermes kept"
  else
    fail "Rule 1 provider filter: expected only pi's stale record removed"
  fi
  [[ -n "$sha" ]] # keep shellcheck happy about unused
}

# Given: one stale record whose session-ts is today
# When:  prune runs with the default 3-day cutoff
# Then:  the record survives
# Asserts: the age cutoff protects a recently-staled record
test_rule1_age_filter_skips_recent() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_age"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  local today; today="$(date +%Y%m%d)"
  # A stale record from TODAY is younger than the default 3-day cutoff -> kept.
  write_record "s_recent" "pi" "aaaa1111aaaa" "${today}-000000"

  invoke_prune > /dev/null 2>&1

  if record_exists "s_recent"; then
    pass "Rule 1 age filter: stale but recent record kept (within AGE_DAYS)"
  else
    fail "Rule 1 age filter: expected recent stale record kept"
  fi
}

# Given: one stale record whose session-ts is today
# When:  prune runs with --age-days=0
# Then:  the record is removed
# Asserts: --age-days sets the staleness cutoff
test_rule1_age_days_broadens() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_agedays"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  local today; today="$(date +%Y%m%d)"
  write_record "s_recent" "pi" "aaaa1111aaaa" "${today}-000000"

  invoke_prune --age-days=0 > /dev/null 2>&1

  if ! record_exists "s_recent"; then
    pass "Rule 1 age-days=0: even the newest stale record is removed"
  else
    fail "Rule 1 age-days=0: expected stale record removed"
  fi
}

# Given: one record whose host-head-sha equals the current project HEAD
# When:  prune runs
# Then:  the record survives
# Asserts: Rule 1 selects by sandbox staleness, not by age alone
test_fresh_record_kept() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_fresh"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  local sha; sha="$(current_sha)"
  write_record "s_fresh" "pi" "$sha" "20260801-000000"

  invoke_prune > /dev/null 2>&1

  if record_exists "s_fresh"; then
    pass "Rule 1: fresh record (host-head-sha == current HEAD) kept"
  else
    fail "Rule 1: expected fresh record kept"
  fi
}

# Given: one stale record
# When:  prune runs with --dry-run
# Then:  the plan names Rule 1, the run is labelled a dry run, and the record stays on disk
# Asserts: --dry-run reports and does not act
test_dry_run_shows_rule1_rule2() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_dry"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  write_record "s_stale" "pi" "aaaa1111aaaa" "20260801-000000"

  local OUT
  OUT="$(invoke_prune --dry-run)"

  if echo "$OUT" | grep -qi "rule 1" && echo "$OUT" | grep -qi "dry run" \
     && record_exists "s_stale"; then
    pass "dry-run: shows plan, labels it a dry run, leaves record in place"
  else
    fail "dry-run: expected rule 1 plan and no record removal"
  fi
}

# Given: one stale record and an answer of `n` on stdin
# When:  prune runs with --interactive
# Then:  the record survives
# Asserts: a declined confirmation stops the prune
test_interactive_abort_keeps_records() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_int_abort"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  write_record "s_stale" "pi" "aaaa1111aaaa" "20260801-000000"

  # Confirm input 'n' (or newline) -> abort, record untouched.
  echo "n" | invoke_prune --interactive > /dev/null 2>&1 || true

  if record_exists "s_stale"; then
    pass "interactive: abort ('n') leaves the record in place"
  else
    fail "interactive: expected abort to leave record in place"
  fi
}

# Given: one stale record and an answer of `n` on stdin
# When:  prune runs with --interactive --provider=pi
# Then:  the equivalent non-interactive command is printed and carries --provider=pi
# Asserts: the confirmation gate discloses the command it would perform
test_interactive_prints_command() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_int_cmd"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  write_record "s_stale" "pi" "aaaa1111aaaa" "20260801-000000"

  # Abort ('n') after the preview: the equivalent non-interactive command must
  # be printed before the gate; nothing is removed because the user declined.
  local OUT
  OUT="$(echo "n" | invoke_prune --interactive --provider=pi 2>/dev/null || true)"

  if echo "$OUT" | grep -q "Equivalent non-interactive command" \
     && echo "$OUT" | grep -q -- "--provider=pi"; then
    pass "interactive: prints equivalent non-interactive command before the confirm gate"
  else
    fail "interactive: expected the equivalent non-interactive command printed"
  fi
}

# Given: one stale record and a live container owned by that session
# When:  prune runs
# Then:  the record and the container are both removed
# Asserts: Rule 1 then a fresh Rule 2 scan removes the newly orphaned resource
test_complete_pass_removes_stale_session_resources() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_complete"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  # A stale copy session with a live container. The complete pass must remove
  # BOTH the stale record (Rule 1) AND its now-orphaned resource (Rule 2).
  export DOCKER_STUB_PS_IDS="c1"
  export DOCKER_STUB_SESSION_ID_LABEL="s_stale"
  write_record "s_stale" "pi" "aaaa1111aaaa" "20260801-000000"

  invoke_prune > /dev/null 2>&1

  if ! record_exists "s_stale" && grep -q "rm c1" "$DOCKER_TRACE_LOG"; then
    pass "complete pass: stale record + its orphaned container both removed"
  else
    fail "complete pass: expected stale record AND container removed"
  fi
}

# Given: an orphan network and an orphan volume whose session has no record
# When:  prune runs
# Then:  both are removed
# Asserts: the Rule 2 kind dispatcher reaches the network and volume branches
test_rule2_removes_network_and_volume_orphans() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_r2_sysnet"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  # Pre-existing orphans across the network + volume branches (no record for
  # their session). Covers the _session_id_of kind dispatcher and the Rule-2
  # network/volume removal branches.
  export DOCKER_STUB_NETWORK_IDS="net1"
  export DOCKER_STUB_VOLUME_NAMES="vol1"
  export DOCKER_STUB_SESSION_ID_LABEL="orphan_sess"

  invoke_prune > /dev/null 2>&1

  if grep -q "network rm net1" "$DOCKER_TRACE_LOG" && grep -q "volume rm vol1" "$DOCKER_TRACE_LOG"; then
    pass "Rule 2 branch coverage: orphaned network and volume both removed"
  else
    fail "Rule 2 branch coverage: expected network + volume orphan removal"
  fi
}

# Rule 2 discovery must canonicalize SANDBOX_DIR before building its label
# filter, so it matches the canonical `agent-sandbox.sandbox-dir` label baked at
# create time regardless of the `--sandbox` spelling. Here we invoke with a
# non-canonical trailing-slash spelling and assert the `ps -aq` filter carries
# the canonical (readlink-resolved) path.
# Given: --sandbox spelled with a redundant `/.` suffix
# When:  prune runs
# Then:  the `docker ps -aq` label filter carries the canonical path
# Asserts: Rule 2 canonicalises the spelling the label was baked with
test_rule2_canonicalizes_sandbox_dir_spelling() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_r2_canon"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  export DOCKER_STUB_PS_IDS="c1"
  export DOCKER_STUB_SESSION_ID_LABEL="orphan_sess"

  local canon_expected
  canon_expected="$(readlink -f "$SANDBOX_DIR")"
  local spelled
  spelled="$SANDBOX_DIR/."   # non-canonical: redundant `/.` suffix

  ( 
    export PATH="$STUB_DIR:$PATH"
    bash "$REPO_ROOT/scripts/prune.sh" \
      --name="$PROJECT_NAME" --project="$PROJECT_DIR" \
      --sandbox="$spelled" >/dev/null 2>&1
  )

  if grep -q "sandbox-dir=$canon_expected" "$DOCKER_TRACE_LOG"; then
    pass "Rule 2 canonicalizes --sandbox spelling before label filter"
  else
    fail "Rule 2 did not canonicalize --sandbox (filter carried a non-canonical spelling)"
  fi
}

# Given: two stale records (copy and mount), one fresh keeper, and a container owned by one stale session
# When:  prune runs
# Then:  both stale records go, the fresh record and its resource stay, and the stale session's container goes
# Asserts: the partition invariant -- every session ends fully pruned or fully kept
test_complete_pass_end_to_end() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_e2e"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  local sha; sha="$(current_sha)"
  # Two stale records (copy + mount deliveries) and a fresh keeper.
  write_record "s_a" "pi" "aaaa1111aaaa" "20260801-000000" copy
  write_record "s_b" "hermes" "bbbb2222bbbb" "20260801-000000" mount
  write_record "s_fresh" "pi" "$sha" "20260801-000000"
  # A container owned by stale session s_a. Rule 1 removes s_a's record; the
  # fresh Rule-2 scan then orphans s_a's container (complete-pass property).
  export DOCKER_STUB_PS_IDS="c_a"
  export DOCKER_STUB_SESSION_ID_LABEL="s_a"

  invoke_prune > /dev/null 2>&1

  local rec_a rec_b fresh cont
  rec_a="$([ ! -f "$SANDBOX_DIR/.compose/s_a.yml" ] && echo y || echo n)"
  rec_b="$([ ! -f "$SANDBOX_DIR/.compose/s_b.yml" ] && echo y || echo n)"
  fresh="$([ -f "$SANDBOX_DIR/.compose/s_fresh.yml" ] && echo y || echo n)"
  cont="$(grep -q 'rm c_a' "$DOCKER_TRACE_LOG" && echo y || echo n)"

  if [[ "$rec_a" == y && "$rec_b" == y && "$fresh" == y && "$cont" == y ]]; then
    pass "complete pass e2e: stale records removed, fresh kept, removed-SID resource cleaned"
  else
    fail "complete pass e2e: stale: a=$rec_a b=$rec_b fresh=$fresh resource=$cont"
  fi
}

# Given: --stale=fresh
# When:  prune runs
# Then:  it fails and names the unknown kind
# Asserts: the --stale validation rejects a retired kind
test_unknown_args_rejected() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_badarg"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"

  local OUT RC
  OUT="$(invoke_prune --stale=fresh 2>&1)"; RC=$?

  if [[ "$RC" -ne 0 ]] && echo "$OUT" | grep -q "unknown --stale kind"; then
    pass "prune: unknown --stale kind rejected (rc=$RC)"
  else
    fail "prune: expected unknown --stale kind error (rc=$RC)"
  fi
}

# Given: no --project
# When:  prune runs
# Then:  it fails and names --project
# Asserts: --project is required for the staleness comparison
test_missing_project_rejected() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr1_noproj"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"

  local OUT RC
  OUT="$( (export PATH="$STUB_DIR:$PATH"; bash "$REPO_ROOT/scripts/prune.sh" \
            --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" 2>&1) )"; RC=$?

  if [[ "$RC" -ne 0 ]] && echo "$OUT" | grep -q "\-\-project"; then
    pass "prune: missing --project rejected (rc=$RC)"
  else
    fail "prune: expected --project required error (rc=$RC)"
  fi
}

# Given: two stubbed containers, one carrying this project's labels and one carrying another project's
# When:  prune runs its container query
# Then:  only this project's container is stopped and removed
# Asserts: the container query's label filters select rather than decorate: the stub resolves
#          DOCKER_STUB_LABELS and returns only the matching ids.
test_rule2_filter_selects_only_this_projects_containers() {
  local FIXTURE_DIR="$FIXTURE_DIR/pr_r2_select"
  mkdir -p "$FIXTURE_DIR"
  setup_prune_fixture "$FIXTURE_DIR"
  # One stale record, so the pass reaches the Rule 2 scan at all.
  write_record "s_gone" "pi" "aaaa1111aaaa" "20260801-000000"
  local canon
  canon="$(readlink -f "$SANDBOX_DIR")"
  export DOCKER_STUB_PS_IDS="c_mine c_foreign"
  export DOCKER_STUB_LABELS="c_mine:agent-sandbox.project-name=$PROJECT_NAME,agent-sandbox.sandbox-dir=$canon c_foreign:agent-sandbox.project-name=another-project,agent-sandbox.sandbox-dir=/elsewhere"
  export DOCKER_STUB_SESSION_ID_LABEL="orphan_sess"

  invoke_prune > /dev/null 2>&1

  if grep -q "rm c_mine" "$DOCKER_TRACE_LOG" && ! grep -q "c_foreign" "$DOCKER_TRACE_LOG"; then
    pass "Rule 2 label filters select this project's containers only"
  else
    fail "Rule 2 container query reached a foreign container: $(grep c_foreign "$DOCKER_TRACE_LOG" | head -2)"
  fi
}


# Run
# ---------------------------------------------------------------------------

run_test test_rule1_provider_filter
run_test test_rule1_age_filter_skips_recent
run_test test_rule1_age_days_broadens
run_test test_fresh_record_kept
run_test test_dry_run_shows_rule1_rule2
run_test test_interactive_abort_keeps_records
run_test test_interactive_prints_command
run_test test_complete_pass_removes_stale_session_resources
run_test test_complete_pass_end_to_end
run_test test_rule2_removes_network_and_volume_orphans
run_test test_rule2_canonicalizes_sandbox_dir_spelling
run_test test_rule2_filter_selects_only_this_projects_containers
run_test test_unknown_args_rejected
run_test test_missing_project_rejected

test_done test_prune

