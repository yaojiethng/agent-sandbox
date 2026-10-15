#!/usr/bin/env bash
# libs/package_eval_snapshot.sh
#
# Package an eval snapshot: the session transcript as frozen, a complete
# repository bundle, the operator turn stream, the session facts, and a
# credential scan. A snapshot is self-contained, so an eval run months later
# needs nothing but the directory.
#
# Produces (under <to>/evals/<export-time>-<summary>-<session-id>/):
#   chat.jsonl            -- the live transcript at the moment of the copy
#   operator-turns.md     -- the user turns, in order, one block each
#   repo.bundle           -- every ref, complete rather than incremental
#   bundle-verify.txt     -- the verification output, naming the refs
#   commits.txt           -- the commit series from the base to HEAD
#   eval-point.json       -- the session facts a reader or a tool needs
#   credentials-scan.txt  -- pattern counts, never a matched value
#   .snapshot-status      -- the machine-readable half of the reply block
#
# The script writes no README.md. The graded moments of a session are a
# judgement about it, and the `package-eval-snapshot` prompt writes them.
#
# Usage (library):
#   package_eval_snapshot SANDBOX_DIR OUTPUT_DIR [BASELINE]
#
# Usage (direct):
#   package_eval_snapshot.sh --to=<dir> --snapshot-summary=<slug> [--baseline=<sha>]
#
# Flags (direct mode):
#   --to=<dir>             Base parent directory (required). The script creates
#                          <to>/evals/<ts>-<summary>-<session-id>/ beneath it.
#   --snapshot-summary     Required. 3 to 48 chars, lowercase snake_case. It
#                          names the snapshot directory.
#   --baseline=<sha>       Explicit base commit. Default: init_sha from
#                          SESSION_STATE. One of the two is required.
#
# Dependencies: git (the bundle and the series), jq (the transcript and the
# facts file). A missing jq is a finding, not an empty artefact.
#
# Exit codes: 0 = the snapshot is complete, 1 = it is not, with the failing
# input named on stderr. No count is encoded in the status.

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_self_dir/session_state.sh"
source "$_self_dir/routing.sh"
source "$_self_dir/cli.sh"

# Patterns the credential scan counts. A value is never printed, only a count
# per pattern, so a hit is a prompt to look rather than a leak.
_SNAPSHOT_CREDENTIAL_PATTERNS=(
  'sk-[A-Za-z0-9]{20,}'
  'sk-ant-[A-Za-z0-9_-]{20,}'
  'AIza[A-Za-z0-9_-]{20,}'
  'ghp_[A-Za-z0-9]{20,}'
  'xoxb-[A-Za-z0-9-]{10,}'
  'Bearer [A-Za-z0-9._-]{20,}'
  'ANTHROPIC_API_KEY=[A-Za-z0-9_-]{20,}'
  'OPENAI_API_KEY=[A-Za-z0-9_-]{20,}'
)

# =============================================================================
# usage  --  print help text
# =============================================================================

usage() {
  cat <<EOF
Usage: package_eval_snapshot.sh --to=<dir> --snapshot-summary=<slug> [--baseline=<sha>]

Packages an eval snapshot: the frozen transcript, a complete repository bundle,
the operator turn stream, the session facts and a credential scan.

Required:
  --to=<dir>              Base output directory. In container: --to=\$HOME/workspace/output
  --snapshot-summary      Required. 3 to 48 chars, lowercase snake_case.

Options:
  --baseline=<sha>        Explicit base commit (default: init_sha from SESSION_STATE)
EOF
}

# Only set strict mode when run directly, not when sourced.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
fi

# =============================================================================
# package_eval_snapshot_validate_summary  --  reject a summary that cannot name
#   a directory
#
# The summary becomes the snapshot directory name. The shape matches the
# packaging command's bundle summary so the two read alike, and a value that
# cannot name a directory is refused where it enters rather than after the
# artefacts have been written.
# =============================================================================
package_eval_snapshot_validate_summary() {
  local SUMMARY="${1:-}"

  if [[ -z "$SUMMARY" ]]; then
    echo "package_eval_snapshot: --snapshot-summary is required and must be snake_case" >&2
    _snapshot_summary_usage
    return 1
  fi

  # ${#SUMMARY} is quoted into a variable: the lib-contract gate's brace
  # counter stops at `#`, so an unquoted length expansion opens a brace it
  # never closes and the rest of the file reads as function body.
  local SLEN="${#SUMMARY}"
  if (( SLEN < 3 || SLEN > 48 )); then
    echo "package_eval_snapshot: --snapshot-summary must be 3 to 48 characters; got ${SLEN}" >&2
    _snapshot_summary_usage
    return 1
  fi

  if [[ ! "$SUMMARY" =~ ^[a-z0-9]+(_[a-z0-9]+)*$ ]]; then
    echo "package_eval_snapshot: --snapshot-summary must be lowercase snake_case" >&2
    echo "  Allowed: letters, digits, and single underscores between words" >&2
    echo "  Rejected: spaces, capitals, punctuation, a leading or trailing underscore" >&2
    _snapshot_summary_usage
    return 1
  fi

  return 0
}

_snapshot_summary_usage() {
  echo "" >&2
  echo "  Good: --snapshot-summary=instruction_surface_contract" >&2
  echo "  Good: --snapshot-summary=task_queue_primitive" >&2
  echo "  Bad:  --snapshot-summary=Session with names (spaces)" >&2
  echo "  Bad:  --snapshot-summary=snapshot (too vague to name a session)" >&2
  echo "" >&2
}

# =============================================================================
# snapshot_write_transcript  --  copy the live transcript
#
# The copy is byte-identical and point-in-time: the live file keeps growing
# after this runs, which is why the snapshot takes its own copy rather than
# pointing at the live path.
# =============================================================================
snapshot_write_transcript() {
  local SOURCE="${1:-}"
  local DEST="$2"

  if [[ -z "$SOURCE" ]]; then
    echo "package_eval_snapshot: PI_SESSION_FILE is unset; cannot copy a transcript" >&2
    return 1
  fi
  if [[ ! -f "$SOURCE" ]]; then
    echo "package_eval_snapshot: no transcript at $SOURCE" >&2
    return 1
  fi
  if ! cp "$SOURCE" "$DEST"; then
    echo "package_eval_snapshot: could not copy $SOURCE to $DEST" >&2
    return 1
  fi
  return 0
}

# =============================================================================
# snapshot_write_operator_turns  --  the user turns, in order
#
# The transcript is JSONL and its last line can be a partial write while the
# session runs. That line is dropped from the turn stream and reported in the
# facts file; the copy itself keeps every byte.
# =============================================================================
snapshot_write_operator_turns() {
  local JSONL="$1"
  local DEST="$2"
  local INCOMPLETE="$3"
  local WORK="$4"

  if ! command -v jq >/dev/null 2>&1; then
    echo "package_eval_snapshot: jq is not on PATH; cannot extract the operator turns" >&2
    return 1
  fi

  local INPUT="$JSONL"
  local incomplete=false
  if ! tail -n 1 "$JSONL" | jq empty >/dev/null 2>&1; then
    incomplete=true
    INPUT="$WORK/transcript-complete.jsonl"
    if ! sed '$d' "$JSONL" > "$INPUT"; then
      echo "package_eval_snapshot: could not drop the incomplete last line of $JSONL" >&2
      return 1
    fi
  fi

  local FILTER
  # --slurp: without it jq streams one document per line, so `to_entries`
  # numbers each line's own array and every turn reads as turn 1.
  FILTER='[ .[]
            | select(.message.role == "user")
            | (.message.content
               | if type == "array"
                 then (map(select(.type == "text") | .text) | join("\n"))
                 else (. // "")
                 end)
            | select(length > 0) ]
          | to_entries[]
          | "### Operator turn \(.key + 1)\n\n\(.value)\n"'

  if ! jq -s -r "$FILTER" "$INPUT" > "$DEST"; then
    echo "package_eval_snapshot: jq could not read the transcript at $INPUT" >&2
    return 1
  fi

  printf '%s' "$incomplete" > "$INCOMPLETE"
  return 0
}

# =============================================================================
# snapshot_write_bundle  --  every ref, complete
#
# No prerequisites are passed, so the bundle carries the whole history and an
# eval can clone it with nothing else. The verification output ships beside it
# so a reader sees which refs it carries without running git.
# =============================================================================
snapshot_write_bundle() {
  local SANDBOX_DIR="$1"
  local BUNDLE="$2"
  local VERIFY="$3"

  if ! git -C "$SANDBOX_DIR" bundle create "$BUNDLE" --all >/dev/null 2>&1; then
    echo "package_eval_snapshot: git bundle create failed in $SANDBOX_DIR; the snapshot is incomplete" >&2
    return 1
  fi
  if ! git bundle verify "$BUNDLE" > "$VERIFY" 2>&1; then
    echo "package_eval_snapshot: the bundle at $BUNDLE does not verify; the snapshot is incomplete" >&2
    return 1
  fi
  return 0
}

# =============================================================================
# snapshot_write_commits  --  the series from the base to HEAD
#
# An empty series is a legitimate answer: a snapshot may be taken before any
# commit lands. A git failure is not, and is named.
# =============================================================================
snapshot_write_commits() {
  local SANDBOX_DIR="$1"
  local BASE="$2"
  local DEST="$3"

  if ! git -C "$SANDBOX_DIR" log --oneline "${BASE}..HEAD" > "$DEST"; then
    echo "package_eval_snapshot: git log ${BASE}..HEAD failed in $SANDBOX_DIR" >&2
    return 1
  fi
  return 0
}

# =============================================================================
# _snapshot_count_matches  --  count a pattern, and tell the two failures apart
#
# grep exits 1 when nothing matched, which is a legitimate zero, and 2 or more
# when the read itself failed, which is not. The count is printed; the caller
# decides what a failed read means.
# =============================================================================
_snapshot_count_matches() {
  local PATTERN="$1"
  local FILE="$2"
  local OUT=""
  local RC=0

  OUT=$(grep -c -E -- "$PATTERN" "$FILE") || RC=$?
  case "$RC" in
    0) printf '%s' "$OUT" ;;
    1) printf '0' ;;
    *) echo "package_eval_snapshot: the credential scan could not read $FILE (grep status $RC)" >&2; return 1 ;;
  esac
  return 0
}

# =============================================================================
# snapshot_scan_credentials  --  counts per pattern, never a value
#
# The scan never refuses. The transcript of the run that scans it holds the
# pattern text itself, so a refusal would fire on its own command line from the
# first run onward. The report says as much, and the prompt reads the hits.
# =============================================================================
snapshot_scan_credentials() {
  local SOURCE="$1"
  local DEST="$2"
  local TOTAL=0
  local PATTERN COUNT

  {
    echo "# Credential scan of chat.jsonl"
    echo "# Counts only: a matched value is never printed."
    echo "# A hit on a pattern this scan writes traces to the scan's own command line or"
    echo "# to this report, because the transcript holds the run that produced both."
    echo "#"
    echo "# count	pattern"
  } > "$DEST"

  for PATTERN in "${_SNAPSHOT_CREDENTIAL_PATTERNS[@]}"; do
    if ! COUNT=$(_snapshot_count_matches "$PATTERN" "$SOURCE"); then
      return 1
    fi
    TOTAL=$(( TOTAL + COUNT ))
    printf '%s\t%s\n' "$COUNT" "$PATTERN" >> "$DEST"
  done

  printf '#\n# total\t%s\n' "$TOTAL" >> "$DEST"
  printf '%s' "$TOTAL"
  return 0
}

# =============================================================================
# package_eval_snapshot  --  write every artefact
# =============================================================================
package_eval_snapshot() {
  local SANDBOX_DIR="$1"
  local OUTPUT_DIR="$2"
  local BASELINE="${3:-}"

  if [[ ! -d "$SANDBOX_DIR/.git" ]]; then
    echo "package_eval_snapshot: $SANDBOX_DIR is not a git repository; cannot bundle it" >&2
    return 1
  fi

  local TRANSCRIPT
  TRANSCRIPT="${PI_SESSION_FILE:-}"
  if [[ -z "$TRANSCRIPT" ]]; then
    echo "package_eval_snapshot: PI_SESSION_FILE is unset; there is no transcript to snapshot" >&2
    return 1
  fi
  if [[ ! -f "$TRANSCRIPT" ]]; then
    echo "package_eval_snapshot: no transcript at $TRANSCRIPT" >&2
    return 1
  fi

  local HARNESS_SESSION
  HARNESS_SESSION=$(session_state_read "$SANDBOX_DIR" session_id)

  # The base: the explicit flag wins, otherwise the recorded init_sha. Neither
  # present is a refusal, because a snapshot without a base cannot be scored
  # against anything.
  local RECORDED_INIT
  RECORDED_INIT=$(session_state_read "$SANDBOX_DIR" init_sha)
  local BASE="$BASELINE"
  if [[ -z "$BASE" ]]; then
    BASE="$RECORDED_INIT"
  fi
  if [[ -z "$BASE" ]]; then
    echo "package_eval_snapshot: no base commit: SESSION_STATE carries no init_sha and no --baseline was given" >&2
    return 1
  fi
  if ! git -C "$SANDBOX_DIR" cat-file -e "${BASE}^{commit}" 2>/dev/null; then
    echo "package_eval_snapshot: $BASE is not a commit in $SANDBOX_DIR" >&2
    return 1
  fi

  local BASELINE_MOVED=false
  if [[ -n "$RECORDED_INIT" && "$BASE" != "$RECORDED_INIT" ]]; then
    BASELINE_MOVED=true
  fi

  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"
  local WORK
  WORK="$OUTPUT_DIR/.work"
  mkdir -p "$WORK"

  if ! snapshot_write_transcript "$TRANSCRIPT" "$OUTPUT_DIR/chat.jsonl"; then
    return 1
  fi

  local TURNS_INCOMPLETE_FILE="$WORK/tail-incomplete"
  if ! snapshot_write_operator_turns "$OUTPUT_DIR/chat.jsonl" "$OUTPUT_DIR/operator-turns.md" \
       "$TURNS_INCOMPLETE_FILE" "$WORK"; then
    return 1
  fi
  local TAIL_INCOMPLETE
  TAIL_INCOMPLETE=$(cat "$TURNS_INCOMPLETE_FILE")

  if ! snapshot_write_bundle "$SANDBOX_DIR" "$OUTPUT_DIR/repo.bundle" "$OUTPUT_DIR/bundle-verify.txt"; then
    return 1
  fi
  if ! snapshot_write_commits "$SANDBOX_DIR" "$BASE" "$OUTPUT_DIR/commits.txt"; then
    return 1
  fi

  local SCAN_TOTAL
  if ! SCAN_TOTAL=$(snapshot_scan_credentials "$OUTPUT_DIR/chat.jsonl" "$OUTPUT_DIR/credentials-scan.txt"); then
    return 1
  fi

  local SNAPSHOT_TIME BRANCH HEAD_SHA TRANSCRIPT_BYTES TURNS="" TURNS_RC=0
  SNAPSHOT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  BRANCH=$(git -C "$SANDBOX_DIR" rev-parse --abbrev-ref HEAD)
  HEAD_SHA=$(git -C "$SANDBOX_DIR" rev-parse HEAD)
  TRANSCRIPT_BYTES=$(wc -c < "$OUTPUT_DIR/chat.jsonl" | tr -d ' ')
  TURNS=$(grep -c '^### Operator turn ' "$OUTPUT_DIR/operator-turns.md") || TURNS_RC=$?
  case "$TURNS_RC" in
    0) : ;;
    1) TURNS=0 ;;   # no operator turn is a legitimate zero
    *) echo "package_eval_snapshot: could not count the operator turns in $OUTPUT_DIR/operator-turns.md" >&2; return 1 ;;
  esac

  if ! jq -n \
    --arg snapshot_time "$SNAPSHOT_TIME" \
    --arg snapshot_dir "$OUTPUT_DIR" \
    --arg harness_session_id "$HARNESS_SESSION" \
    --arg pi_session_id "${PI_SESSION_ID:-}" \
    --arg provider "${PI_PROVIDER:-}" \
    --arg model "${PI_MODEL:-}" \
    --arg thinking "${PI_REASONING_LEVEL:-}" \
    --arg sandbox_dir "$SANDBOX_DIR" \
    --arg branch "$BRANCH" \
    --arg head "$HEAD_SHA" \
    --arg base "$BASE" \
    --arg recorded_init_sha "$RECORDED_INIT" \
    --arg baseline_moved "$BASELINE_MOVED" \
    --arg transcript_source "$TRANSCRIPT" \
    --arg transcript_bytes "$TRANSCRIPT_BYTES" \
    --arg operator_turns "$TURNS" \
    --arg transcript_tail_incomplete "$TAIL_INCOMPLETE" \
    --arg credential_pattern_hits "$SCAN_TOTAL" \
    '{
      snapshot_time: $snapshot_time,
      snapshot_dir: $snapshot_dir,
      session: {
        harness_session_id: $harness_session_id,
        pi_session_id: $pi_session_id,
        provider: $provider,
        model: $model,
        thinking: $thinking
      },
      repository: {
        sandbox_dir: $sandbox_dir,
        branch: $branch,
        head: $head,
        base: $base,
        recorded_init_sha: $recorded_init_sha,
        baseline_moved: ($baseline_moved == "true")
      },
      transcript: {
        source: $transcript_source,
        bytes: ($transcript_bytes | tonumber),
        operator_turns: ($operator_turns | tonumber),
        last_line_incomplete_at_copy: ($transcript_tail_incomplete == "true")
      },
      credential_scan: { pattern_hits: ($credential_pattern_hits | tonumber) }
    }' > "$OUTPUT_DIR/eval-point.json"; then
    echo "package_eval_snapshot: could not write $OUTPUT_DIR/eval-point.json" >&2
    return 1
  fi

  local SNAPSHOT_NAME
  SNAPSHOT_NAME=$(basename "$OUTPUT_DIR")
  {
    echo "SNAPSHOT=${SNAPSHOT_NAME}"
    echo "SNAPSHOT_TIME=${SNAPSHOT_TIME}"
    echo "BASE=${BASE}"
    echo "BASELINE_MOVED=${BASELINE_MOVED}"
    echo "RECORDED_INIT_SHA=${RECORDED_INIT}"
    echo "HEAD=${HEAD_SHA}"
    echo "BRANCH=${BRANCH}"
    echo "TRANSCRIPT_SOURCE=${TRANSCRIPT}"
    echo "OPERATOR_TURNS=${TURNS}"
    echo "CREDENTIAL_PATTERN_HITS=${SCAN_TOTAL}"
  } > "$OUTPUT_DIR/.snapshot-status"
  rm -rf "$WORK"

  echo "package_eval_snapshot: snapshot written to ${OUTPUT_DIR}" >&2
  echo "" >&2
  echo "Snapshot: ${SNAPSHOT_NAME}" >&2
  echo "Session:  ${PI_SESSION_ID:-unknown} (${PI_PROVIDER:-unknown}/${PI_MODEL:-unknown} at ${PI_REASONING_LEVEL:-unknown})" >&2
  echo "Base:     ${BASE:0:7} (recorded init_sha ${RECORDED_INIT:0:7}; baseline moved: ${BASELINE_MOVED})" >&2
  echo "Head:     ${HEAD_SHA:0:7} on ${BRANCH}" >&2
  echo "Turns:    ${TURNS} operator turn(s)" >&2
  echo "Scan:     ${SCAN_TOTAL} credential-pattern hit(s) across ${#_SNAPSHOT_CREDENTIAL_PATTERNS[@]} pattern(s)" >&2
  echo "Next:     write README.md in the snapshot directory, naming the graded moments" >&2
}

# If run directly (not sourced), parse flags and execute.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  TO_ARG=""
  SNAPSHOT_SUMMARY_ARG=""
  BASELINE_ARG=""

  parse_args usage \
    --snapshot-summary=SNAPSHOT_SUMMARY_ARG \
    --baseline=BASELINE_ARG \
    --to=TO_ARG \
    -- "$@"
  [ $? -eq 2 ] && exit 0

  if [[ -z "$TO_ARG" ]]; then
    echo "Error: --to is required. Specify a base output directory." >&2
    echo "  In container: --to=\$HOME/workspace/output" >&2
    exit 1
  fi

  if [[ -d "$HOME/sandbox" ]]; then
    SANDBOX_DIR="$HOME/sandbox"
  else
    echo "Error: could not find the sandbox directory at $HOME/sandbox." >&2
    exit 1
  fi

  if ! package_eval_snapshot_validate_summary "$SNAPSHOT_SUMMARY_ARG"; then
    echo "Usage: package_eval_snapshot.sh --to=<dir> --snapshot-summary=<slug>" >&2
    exit 1
  fi

  HARNESS_SESSION_ID=$(session_state_read "$SANDBOX_DIR" session_id)
  OUTPUT_DIR=$(export_path "$TO_ARG" "evals" "$HARNESS_SESSION_ID" "$SNAPSHOT_SUMMARY_ARG")
  mkdir -p "$OUTPUT_DIR"

  package_eval_snapshot "$SANDBOX_DIR" "$OUTPUT_DIR" "$BASELINE_ARG"
fi
