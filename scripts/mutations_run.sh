#!/usr/bin/env bash
# scripts/mutations_run.sh
# The mutation tier: replays the mutation catalog against the tree.
#
# The read-through's bite sweeps (2026-09-24/25) are kept here as a maintained
# catalog (`tests/mutations/catalog.jsonl`), one row per mutation. Each row
# names the subject file, the old text to replace (first occurrence, exact
# bytes, multi-line safe), and the replacement. The runner applies each
# mutation to the subject, checks the mutation is real (mutant differs, `bash
# -n` passes), runs the subject's own test files, and records the verdict.
#
# Verdicts:
#   PROVEN   - the mutation bit: a targeted test failed against the mutant.
#   SURVIVED - all targeted tests passed against the mutant; the line it
#              mutated is unpinned. A survivor is a finding.
#   NO-OP    - the old text no longer matches the subject. Reported and
#              excluded from the survivor count. Makes catalog staleness
#              visible; refresh the catalog when a NO-OP surge appears.
#
# The register: survivors and no-ops are written to a dated jsonl findings
# register under `tests/mutations/runs/` (collect-then-process; this run never
# terminates on a survivor). Proven rows live in the summary only. The
# register uses the findings-register status vocabulary: a survivor is `open`,
# a no-op is `stale`.
#
# Configuration (env):
#   MUTATIONS_CATALOG   catalog path (default tests/mutations/catalog.jsonl)
#   MUTATIONS_OUTPUT    register path (default <date>-mutation_run.jsonl in
#                       tests/mutations/runs/)
#   MUTATIONS_BUDGET    total budget in seconds (default 900); rows beyond it
#                       are skipped and reported
#   MUTATIONS_PER_TEST  per-test deadline in seconds (default 60)
#   MUTATIONS_ROOT      directory the catalog's subject paths resolve against
#                       (default the repo root; test seam)
#   MUTATIONS_SUBJECT_MAP  file of `subject<TAB>test-file [test-file...]`
#                       lines merged over the built-in subject map (test seam)
#
# Run through the suite runner with `MUTATION=1 bash scripts/run_tests.sh`,
# or directly with `bash scripts/mutations_run.sh`.

set -uo pipefail

MUTATIONS_ROOT="${MUTATIONS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MUTATIONS_CATALOG="${MUTATIONS_CATALOG:-$MUTATIONS_ROOT/tests/mutations/catalog.jsonl}"
MUTATIONS_RUN_DIR="$MUTATIONS_ROOT/tests/mutations/runs"
MUTATIONS_BUDGET="${MUTATIONS_BUDGET:-900}"
MUTATIONS_PER_TEST="${MUTATIONS_PER_TEST:-60}"
SECONDS=0

# The subject-to-tests lookup. The test-file naming rule ("the file and the
# unit", testing_policy.md) is the source: each test file is named for the
# subject it covers. Where a subject has more than one suite, list them all.
declare -A SUBJECT_TESTS=(
  [scripts/agent-sandbox.sh]="test_dispatch.sh"
  [scripts/build.sh]="test_build_context.sh"
  [scripts/install.sh]="test_install.sh"
  [scripts/resume_agent.sh]="test_resume_list.sh test_resume.sh"
  [scripts/run_agent.sh]="test_run_agent.sh"
  [scripts/stop.sh]="test_stop_fail_closed.sh test_trace_stop.sh"
  [scripts/workflows/apply.sh]="test_apply_workflow.sh test_rename_apply.sh"
  [scripts/workflows/confirm.sh]="test_confirm_workflow.sh"
  [scripts/workflows/draft.sh]="test_draft_workflow.sh test_draft_state.sh"
  [src/build/compose.sh]="test_compose_wait.sh test_trace_compose_gen.sh"
  [src/capability/entrypoint.sh]="test_capability_entrypoint_mount.sh test_dry_run_probe.sh"
  [src/capability/git-hooks/pre-commit.sh]="test_git_hook.sh"
  [src/capability/seed_volume.sh]="test_seed_volume.sh"
  [src/capability/snapshot.sh]="test_snapshot_host.sh"
)

# Optional map overlay from MUTATIONS_SUBJECT_MAP: lines of
# `subject<TAB>test-file [test-file ...]` merged over the built-in map.
# The test suite uses it to point the runner at fixture subjects.
if [[ -n "${MUTATIONS_SUBJECT_MAP:-}" && -f "$MUTATIONS_SUBJECT_MAP" ]]; then
  while IFS=$'\t' read -r _subj _tests_line; do
    [[ -n "$_subj" ]] && SUBJECT_TESTS["$_subj"]="$_tests_line"
  done < "$MUTATIONS_SUBJECT_MAP"
fi

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}"
  exit 0
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; fi
if [[ $# -gt 0 ]]; then
  echo "Unknown option: $1" >&2
  echo "This script takes no arguments; configure it with env vars." >&2
  exit 1
fi

# decode_row ROW_JSON
#   Emits the row's fields NUL-separated in order: id, name, subject, old,
#   new. NUL separates because old/new may contain newlines.
decode_row() {
  printf '%s' "$1" | perl -MJSON::PP=decode_json -0777 -ne '
    $r = decode_json($_);
    print "$r->{id}\0$r->{name}\0$r->{subject}\0$r->{old}\0$r->{new}\0";'
}

# first_index NEEDLE FILE
#   Prints the byte index of the first exact occurrence of NEEDLE in FILE,
#   or nothing when absent.
first_index() {
  local needle="$1" file="$2"
  NEEDLE="$needle" perl -0777 -ne 'if (($i = index($_, $ENV{NEEDLE})) >= 0) { print "$i\n" }' "$file"
}

# apply_mutation FILE OLD NEW
#   Replaces the first exact occurrence of OLD in FILE with NEW. The literal
#   passes through the environment so perl cannot interpolate it.
apply_mutation() {
  local file="$1" old="$2" new="$3"
  OLD="$old" NEW="$new" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$file"
}

# run_targeted_tests SUBJECT
#   Runs the subject's mapped test files in order. On the first failing file,
#   prints the failure reason lines and the file name to stdout and returns
#   that file's rc. Returns 0 when all pass. Returns 99 when no mapped suite
#   exists or the mapped file is missing.
run_targeted_tests() {
  local subject="$1"
  local tests="${SUBJECT_TESTS[$subject]:-}"
  local t rc
  if [[ -z "$tests" ]]; then
    echo "subject has no mapped test suite" >&2
    return 99
  fi
  for t in $tests; do
    local test_file="$MUTATIONS_ROOT/tests/$t"
    [[ -f "$test_file" ]] || {
      echo "mapped test missing: $test_file" >&2
      echo "$t"
      return 99
    }
    local out
    out=$(timeout "$MUTATIONS_PER_TEST" bash "$test_file" 2>&1)
    rc=$?
    if [[ $rc -ne 0 ]]; then
      printf '%s\n' "$out" | grep -E "^  FAIL:|^ERROR" | head -3 | sed 's/^/           /'
      echo "$t"
      return "$rc"
    fi
  done
  return 0
}

# run_mutation ROW_JSON
#   Applies one mutation and echoes the bare verdict on its final line:
#   proven | survived | no-op.
run_mutation() {
  local row="$1"
  local id subject old new
  local -a fields
  mapfile -d '' -t fields < <(decode_row "$row")
  id="${fields[0]}"; subject="${fields[2]}"
  old="${fields[3]}"; new="${fields[4]}"
  local verdict=proven reason=""
  local subject_file="$MUTATIONS_ROOT/$subject"
  local backup="$subject_file.mutation-bak"
  if [[ ! -f "$subject_file" ]]; then
    verdict=no-op; reason="subject file missing"
  elif [[ -z "$(first_index "$old" "$subject_file")" ]]; then
    verdict=no-op; reason="old text not found in subject"
  else
    cp "$subject_file" "$backup"
    apply_mutation "$subject_file" "$old" "$new"
    if ! bash -n "$subject_file" 2>/dev/null; then
      verdict=no-op; reason="mutant fails bash -n"
    elif cmp -s "$subject_file" "$backup"; then
      verdict=no-op; reason="mutation left the file unchanged"
    else
      local test_failed rc
      test_failed="$(run_targeted_tests "$subject")"
      rc=$?
      if [[ $rc -eq 99 ]]; then
        verdict=no-op; reason="cannot run the target suite: ${test_failed:-no mapped suite}"
      elif [[ $rc -ne 0 ]]; then
        verdict=proven; reason="$test_failed"
      else
        verdict=survived
      fi
    fi
    cp "$backup" "$subject_file"
    rm -f "$backup"
  fi
  printf '%-9s %-5s %-45s %s\n' "$verdict" "$id" "$subject" "$reason"
  echo "$verdict"
}

main() {
  mkdir -p "$MUTATIONS_RUN_DIR" || return 1
  local output="${MUTATIONS_OUTPUT:-$MUTATIONS_RUN_DIR/$(date +%Y%m%d-%H%M%S)-mutation_run.jsonl}"
  local rows_count=0 proven=0 survived=0 noop=0 skipped=0
  local row
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    rows_count=$((rows_count + 1))
    if (( SECONDS >= MUTATIONS_BUDGET )); then
      skipped=$((skipped + 1))
      continue
    fi
    local -a fields
    mapfile -d '' -t fields < <(decode_row "$row")
    local out verdict
    out="$(run_mutation "$row")"
    verdict="${out##*$'\n'}"
    printf '%s\n' "${out%$'\n'*}"
    case "$verdict" in
      proven)   proven=$((proven + 1));;
      survived) survived=$((survived + 1))
        printf '{"id":%s,"status":"open","name":"%s","verdict":"survived","subject":"%s"}\n' "${fields[0]}" "${fields[1]}" "${fields[2]}" >> "$output";;
      *)        noop=$((noop + 1))
        printf '{"id":%s,"status":"stale","name":"%s","verdict":"no-op","subject":"%s"}\n' "${fields[0]}" "${fields[1]}" "${fields[2]}" >> "$output";;
    esac
  done < <(grep -v '"schema"' "$MUTATIONS_CATALOG")
  echo
  echo "Mutation run complete in $((SECONDS))s:"
  echo "  rows:      $rows_count"
  echo "  proven:    $proven"
  echo "  survived:  $survived"
  echo "  no-op:     $noop"
  echo "  skipped:   $skipped"
  echo "  register:  $output"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi