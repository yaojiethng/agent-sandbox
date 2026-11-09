#!/usr/bin/env bash
# tests/test_mutations_runner.sh
# Tests for the mutation tier (scripts/mutations_run.sh):
# the verdict semantics (proven / survived / no-op), the stale-row exclusion
# from the survivor count, the register row shape, and the subject-file
# restore after every run.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/libs/test_common.sh"
MUTATE_RUNNER="$TEST_DIR/../scripts/mutations_run.sh"

# make_fixture
#   Builds a fixture root: two subjects (one whose guard a mutation removes,
#   one whose cosmetic value a mutation changes), their test files, the
#   catalog rows (proven / survived / stale), and the subject map. Prints the
#   fixture root.
make_fixture() {
  local root
  root="$(get_fixture_dir)"
  mkdir -p "$root/scripts" "$root/tests" "$root/mutations"
  cat > "$root/scripts/fake.sh" <<'EOF'
#!/usr/bin/env bash
guard() {
  if [[ "${1:-}" == "blocked" ]]; then
    return 1
  fi
  return 0
}
EOF

  cat > "$root/scripts/fake2.sh" <<'EOF'
#!/usr/bin/env bash
LABEL="start"
EOF

  cat > "$root/scripts/fake.mjs" <<'EOF'
export function guard(value) {
  if (value === "blocked") return false;
  return true;
}
EOF

  cat > "$root/tests/test_fake_mjs.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node --input-type=module -e "import('$D/scripts/fake.mjs').then((m) => { if (m.guard('blocked') !== false) { console.error('guard failed to refuse'); process.exit(1); } })" || exit 1
EOF
  chmod +x "$root/tests/test_fake_mjs.sh"

  cat > "$root/tests/test_fake.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$D/scripts/fake.sh"
guard blocked
[[ $? -eq 1 ]] || { echo "guard failed to refuse"; exit 1; }
exit 0
EOF

  cat > "$root/tests/test_fake2.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$D/scripts/fake2.sh" ]] || { echo "fake2 missing"; exit 1; }
exit 0
EOF
  chmod +x "$root/tests/test_fake.sh" "$root/tests/test_fake2.sh"

  printf 'scripts/fake.sh\ttest_fake.sh test_fake2.sh\nscripts/fake2.sh\ttest_fake2.sh\nscripts/fake.mjs\ttest_fake_mjs.sh\n' > "$root/subjects.map"

  cat > "$root/catalog.jsonl" <<EOF
{"schema":1,"kind":"mutation-catalog"}
{"id":1,"source":"fixture","name":"proven-row","subject":"scripts/fake.sh","old":"  if [[ \"\${1:-}\" == \"blocked\" ]]; then","new":"  if false; then"}
{"id":2,"source":"fixture","name":"survived-row","subject":"scripts/fake2.sh","old":"LABEL=\"start\"","new":"LABEL=\"mutated\""}
{"id":3,"source":"fixture","name":"stale-row","subject":"scripts/fake.sh","old":"text that appears nowhere","new":"irrelevant"}
{"id":4,"source":"fixture","name":"module-row","subject":"scripts/fake.mjs","old":"  if (value === \"blocked\") return false;","new":"  if (false) return false;"}
{"id":5,"source":"fixture","name":"unparseable-module","subject":"scripts/fake.mjs","old":"  return true;","new":"  return true(;"}
EOF
  printf '%s\n' "$root"
}

run_mutation_tier() {
  local root="$1" out="$2" strict="${3:-0}" required="${4:-}" budget="${5:-120}"
  MUTATIONS_ROOT="$root" \
  MUTATIONS_CATALOG="$root/catalog.jsonl" \
  MUTATIONS_OUTPUT="$root/mutations/out.jsonl" \
  MUTATIONS_BUDGET="$budget" \
  MUTATIONS_PER_TEST=10 \
  MUTATIONS_STRICT="$strict" \
  MUTATIONS_REQUIRED_SUBJECTS="$required" \
  MUTATIONS_SUBJECT_MAP="$root/subjects.map" \
    bash "$MUTATE_RUNNER" > "$out" 2>&1
  echo $?
}

test_verdicts_and_register() {
  local root out rc
  root="$(make_fixture)"
  cp "$root/scripts/fake.sh" "$root/fake.orig"
  cp "$root/scripts/fake2.sh" "$root/fake2.orig"
  out="$root/run.out"
  rc="$(run_mutation_tier "$root" "$out")"
  assert_eq_num "$rc" 0 "runner exits 0 even with survivors"
  local output
  output="$(cat "$out")"
  assert_contains "$output" "proven" "the bit against fake.sh is reported proven"
  assert_contains "$output" "survived" "the unchanged fake2.sh behaviour is reported survived"
  assert_contains "$output" "no-op" "the non-matching row is reported no-op"
  assert_contains "$output" "rows:      5" "all five rows accounted"
  assert_contains "$output" "proven:    2" "a shell mutation and a module mutation both bite"
  assert_contains "$output" "survived:  1" "one survivor"
  assert_contains "$output" "no-op:     2" "a stale row and an unparseable mutant are no-ops"
  assert_contains "$output" "mutant does not parse" "the unparseable mutant names the reason"
  assert_contains "$output" "skipped:   0" "budget did not skip"

  # The register holds the survivor (open) and the no-op (stale), not proven.
  assert_file_exists "$root/mutations/out.jsonl" "register written"
  local register
  register="$(cat "$root/mutations/out.jsonl")"
  assert_contains "$register" '"status":"open"' "the survivor is an open finding"
  assert_contains "$register" '"status":"stale"' "the no-op is a stale finding"
  assert_contains "$register" '"name":"survived-row"' "survivor row names the mutation"
  assert_contains "$register" '"name":"stale-row"' "stale row names the mutation"
  assert_not_contains "$register" "proven-row" "a proven mutation is not a finding"
  assert_eq "$(printf '%s\n' "$register" | grep -c '^{')" "3" "register holds the survivor and both no-ops"

  # The subjects are restored after the run.
  assert_eq "$(cat "$root/scripts/fake.sh")" "$(cat "$root/fake.orig")" "fake.sh restored"
  assert_eq "$(cat "$root/scripts/fake2.sh")" "$(cat "$root/fake2.orig")" "fake2.sh restored"
  assert_file_exists "$MUTATE_RUNNER" "runner script present"
}

test_help_and_arg_rejection() {
  local out rc
  out="$(bash "$MUTATE_RUNNER" --help 2>&1)"; rc=$?
  assert_eq_num "$rc" 0 "--help exits 0"
  assert_contains "$out" "mutation tier" "--help names the tier"
  out="$(bash "$MUTATE_RUNNER" --bogus 2>&1)"; rc=$?
  assert_eq_num "$rc" 1 "an unknown option is rejected"
}

test_strict_mode_fails_on_findings() {
  local root out rc
  root="$(make_fixture)"
  out="$root/run-strict.out"
  rc="$(run_mutation_tier "$root" "$out" 1)"
  assert_eq_num "$rc" 1 "strict mode fails on a survivor or no-op"
  assert_contains "$(cat "$out")" "Mutation gate: findings present" "strict mode names the gate failure"
}

test_strict_mode_fails_on_skipped_rows() {
  local root out rc
  root="$(make_fixture)"
  out="$root/run-strict-skip.out"
  rc="$(run_mutation_tier "$root" "$out" 1 "" 0)"
  assert_eq_num "$rc" 1 "strict mode fails when the budget skips rows"
  assert_contains "$(cat "$out")" "Mutation gate: findings present" "strict mode names the skipped-row failure"
}

# Given: a required subject and a survivor in another subject
# When:  the runner applies the required-subject filter
# Then:  the survivor is reported but does not fail the run
test_unrequired_survivor_stays_report_only() {
  local root out rc
  root="$(make_fixture)"
  cat > "$root/clean-catalog.jsonl" <<'EOF'
{"schema":1,"kind":"mutation-catalog"}
{"id":1,"source":"fixture","name":"proven-row","subject":"scripts/fake.sh","old":"  if [[ \"${1:-}\" == \"blocked\" ]]; then","new":"  if false; then"}
{"id":2,"source":"fixture","name":"survived-row","subject":"scripts/fake2.sh","old":"LABEL=\"start\"","new":"LABEL=\"mutated\""}
EOF
  out="$root/run-required-clean.out"
  MUTATIONS_ROOT="$root" \
  MUTATIONS_CATALOG="$root/clean-catalog.jsonl" \
  MUTATIONS_OUTPUT="$root/mutations/required-clean.jsonl" \
  MUTATIONS_BUDGET=120 \
  MUTATIONS_PER_TEST=10 \
  MUTATIONS_STRICT=0 \
  MUTATIONS_REQUIRED_SUBJECTS='^scripts/fake\.sh$' \
  MUTATIONS_SUBJECT_MAP="$root/subjects.map" \
    bash "$MUTATE_RUNNER" > "$out" 2>&1
  rc=$?
  assert_eq_num "$rc" 0 "a clean required subject passes with no unrelated findings"
  assert_contains "$(cat "$out")" "required findings: 0" "the required findings count is reported"
}

# Given: a survivor in the required subject set
# When:  the runner applies the required-subject filter
# Then:  the survivor fails the run
test_required_subject_fails_on_finding() {
  local root out rc
  root="$(make_fixture)"
  out="$root/run-required-fail.out"
  rc="$(run_mutation_tier "$root" "$out" 0 '^scripts/fake2\.sh$')"
  assert_eq_num "$rc" 1 "a survivor in the required subject fails the run"
  assert_contains "$(cat "$out")" "required subjects have findings" "the required-subject failure is named"
}

# Given: a stale row in the required subject set
# When:  the runner applies the required-subject filter
# Then:  the no-op fails the run instead of only being reported
test_required_subject_fails_on_stale_row() {
  local root out rc
  root="$(make_fixture)"
  out="$root/run-required-stale.out"
  rc="$(run_mutation_tier "$root" "$out" 0 '^scripts/fake\.sh$')"
  assert_eq_num "$rc" 1 "a stale row in the required subject fails the run"
  assert_contains "$(cat "$out")" "no-op" "the stale row is reported as a no-op"
  assert_contains "$(cat "$out")" "required findings: 1" "the required no-op is counted"
  assert_contains "$(cat "$out")" "required subjects have findings" "the required-subject failure is named"
}

# Given: a required row the budget skips
# When:  the runner applies the required-subject filter
# Then:  the skipped required row fails the run
test_required_subject_skip_fails() {
  local root out rc
  root="$(make_fixture)"
  cat > "$root/clean-catalog.jsonl" <<'EOF'
{"schema":1,"kind":"mutation-catalog"}
{"id":1,"source":"fixture","name":"proven-row","subject":"scripts/fake.sh","old":"  if [[ \"${1:-}\" == \"blocked\" ]]; then","new":"  if false; then"}
EOF
  out="$root/run-required-skip.out"
  MUTATIONS_ROOT="$root" \
  MUTATIONS_CATALOG="$root/clean-catalog.jsonl" \
  MUTATIONS_OUTPUT="$root/mutations/required-skip.jsonl" \
  MUTATIONS_BUDGET=0 \
  MUTATIONS_PER_TEST=10 \
  MUTATIONS_STRICT=0 \
  MUTATIONS_REQUIRED_SUBJECTS='^scripts/fake\.sh$' \
  MUTATIONS_SUBJECT_MAP="$root/subjects.map" \
    bash "$MUTATE_RUNNER" > "$out" 2>&1
  rc=$?
  assert_eq_num "$rc" 1 "a skipped required row fails the run"
  assert_contains "$(cat "$out")" "required skipped: 1" "the skipped required count is reported"
}

# Given: a required subject later in the catalog
# When:  the runner starts
# Then:  the required rows run before the report-only rows
test_required_rows_run_before_report_only() {
  local root out rc order
  root="$(make_fixture)"
  out="$root/run-required-order.out"
  rc="$(run_mutation_tier "$root" "$out" 0 '^scripts/fake2\.sh$')"
  assert_eq_num "$rc" 1 "the required-order fixture reports the required survivor"
  order=$(awk '/^survived /{print NR; exit}' "$out")
  assert_eq "$order" "1" "the required row is applied before the report-only rows"
}

test_control_row_replays_the_unedited_suite() {
  local root out rc
  root="$(make_fixture)"
  out="$root/run-control.out"
  cat > "$root/control-catalog.jsonl" <<'EOF'
{"schema":1,"kind":"mutation-catalog"}
{"id":90,"name":"control-row","subject":"scripts/fake.sh","control":true}
EOF
  MUTATIONS_ROOT="$root" \
  MUTATIONS_CATALOG="$root/control-catalog.jsonl" \
  MUTATIONS_OUTPUT="$root/mutations/control.jsonl" \
  MUTATIONS_BUDGET=120 \
  MUTATIONS_PER_TEST=10 \
  MUTATIONS_STRICT=1 \
  MUTATIONS_REQUIRED_SUBJECTS='^scripts/fake\.sh$' \
  MUTATIONS_SUBJECT_MAP="$root/subjects.map" \
    bash "$MUTATE_RUNNER" > "$out" 2>&1
  rc=$?
  assert_eq_num "$rc" 0 "a green control row passes strict mode"
  assert_contains "$(cat "$out")" "control" "the control verdict is printed"
  assert_contains "$(cat "$out")" "control:   1" "the control count is reported"
  assert_contains "$(cat "$out")" "required findings: 0" "the green control row is in the required set"
}

test_setup
run_test test_verdicts_and_register
run_test test_help_and_arg_rejection
run_test test_strict_mode_fails_on_findings
run_test test_strict_mode_fails_on_skipped_rows
run_test test_unrequired_survivor_stays_report_only
run_test test_required_subject_fails_on_finding
run_test test_required_subject_fails_on_stale_row
run_test test_required_subject_skip_fails
run_test test_required_rows_run_before_report_only
run_test test_control_row_replays_the_unedited_suite
test_done test_mutations_runner
