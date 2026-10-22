#!/usr/bin/env bash
# scripts/replay_criteria.sh
# Replays the Verification cell of every acceptance-criteria row in the live
# handovers, so a mark is compared with what its own row says decides it
# rather than with a reading of the prose.
#
# A row is a line of the criteria table whose Result field carries a mark.
# The classifier (scripts/lint/criteria-form.mjs) decides whether the
# Verification cell names one command, one or more paths, a command plus text
# it does not check (`mixed`), or prose. Only `command` and `path` cells are
# decidable, and only a `[x]` row asserts a claim; everything else is
# reported as unverified.
#
# Isolation: every run happens in one throwaway worktree cut from HEAD, one
# command at a time, and the worktree is removed on every exit path. A cell
# that would write, install or change git state is refused before it runs;
# the deny list is the only thing standing between a handover's prose and the
# machine, so it is applied to the whole cell, not to its first word. `>` is
# on it, so a redirect of any kind refuses the row rather than leaving the
# worktree the only intended write.
#
# Modes: --report (the default) changes nothing and exits 0 once it ran;
# --fail-on-failures additionally exits 1 when any row holds a mark whose own
# command contradicts it. Exit codes carry a verdict, never a count (see
# docs/development/bash-coding-conventions.md 3.2).
#
# Flags: --root <dir> (default: this repository), --timeout <seconds>
# (default 120, the bound on one command), --only <glob> (match the handover
# file name).
#
# Test seam: --root points the scan at a fixture root holding its own
# devlog/handovers/ and a git repository with a HEAD commit.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLASSIFIER="$REPO_ROOT/scripts/lint/criteria-form.mjs"

MODE="report"
ROOT="$REPO_ROOT"
TIMEOUT=120
ONLY=""

while (( $# > 0 )); do
  case "$1" in
    --report) MODE="report"; shift ;;
    --fail-on-failures) MODE="fail"; shift ;;
    --root) ROOT="${2:-}"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --timeout=*) TIMEOUT="${1#--timeout=}"; shift ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --only=*) ONLY="${1#--only=}"; shift ;;
    *)
      echo "replay-criteria: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for tool in node jq git timeout; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "replay-criteria: $tool is not on PATH; cannot run the replay." >&2
    exit 1
  fi
done

if [[ ! -f "$CLASSIFIER" ]]; then
  echo "replay-criteria: $CLASSIFIER is missing; cannot classify a row." >&2
  exit 1
fi

if [[ ! -d "$ROOT/devlog/handovers" ]]; then
  echo "replay-criteria: $ROOT/devlog/handovers is missing; nothing to replay." >&2
  exit 1
fi

if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]] || (( TIMEOUT < 1 )); then
  echo "replay-criteria: --timeout needs a whole number of seconds, got: $TIMEOUT" >&2
  exit 1
fi

# A cell is refused when it names an act that writes, installs or moves git
# state, and when it carries a redirect. The pattern matches the act anywhere
# in the cell, because `a && rm b` is the same act as `rm b`.
DENY_RE='(^|[^[:alnum:]_])(git[[:space:]]+(commit|push|add|reset|checkout|merge|rebase|clean)|rm|mv|cp|mkdir|touch|tee|npm[[:space:]]+(i|install))([^[:alnum:]_]|$)|[>]'

WT_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/replay-criteria.XXXXXX")" || exit 1
WT="$WT_PARENT/wt"

cleanup() {
  if [[ -n "${WT:-}" ]]; then
    git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$WT_PARENT"
  return 0
}
trap cleanup EXIT INT TERM

if ! git -C "$ROOT" worktree add --detach "$WT" HEAD >/dev/null 2>&1; then
  echo "replay-criteria: cannot cut a worktree at HEAD under $ROOT; the replay needs a committed tree." >&2
  exit 1
fi

declare -A FORM_COUNT=()
declare -A VERDICT_COUNT=()
FORMS=(command path mixed prose)
VERDICTS=(holds would-pass FAILS-MARK unverified refused timeout)

TOTAL=0
for form in "${FORMS[@]}"; do FORM_COUNT[$form]=0; done
for verdict in "${VERDICTS[@]}"; do VERDICT_COUNT[$verdict]=0; done

FAILS_MARK_LINES=()

# The verdict for one row: the form decides whether it can run at all, the
# deny list whether it may, and the mark whether a run can contradict it.
verdict_of() {
  local form="$1" subject="$2" result="$3" expect="${4:-exit0}"
  local marked=0 open=0 rc=0 ok=1 path out=""

  if [[ "$result" == *"[x]"* || "$result" == *"[X]"* ]]; then
    marked=1
  elif [[ "$result" == *"[ ]"* ]]; then
    open=1
  fi

  case "$form" in
    command|path) ;;
    *)
      printf 'unverified'
      return 0
      ;;
  esac

  if (( !marked && !open )); then
    printf 'unverified'
    return 0
  fi

  if [[ "$form" == "command" ]] && [[ "$subject" =~ $DENY_RE ]]; then
    printf 'refused'
    return 0
  fi

  if [[ "$form" == "path" ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      path="${path#./}"
      if [[ "$path" == /* || ! -e "$WT/$path" ]]; then
        ok=0
        break
      fi
    done <<< "$subject"
    if (( ok )); then
      (( marked )) && printf 'holds' || printf 'would-pass'
    else
      (( marked )) && printf 'FAILS-MARK' || printf 'unverified'
    fi
    return 0
  fi

  # stdin is /dev/null: a cell may run a filter such as `grep -n` that reads
  # its input, and it must not consume the row stream this loop is reading.
  out="$( cd "$WT" && timeout "$TIMEOUT" bash -c "$subject" 2>/dev/null </dev/null )"
  rc=$?
  if (( rc == 124 )); then
    printf 'timeout'
    return 0
  fi
  # "prints nothing" is the one expectation that a non-zero exit satisfies,
  # because a filter exits 1 on no match. The row's own words decide which
  # reading applies, so the mark is compared with the claim it makes.
  if [[ "$expect" == "empty" ]]; then
    (( rc == 0 || rc == 1 )) && [[ -z "$out" ]] && ok=1 || ok=0
  else
    (( rc == 0 )) && ok=1 || ok=0
  fi
  if (( ok )); then
    (( marked )) && printf 'holds' || printf 'would-pass'
  else
    (( marked )) && printf 'FAILS-MARK' || printf 'unverified'
  fi
}

HANDOVERS=()
for file in "$ROOT"/devlog/handovers/*.md; do
  [[ -e "$file" ]] || continue
  base="${file##*/}"
  if [[ -n "$ONLY" ]]; then
    # shellcheck disable=SC2053  # --only is the caller's glob, so the pattern stays unquoted
    [[ "$base" == $ONLY ]] || continue
  fi
  HANDOVERS+=("$file")
done

for file in "${HANDOVERS[@]}"; do
  rel="${file#"$ROOT"/}"
  rows=0 holds=0 wouldpass=0 fails=0 unverified=0 refused=0 timeouts=0

  # The classifier prints its rows as NUL-delimited fields, so a command keeps
  # its tabs, quotes and backslashes, and a path subject keeps its newlines.
  while IFS= read -r -d '' lineno \
    && IFS= read -r -d '' form \
    && IFS= read -r -d '' subject \
    && IFS= read -r -d '' expect \
    && IFS= read -r -d '' criterion \
    && IFS= read -r -d '' result; do
    rows=$((rows + 1))
    verdict="$(verdict_of "$form" "$subject" "$result" "$expect")"
    case "$verdict" in
      holds) holds=$((holds + 1)) ;;
      would-pass) wouldpass=$((wouldpass + 1)) ;;
      FAILS-MARK) fails=$((fails + 1)) ;;
      refused) refused=$((refused + 1)) ;;
      timeout) timeouts=$((timeouts + 1)) ;;
      *) unverified=$((unverified + 1)) ;;
    esac
    FORM_COUNT[$form]=$(( ${FORM_COUNT[$form]:-0} + 1 ))
    VERDICT_COUNT[$verdict]=$(( ${VERDICT_COUNT[$verdict]:-0} + 1 ))
    if [[ "$verdict" == "FAILS-MARK" ]]; then
      FAILS_MARK_LINES+=("FAILS-MARK $rel:$lineno $criterion :: $subject")
    fi
  done < <(node "$CLASSIFIER" --json "$file" \
    | jq -j '.[] | "\(.lineno)\u0000\(.form)\u0000\(.subject)\u0000\(.expect)\u0000\(.criterion)\u0000\(.result)\u0000"')

  TOTAL=$((TOTAL + rows))
  printf '%s: %d row(s), holds=%d, fails-mark=%d, would-pass=%d, unverified=%d, refused=%d, timeout=%d\n' \
    "$rel" "$rows" "$holds" "$fails" "$wouldpass" "$unverified" "$refused" "$timeouts"
done

echo ""
printf 'Corpus by form:'
for form in "${FORMS[@]}"; do printf ' %s=%d' "$form" "${FORM_COUNT[$form]:-0}"; done
printf '\n'
printf 'Corpus by verdict:'
for verdict in "${VERDICTS[@]}"; do printf ' %s=%d' "$verdict" "${VERDICT_COUNT[$verdict]:-0}"; done
printf '\n'
echo ""

for line in "${FAILS_MARK_LINES[@]}"; do
  printf '%s\n' "$line"
done

printf 'replay-criteria: %d row(s), %d holds, %d fails-mark, %d unverified, %d refused\n' \
  "$TOTAL" "${VERDICT_COUNT[holds]:-0}" "${VERDICT_COUNT[FAILS-MARK]:-0}" \
  "${VERDICT_COUNT[unverified]:-0}" "${VERDICT_COUNT[refused]:-0}"

if [[ "$MODE" == "fail" ]] && (( ${VERDICT_COUNT[FAILS-MARK]:-0} > 0 )); then
  exit 1
fi
exit 0
