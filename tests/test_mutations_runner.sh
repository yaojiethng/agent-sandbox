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

  printf 'scripts/fake.sh\ttest_fake.sh test_fake2.sh\nscripts/fake2.sh\ttest_fake2.sh\n' > "$root/subjects.map"

  cat > "$root/catalog.jsonl" <<EOF
{"schema":1,"kind":"mutation-catalog","last_updated":"fixture","count":3}
{"id":1,"source":"fixture","name":"proven-row","subject":"scripts/fake.sh","old":"  if [[ \"\${1:-}\" == \"blocked\" ]]; then","new":"  if false; then"}
{"id":2,"source":"fixture","name":"survived-row","subject":"scripts/fake2.sh","old":"LABEL=\"start\"","new":"LABEL=\"mutated\""}
{"id":3,"source":"fixture","name":"stale-row","subject":"scripts/fake.sh","old":"text that appears nowhere","new":"irrelevant"}
EOF
  printf '%s\n' "$root"
}

run_mutation_tier() {
  local root="$1" out="$2"
  MUTATIONS_ROOT="$root" \
  MUTATIONS_CATALOG="$root/catalog.jsonl" \
  MUTATIONS_OUTPUT="$root/mutations/out.jsonl" \
  MUTATIONS_BUDGET=120 \
  MUTATIONS_PER_TEST=10 \
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
  assert_contains "$output" "rows:      3" "all three rows accounted"
  assert_contains "$output" "proven:    1" "one proven"
  assert_contains "$output" "survived:  1" "one survivor"
  assert_contains "$output" "no-op:     1" "one no-op"
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
  assert_eq "$(printf '%s\n' "$register" | grep -c '^{')" "2" "register has exactly two rows"

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

test_setup
run_test test_verdicts_and_register
run_test test_help_and_arg_rejection
test_done test_mutations_runner