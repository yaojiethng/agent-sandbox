#!/usr/bin/env bash
# tests/test_dry_run_harness.sh
# Unit tests for src/libs/dry_run_harness.sh  --  the check framework the two
# dry-run probes share: the layer-aware counters, the summary branches, the
# section header, the writability helpers, and the diagnostics record writer.
#
# The probes' own behaviour is covered in tests/test_dry_run_probe.sh, which
# runs each probe as a script. These units call the harness directly, so the
# counter arithmetic, the warn-only summary, and the record-write failure path
# have an owner that fails when they change.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/dry_run_harness.sh"

# The counters and the layer maps are globals in the library, so every unit
# starts from a clean frame. A unit that forgets to reset sees the previous
# unit's counts, which is why every unit calls this first.
_reset_harness() {
  CRITICAL_FAILS=0
  WARN_FAILS=0
  LAYER_CRIT=()
  LAYER_WARN=()
  CURRENT_LAYER=""
}

_true() { return 0; }
_false() { return 1; }

# Given: a critical check whose command succeeds
# When:  critical runs
# Then:  it prints PASS and no counter moves
# Asserts: the pass arm of the critical wrapper.
test_critical_pass_moves_no_counter() {
  _reset_harness
  # Output goes to a file: a command substitution would run the check in a
  # subshell and the counters under test would be discarded with it.
  critical "sample check" _true > "$FIXTURE_DIR/crit_pass.out" 2>&1
  local out
  out="$(cat "$FIXTURE_DIR/crit_pass.out")"
  if [[ "$out" == *"PASS  sample check"* && "$CRITICAL_FAILS" -eq 0 && "$WARN_FAILS" -eq 0 ]]; then
    pass "critical: a passing check counts on neither counter"
  else
    fail "critical pass arm: out='$out' crit=$CRITICAL_FAILS warn=$WARN_FAILS"
  fi
}

# Given: a critical check whose command fails, inside a named section
# When:  critical runs
# Then:  the critical counter and that layer's critical counter both increment
# Asserts: the fail arm, and the layer attribution the record writer reads.
test_critical_fail_counts_against_its_layer() {
  _reset_harness
  section "alpha | the first layer"
  critical "sample check" _false > "$FIXTURE_DIR/crit_fail.out" 2>&1
  local out
  out="$(cat "$FIXTURE_DIR/crit_fail.out")"
  if [[ "$out" == *"FAIL  sample check"* \
     && "$CRITICAL_FAILS" -eq 1 \
     && "${LAYER_CRIT[alpha]:-0}" -eq 1 \
     && "$CURRENT_LAYER" == "alpha" ]]; then
    pass "critical: a failing check counts globally and against its section"
  else
    fail "critical fail arm: out='$out' crit=$CRITICAL_FAILS layer=${LAYER_CRIT[alpha]:-0}"
  fi
}

# Given: sections alpha and beta, with a failure in alpha only
# When:  the record writer renders both layers
# Then:  alpha renders FAIL and beta renders PASS
# Asserts: layer isolation - one layer's failure does not condemn another.
test_record_isolates_layers() {
  _reset_harness
  section "alpha | the first layer"
  critical "alpha check" _false
  section "beta | the second layer"
  critical "beta check" _true

  local record="$FIXTURE_DIR/record.layers"
  dry_run_write_record "$record" "alpha beta"

  local alpha beta status
  alpha="$(grep '^layer\.alpha=' "$record")"
  beta="$(grep '^layer\.beta=' "$record")"
  status="$(grep '^status=' "$record")"
  if [[ "$alpha" == "layer.alpha=FAIL" && "$beta" == "layer.beta=PASS" && "$status" == "status=FAIL" ]]; then
    pass "record: layers render their own verdict, overall status is FAIL"
  else
    fail "record layer isolation: $alpha $beta $status"
  fi
}

# Given: extra name=value fields passed to the writer
# When:  dry_run_write_record runs
# Then:  the record carries them verbatim ahead of the status line
# Asserts: the sandbox_init metrics contract (fields after the layers, before status).
test_record_writes_identity_and_extra_fields_in_order() {
  _reset_harness
  section "alpha | the first layer"
  DRY_RUN_IDENTITY="container-under-test" dry_run_write_record "$FIXTURE_DIR/record.order" "alpha" "metric_a=1" "metric_b=2"

  local body expected
  body="$(cat "$FIXTURE_DIR/record.order")"
  expected=$'container=container-under-test\nlayer.alpha=PASS\nmetric_a=1\nmetric_b=2\nstatus=PASS'
  if [[ "$body" == "$expected" ]]; then
    pass "record: identity, layers, extra fields, status, in that order"
  else
    fail "record order: got $(printf '%q' "$body")"
  fi
  unset DRY_RUN_IDENTITY
}

# Given: a record path whose parent directory does not exist
# When:  dry_run_write_record runs
# Then:  it warns on stderr and returns 0, leaving the run alive
# Asserts: a failed record write is a warning, not an abort - the probe's
#          remaining checks still run and the summary still prints.
test_record_write_failure_warns_without_aborting() {
  _reset_harness
  section "alpha | the first layer"
  local err rc=0
  err="$(dry_run_write_record "$FIXTURE_DIR/absent_dir/record" "alpha" 2>&1)" || rc=$?
  if [[ $rc -eq 0 && "$err" == *"WARN  could not write diagnostics record"* ]]; then
    pass "record: an unwritable path warns and does not abort"
  else
    fail "record write failure: rc=$rc err='$err'"
  fi
}

# Given: no failed check
# When:  dry_run_summary runs
# Then:  it prints the healthy text and returns 0
# Asserts: the all-clear arm.
test_summary_all_clear_returns_zero() {
  _reset_harness
  local out rc=0
  out="$(dry_run_summary)" || rc=$?
  if [[ $rc -eq 0 && "$out" == *"critical failures: 0"* && "$out" == *"All checks passed"* ]]; then
    pass "summary: no failures reports healthy and returns 0"
  else
    fail "summary all-clear: rc=$rc out='$out'"
  fi
}

# Given: a warning and no critical failure
# When:  dry_run_summary runs
# Then:  it counts the warning, prints the review text, and returns 0
# Asserts: the warn-only branch - warning-only runs stay healthy, and the
#          warning count reaches the summary (a mutation to the _warn counter
#          or to this text must fail here).
test_summary_warn_only_is_healthy_and_counted() {
  _reset_harness
  section "alpha | the first layer"
  warn_check "a warn-only check" _false

  local out rc=0
  out="$(dry_run_summary)" || rc=$?
  if [[ $rc -eq 0 \
     && "$out" == *"warnings:          1"* \
     && "${LAYER_WARN[alpha]:-0}" -eq 1 \
     && "$out" == *"Layer healthy. Review warnings before production use."* ]]; then
    pass "summary: warning-only is counted, attributed to its layer, and stays healthy"
  else
    fail "summary warn-only: rc=$rc out='$out'"
  fi
}

# Given: a warning and a critical failure
# When:  dry_run_summary runs
# Then:  the critical arm prints and the return code is 1
# Asserts: warnings never mask a critical failure.
test_summary_critical_failure_returns_one() {
  _reset_harness
  section "alpha | the first layer"
  warn_check "a warn-only check" _false
  critical "a critical check" _false

  local out rc=0
  out="$(dry_run_summary)" || rc=$?
  if [[ $rc -eq 1 \
     && "$out" == *"critical failures: 1"* \
     && "$out" == *"Layer is NOT healthy."* ]]; then
    pass "summary: a critical failure returns 1 and prints the refusal"
  else
    fail "summary critical: rc=$rc out='$out'"
  fi
}

# Given: a passed command with arguments
# When:  critical forwards them
# Then:  the command receives the arguments
# Asserts: the wrapper's argument pass-through, which the probes rely on for
#          every parameterised check.
test_critical_forwards_arguments() {
  _reset_harness
  local mark="$FIXTURE_DIR/forwarded.mark"
  rm -f "$mark"
  _record_arg() { printf '%s\n' "$1" > "$mark"; return 0; }
  critical "forwarded" _record_arg "value under test"
  unset -f _record_arg
  if [[ "$(cat "$mark" 2>/dev/null)" == "value under test" ]]; then
    pass "critical: forwards its arguments to the checked command"
  else
    fail "critical did not forward its argument: '$(cat "$mark" 2>/dev/null)'"
  fi
}

# Given: a writable directory
# When:  _is_writable and _is_readonly run on it
# Then:  both agree it is writable, and the probe file is removed
# Asserts: the inverse pair the two probes use for the mount checks.
test_writability_helpers_agree_and_leave_no_probe_file() {
  _reset_harness
  local dir="$FIXTURE_DIR/writable"
  mkdir -p "$dir"
  if _is_writable "$dir" && ! _is_readonly "$dir" && [[ ! -e "$dir/.dryrun_write_test" ]]; then
    pass "_is_writable and _is_readonly agree, and the probe file is cleaned up"
  else
    fail "writability helpers disagreed or left $dir/.dryrun_write_test behind"
  fi
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

run_test test_critical_pass_moves_no_counter
run_test test_critical_fail_counts_against_its_layer
run_test test_record_isolates_layers
run_test test_record_writes_identity_and_extra_fields_in_order
run_test test_record_write_failure_warns_without_aborting
run_test test_summary_all_clear_returns_zero
run_test test_summary_warn_only_is_healthy_and_counted
run_test test_summary_critical_failure_returns_one
run_test test_critical_forwards_arguments
run_test test_writability_helpers_agree_and_leave_no_probe_file

test_done test_dry_run_harness.sh
