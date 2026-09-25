#!/usr/bin/env bash
# Mutation bites for scripts/resume_agent.sh, each against the FULL suite.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/resume_agent.sh
ORIG=/tmp/resume.orig
cp "$SRC" "$ORIG"

bite() { # bite <label> <literal-old> <literal-new> [optional note]
  local label="$1"
  cp "$ORIG" "$SRC"
  local n
  n=$(grep -cF -e "$2" "$SRC" || true)
  if [[ "$n" != "1" ]]; then printf '%-4s SKIP  (literal matches=%s)\n' "$label" "$n"; return 0; fi
  OLD="$2" NEW="$3" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"
  cmp -s "$ORIG" "$SRC" && { printf '%-4s NO-OP\n' "$label"; return 0; }
  timeout 900 bash scripts/run_tests.sh > "/tmp/bite_res_$label.log" 2>&1
  cp "$ORIG" "$SRC"
  if grep -q '^FAIL ' "/tmp/bite_res_$label.log"; then
    printf '%-4s PROVEN    %s\n' "$label" "$(grep '^FAIL ' "/tmp/bite_res_$label.log" | sed 's/^FAIL //' | tr '\n' ' ')"
  else
    printf '%-4s SURVIVED  %s\n' "$label" "$(tail -1 "/tmp/bite_res_$label.log")"
  fi
}

# A1  the sandbox canonicalisation failure tolerated (guard disabled)
bite A1 'if ! canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")"; then exit 1; fi' 'if ! canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")"; then :; fi'
# A2  --provider without --list/--interactive accepted
bite A2 'if [[ -n "$PROVIDER_FILTER" && -z "$SESSION_ID_ARG" && "$RESUME_LIST" != true && "$INTERACTIVE_FLAG" != true ]]; then' 'if [[ -n "$PROVIDER_FILTER" && -z "$SESSION_ID_ARG" && "$RESUME_LIST" != true && "$INTERACTIVE_FLAG" != true && false ]]; then'
# A3  no resume target accepted
bite A3 'if [[ -z "$SESSION_ID_ARG" ]]; then
  echo "Error: no resume target given' 'if [[ -z "$SESSION_ID_ARG" && false ]]; then
  echo "Error: no resume target given'
# A4  --sandbox requirement disabled
bite A4 'if [[ -z "$SANDBOX_DIR" ]]; then
  echo "Error: --sandbox is required' 'if [[ -z "$SANDBOX_DIR" && false ]]; then
  echo "Error: --sandbox is required'
# A5  missing record guard disabled
bite A5 'if [[ ! -f "$RECORD_FILE" ]]; then' 'if false; then'
# A6  provider recovery failure tolerated
bite A6 'if [[ -z "$local_provider" ]]; then' 'if [[ -z "$local_provider" && false ]]; then'
# A7  delivery recovery: any literal accepted
bite A7 '  copy|mount) ;;' '  copy|mount|*) ;;'
# A8  the ambient SANDBOX_TYPE warning removed
bite A8 'if [[ -n "${SANDBOX_TYPE:-}" ]]; then
  echo "Warning: ambient SANDBOX_TYPE' 'if false; then
  echo "Warning: ambient SANDBOX_TYPE'
# A9  flatten literal validation disabled
bite A9 '  true|false|"") ;;' '  *) ;;'
# A10 the flatten default dropped
bite A10 'local_flatten="${local_flatten:-false}"' 'local_flatten=""'
# A11 the worktree flatten mismatch warning removed
bite A11 '  if [[ -n "$wt_flatten" && "$wt_flatten" != "$local_flatten" ]]; then' '  if false; then'
# A12 preflight asked to build missing images
bite A12 'preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "false"' 'preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "true"'
# A13 the workspace directories
bite A13 'mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"' ':'
# A14 session identity from the record's labels
bite A14 'session_env_names "$PROJECT_NAME" "$local_provider" "$SANDBOX_DIR" "$SESSION_ID_ARG"' 'session_env_names "$PROJECT_NAME" "$PROVIDER_NAME" "$SANDBOX_DIR" "$SESSION_ID_ARG"'
# A15 SESSION_TS from the record
bite A15 'SESSION_TS="$(record_label "$RECORD_FILE" session-ts")' 'SESSION_TS=""'
# A16 the page size for the list and picker
bite A16 'RESUME_LIST_PAGE_SIZE="$INTERACTIVE_MAX_ENTRIES"' 'RESUME_LIST_PAGE_SIZE=1000'
# A17 the flatten argument is not forwarded
bite A17 '[[ "$local_flatten" == "true" ]] && flatten_arg=(--flatten)' ':'
# A18 the mount cross-check ignores whether a worktree exists
bite A18 'if [[ "$local_delivery" == "mount" && -f "$WORKTREE_DIR/.git/config" ]]; then' 'if [[ "$local_delivery" == "mount" ]]; then'
# A19 the delivery forwarded is always copy
bite A19 '  --delivery="$local_delivery" \' '  --delivery="copy" \'
# A20 the list overflow hint removed
bite A20 '    echo "  (...$(( ${#RESUME_INVENTORY[@]} - RESUME_LIST_PAGE_SIZE )) more session(s)' '    echo "  (...'
# A21 the env file forwarded is derived, not the resolved one
bite A21 '  --env="$ENV_FILE" \' '  --env="$SANDBOX_DIR/.env" \'

echo "--- integrity ---"; cp "$ORIG" "$SRC"; cmp -s "$ORIG" "$SRC" && echo "restored byte-identical"
