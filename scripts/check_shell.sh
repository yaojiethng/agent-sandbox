#!/usr/bin/env bash
# scripts/check_shell.sh
# ShellCheck gate over all tracked shell scripts (src/, scripts/, tests/).
# BLOCKING since handover 20260823-15: exits nonzero on any warning.
#
# Exit codes: 0 = no findings, 1 = findings OR the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# docs/development/bash-coding-conventions.md 3.2).
#
# History: baseline at introduction (20260823-07) was 31 warnings, held
# non-gating until cleared. Suppression policy: targeted `# shellcheck
# disable=SCxxxx` with a rationale comment -- never a blanket disable.
# Known intentional suppressions:
#   - SC2034 in draft_state.sh: printf -v dynamic assignment targets
#   - SC2064 in snapshot.sh: trap expansion-now is required because the
#     variable is function-local and must be baked into the trap body
#   - SC1090 on runtime-resolved source paths that are -f validated first
#   - SC2034/SC2154 where a variable is consumed by code a `source` or `eval`
#     introduces, which ShellCheck cannot trace (see each site's rationale)
#
# Invocation: one shellcheck run per file, in parallel, not a single batch
# invocation. A batch run treats the first file as "the script" and the rest
# as sourced libraries, which suppresses script-context warnings (SC2034/
# SC2154); the lint-duration study measured that mask on 134 of 135 files.
# Per-file checking is strict AND faster in parallel (the study measured ~1s
# at 16-way parallelism vs ~30s serial batch). When a per-file run surfaced
# findings the batch mask hid, the site was patched, never re-suppressed.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Fail closed: the gate cannot report "clean" when it never ran. A missing tool
# or an empty file set is a finding, not a pass.
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ShellCheck gate: shellcheck is not installed; cannot run the gate." >&2
  exit 1
fi

SCAN_DIRS=("$REPO_ROOT/src" "$REPO_ROOT/scripts" "$REPO_ROOT/tests")
# Test seam: a fixture root exercises the missing-directory and empty-file-set
# guards without disturbing the real scan.
if [[ -n "${SHELLCHECK_SCAN_ROOT:-}" ]]; then
  SCAN_DIRS=("$SHELLCHECK_SCAN_ROOT/src" "$SHELLCHECK_SCAN_ROOT/scripts" "$SHELLCHECK_SCAN_ROOT/tests")
fi

FILES=()
for d in "${SCAN_DIRS[@]}"; do
  if [[ ! -d "$d" ]]; then
    echo "ShellCheck gate: $d is missing; cannot determine the file set." >&2
    exit 1
  fi
done
while IFS= read -r F; do
  FILES+=("$F")
done < <(find "${SCAN_DIRS[@]}" -name '*.sh' -not -path '*/node_modules/*' | sort)

if (( ${#FILES[@]} == 0 )); then
  echo "ShellCheck gate: no shell files found under $REPO_ROOT; cannot run the gate." >&2
  exit 1
fi

# One shellcheck run per file, in parallel. Each worker writes its rc and
# output to a per-file temp file so the gate merges the results
# deterministically (no interleaved lines from concurrent processes).
OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/check_shell.XXXXXX") || exit 1
trap 'rm -rf "$OUT_DIR"' EXIT
i=0
for f in "${FILES[@]}"; do
  (
    out="$(shellcheck -S warning "$f" 2>&1)"; rc=$?
    printf '%s' "$out" > "$OUT_DIR/o.$i"
    printf '%d' "$rc" > "$OUT_DIR/rc.$i"
  ) &
  i=$((i + 1))
done
wait

# Directive prose-comment pass: a comment line whose first token after '#' is
# the tool name is parsed as a shellcheck directive (SC1072/SC1073). A prose
# line like `# shellcheck absent` silently becomes a directive the tool tries
# to parse, so it is flagged on its own rather than left to the parse-error
# wording. A real directive (`(disable|enable|source)=`) is allowed. One grep
# per file in parallel, merged into per-file temp files like the shellcheck
# workers.
DIRECTIVE_GREP='^[[:space:]]*#[[:space:]]*shellcheck([[:space:]]|$)'
DIRECTIVE_GREP_ALLOW='shellcheck[[:space:]]+(disable|enable|source)='
DIR_PROSE=0
j=0
for f in "${FILES[@]}"; do
  (
    hits="$(grep -nE "$DIRECTIVE_GREP" "$f" 2>/dev/null | grep -vE "$DIRECTIVE_GREP_ALLOW")"; rc=$?
    [[ -n "$hits" ]] && printf '%s\n' "$hits" > "$OUT_DIR/d.$j"
    printf '%d' "$rc" > "$OUT_DIR/drc.$j"
  ) &
  j=$((j + 1))
done
wait
for (( k = 0; k < ${#FILES[@]}; k++ )); do
  [[ -s "$OUT_DIR/d.$k" ]] || continue
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    DIR_PROSE=$((DIR_PROSE + 1))
    file=$(printf '%s' "${FILES[$k]}" | sed "s|$REPO_ROOT/||")
    printf '%s:%s\n' "$file" "$line"
  done < "$OUT_DIR/d.$k"
done

WARNINGS=0
worst_rc=0
directive=false
for (( k = 0; k < ${#FILES[@]}; k++ )); do
  rcf="$OUT_DIR/rc.$k"
  [[ -f "$rcf" ]] || continue
  rc=$(<"$rcf")
  (( rc > worst_rc )) && worst_rc=$rc
  cnt=$(grep -c '\^--' "$OUT_DIR/o.$k" || true)
  WARNINGS=$((WARNINGS + cnt))
  if (( rc != 0 )) && grep -q "Couldn't parse this shellcheck directive" "$OUT_DIR/o.$k"; then
    directive=true
  fi
done

# Print each file's findings in a stable order for the failure paths.
dump_output() {
  local k
  for (( k = 0; k < ${#FILES[@]}; k++ )); do
    [[ -s "$OUT_DIR/o.$k" ]] || continue
    printf '%s\n' "$(<"$OUT_DIR/o.$k")"
    printf '\n'
  done
}

# The exit code is a verdict: a clean run with no findings. Two things can make
# that false -- findings the marker scan did not parse, and a tool that could
# not run. Both fail the gate; the wording distinguishes them. `worst_rc` is the
# worst exit code across the per-file runs, mirroring the single-run semantics.
echo "ShellCheck (-S warning): $WARNINGS warnings across ${#FILES[@]} files"
if (( worst_rc > 1 )); then
  dump_output
  echo "ShellCheck gate: shellcheck exited $worst_rc; cannot run the gate." >&2
  exit 1
fi
# A comment whose first token is the tool name is parsed as a directive, which
# the tool reports as SC1072/SC1073 with its own wording. Those codes alone
# cover every parse failure, so match the wording: an ordinary syntax error must
# fall through to the generic findings message rather than receive a remedy that
# cannot work.
if $directive; then
  dump_output
  echo "ShellCheck gate: a comment starting with the word 'shellcheck' is parsed as a directive." >&2
  echo "  Reword the line so the tool name is not the first token after '#'." >&2
  exit 1
fi
# The prose-comment pass reports any comment whose first token is the tool name
# unless it is a real disable= / enable= / source= directive. It is an
# independent verdict from the shellcheck parse failure (a line the tool would
# tolerate but an author meant as prose still trips the rule).
if (( DIR_PROSE > 0 )); then
  echo "shellcheck-directive: $DIR_PROSE prose comment(s) whose first token is 'shellcheck'." >&2
  echo "  Reword the line so the tool name is not the first token after '#'." >&2
  exit 1
fi
if (( worst_rc != 0 || WARNINGS > 0 )); then
  dump_output
  echo ""
  echo "Blocking gate: fix the findings above (targeted directives allowed
with rationale for known false-positive classes; see file header)." >&2
  exit 1
fi

echo "Clean (${SECONDS}s)"
exit 0
